"""Offline-first, bounded A/B conversation capture. No automatic AI grader."""
from __future__ import annotations

import argparse
import ast
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
from typing import Any, Callable, Sequence

ROOT = Path(__file__).resolve().parent.parent
BASELINE_COMMIT = "15bcd44b5ad41290c1e90e3bd7dfea1e07defb53"
MAX_CALLS = 12
MAX_OUTPUT_TOKENS = 1400
Generator = Callable[[str, list[dict[str, str]]], dict[str, Any]]


class ComparisonFailure(RuntimeError):
    """Carries partial, fictional results without disclosing raw API errors."""

    def __init__(self, report: dict[str, Any]):
        super().__init__("Comparison stopped; inspect the partial report.")
        self.report = report


def load_cases(root: Path = ROOT) -> list[dict[str, Any]]:
    payload = json.loads((root / "evals/conversation_cases.json").read_text("utf-8"))
    if payload.get("schema_version") != 1:
        raise ValueError("Unsupported case schema.")
    cases = payload.get("cases")
    if not isinstance(cases, list) or not cases:
        raise ValueError("Cases must be a nonempty list.")
    seen: set[str] = set()
    for case in cases:
        case_id = case.get("id")
        if not isinstance(case_id, str) or not case_id.startswith("CQ-") or case_id in seen:
            raise ValueError("Invalid or duplicate case ID.")
        seen.add(case_id)
        for field in ("name",):
            if not isinstance(case.get(field), str) or not case[field].strip():
                raise ValueError("Case name is required.")
        for field in ("tags", "user_turns", "review_criteria", "critical_failures"):
            values = case.get(field)
            if not isinstance(values, list) or not values or any(
                not isinstance(value, str) or not value.strip() for value in values
            ):
                raise ValueError(f"Invalid case field: {field}.")
        if not 2 <= len(case["user_turns"]) <= 4 or any(
            len(turn) > 1500 for turn in case["user_turns"]
        ):
            raise ValueError("Conversation fixture exceeds the allowed size.")
    return cases


def select_cases(cases: list[dict[str, Any]], requested: str) -> list[dict[str, Any]]:
    ids = [value.strip() for value in requested.split(",")]
    lookup = {case["id"]: case for case in cases}
    if not ids or len(ids) != len(set(ids)) or any(value not in lookup for value in ids):
        raise ValueError("Use unique, known conversation IDs.")
    return [lookup[value] for value in ids]


def required_calls(cases: list[dict[str, Any]], cap: int) -> int:
    if not 1 <= cap <= MAX_CALLS:
        raise ValueError(f"Request cap must be between 1 and {MAX_CALLS}.")
    count = 2 * sum(len(case["user_turns"]) for case in cases)
    if not count or count > cap:
        raise ValueError(f"Selected cases need {count} requests; cap is {cap}.")
    return count


def read_prompts(root: Path = ROOT) -> dict[str, str]:
    # Fixed known commit, no network fetch and no caller-supplied shell syntax.
    result = subprocess.run(
        ["git", "show", f"{BASELINE_COMMIT}:prompts/system_prompt.md"],
        cwd=root, capture_output=True, text=True, encoding="utf-8", check=True,
    )
    prompts = {
        "baseline": result.stdout.strip(),
        "candidate": (root / "prompts/system_prompt.md").read_text("utf-8").strip(),
    }
    if any(not prompt or len(prompt) > 20000 for prompt in prompts.values()):
        raise ValueError("Missing or oversized prompt.")
    return prompts


def configured_model(root: Path = ROOT) -> str:
    # Read the literal model name without importing app.config or opening .env.
    tree = ast.parse((root / "app/config.py").read_text("utf-8"))
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(
            isinstance(target, ast.Name) and target.id == "MODEL_NAME"
            for target in node.targets
        ):
            value = ast.literal_eval(node.value)
            if isinstance(value, str) and value.strip():
                return value
    raise ValueError("Cannot read the configured model without executing configuration.")


class LiveGenerator:
    def __init__(self, model: str):
        # Reached only after explicit --live --allow-paid and budget validation.
        from openai import OpenAI
        key = os.environ.get("OPENAI_API_KEY", "").strip()
        if not key:
            raise ValueError("An environment-provided OpenAI key is required for an authorized run.")
        self.model = model
        self.client = OpenAI(api_key=key, max_retries=0, timeout=45.0)

    def __call__(self, prompt: str, conversation: list[dict[str, str]]) -> dict[str, Any]:
        response = self.client.responses.create(
            model=self.model,
            instructions=prompt,
            input=conversation,
            store=False,
            reasoning={"effort": "low"},
            text={"verbosity": "low"},
            max_output_tokens=MAX_OUTPUT_TOKENS,
        )
        if response.status != "completed" or not response.output_text.strip():
            raise RuntimeError("Response incomplete or empty; do not score it as a success.")
        usage = response.usage
        return {
            "text": response.output_text.strip(),
            "input_tokens": usage.input_tokens if usage else None,
            "output_tokens": usage.output_tokens if usage else None,
        }

    def close(self) -> None:
        self.client.close()


def compare(
    cases: list[dict[str, Any]], prompts: dict[str, str], generate: Generator,
    *, max_calls: int, model: str,
) -> dict[str, Any]:
    planned = required_calls(cases, max_calls)
    if set(prompts) != {"baseline", "candidate"} or any(
        not value.strip() for value in prompts.values()
    ):
        raise ValueError("Both baseline and candidate prompts are required.")
    report: dict[str, Any] = {
        "schema_version": 1, "status": "running", "model": model,
        "quality_verdict": "NOT_EVALUATED", "human_review_required": True,
        "baseline_commit": BASELINE_COMMIT,
        "prompt_sha256": {name: hashlib.sha256(text.encode()).hexdigest()
                          for name, text in prompts.items()},
        "settings": {"reasoning": "low", "verbosity": "low", "store": False,
                     "max_output_tokens": MAX_OUTPUT_TOKENS, "max_retries": 0},
        "planned_requests": planned, "requests_attempted": 0, "results": [],
    }
    for case in cases:
        item = {key: copy.deepcopy(case[key]) for key in
                ("id", "name", "review_criteria", "critical_failures")}
        item["variants"] = {}
        report["results"].append(item)
        for variant in ("baseline", "candidate"):
            conversation: list[dict[str, str]] = []
            capture: dict[str, Any] = {"conversation": conversation, "usage": []}
            item["variants"][variant] = capture
            for user_text in case["user_turns"]:
                conversation.append({"role": "user", "content": user_text})
                report["requests_attempted"] += 1
                try:
                    if report["requests_attempted"] > max_calls:
                        raise RuntimeError("Request cap reached.")
                    reply = generate(prompts[variant], copy.deepcopy(conversation))
                    text = reply.get("text")
                    if not isinstance(text, str) or not text.strip():
                        raise ValueError("Empty response.")
                    conversation.append({"role": "assistant", "content": text})
                    capture["usage"].append({key: reply.get(key) for key in
                                             ("input_tokens", "output_tokens")})
                except Exception:
                    # Do not print exception text that might include credentials.
                    report["status"] = "incomplete"
                    report["error"] = "Generation failed; no retry or automatic continuation."
                    raise ComparisonFailure(report) from None
    report["status"] = "complete"
    return report


def main(
    argv: Sequence[str] | None = None, *, root: Path = ROOT,
    generator_factory: Callable[[str], Any] = LiveGenerator,
) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live", action="store_true")
    parser.add_argument("--allow-paid", action="store_true")
    parser.add_argument("--cases", default="CQ-001")
    parser.add_argument("--max-calls", type=int, default=6)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    if args.live != args.allow_paid:
        parser.error("Paid execution requires BOTH --live and --allow-paid.")
    try:
        all_cases = load_cases(root)
        cases = select_cases(all_cases, args.cases)
        planned = required_calls(cases, args.max_calls)
    except (ValueError, OSError) as error:
        parser.error(str(error))
    if not args.live:
        print(json.dumps({
            "mode": "OFFLINE_PLAN_ONLY", "api_calls": 0,
            "selected_cases": [case["id"] for case in cases],
            "planned_requests_if_authorized": planned,
            "available_cases": [{"id": c["id"], "name": c["name"]} for c in all_cases],
            "quality_verdict": "NOT_EVALUATED",
        }, indent=2))
        return 0
    if args.output is None:
        parser.error("An output path is required for authorized live comparisons.")
    try:
        prompts = read_prompts(root)
        model = configured_model(root)
        # Refuse to overwrite existing evidence; open before creating a client.
        with args.output.open("x", encoding="utf-8") as output:
            generator = None
            try:
                generator = generator_factory(model)
                report = compare(cases, prompts, generator,
                                 max_calls=args.max_calls, model=model)
                exit_code = 0
            except ComparisonFailure as error:
                report, exit_code = error.report, 1
            except Exception:
                report, exit_code = {"status": "setup_failed", "quality_verdict": "NOT_EVALUATED"}, 1
            finally:
                if generator is not None:
                    generator.close()
            json.dump(report, output, indent=2)
            output.write("\n")
        print(f"Comparison capture finished; quality requires human review. Report: {args.output}")
        return exit_code
    except (OSError, ValueError, subprocess.SubprocessError):
        print("Comparison could not start; check prompt history and a new writable output path.")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
