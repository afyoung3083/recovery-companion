# Recovery Companion

Recovery Companion is an AI-powered Twelve-Step recovery companion designed to help people pursue long-term recovery through connection, honesty, and spiritual growth.

It does **not** replace sponsors, meetings, therapists, clergy, or a Higher Power. It is designed to supplement recovery while consistently encouraging real-world human connection.

## Immutable Values

- **Anonymity**
- **Connection**
- **Rigorous Honesty**

These values guide the design of Recovery Companion.

## Current Status

Recovery Companion is currently approaching its first stable `v1.0.0` release.

Current development version: **v1.0.0**

Implemented capabilities include:

- Recovery-focused AI chat
- Recovery Knowledge Standard (RKS) behavioral safeguards
- Local structured journal
- Journal search and tag filtering
- User-initiated AI journal analysis
- Step Work assignments and reflection
- AI-assisted Step Work without AI-controlled progression
- Local Fellowship contacts
- Human-connection prioritization
- Daily Recovery Dashboard
- Sobriety-date tracking
- Daily Recovery Check-In
- Check-In history and trends
- User-initiated AI Check-In analysis
- Local recovery data storage
- Automated unit tests
- Automated RKS evaluations

The current command-line application is an MVP and development platform for the larger Recovery Companion product.

## Recovery Knowledge Standard

Recovery Companion uses a Recovery Knowledge Standard (RKS) to test important AI behaviors.

Examples include:

- Curiosity before counsel
- Reflection before guidance
- Presence before prescription during grief
- Careful handling of shame and sacred disclosures
- Human connection before AI dependence
- Tentative language when identifying possible patterns
- Supporting Step Work without controlling progression
- Nonjudgmental Daily Check-In analysis

The RKS evaluation suite runs automatically through GitHub Actions.

## Local Data

The current MVP stores recovery data locally on the user's computer.

Local data includes:

- Journal entries
- Step Work
- Fellowship contacts
- Sobriety profile information
- Daily Check-Ins

AI analysis is explicitly user initiated where designed.

## Project Structure

```text
recovery-companion/
|-- app/
|-- data/
|-- docs/
|-- prompts/
|-- tests/
|-- main.py
|-- README.md
|-- requirements.txt
`-- .env
```

## Getting Started

### Requirements

- Python 3.12+
- Git
- OpenAI API key

### 1. Clone the repository

```bash
git clone https://github.com/afyoung3083/recovery-companion.git
cd recovery-companion
```

### 2. Create a virtual environment

```bash
python -m venv .venv
```

### 3. Activate the virtual environment

Windows PowerShell:

```powershell
.\.venv\Scripts\Activate.ps1
```

macOS/Linux:

```bash
source .venv/bin/activate
```

### 4. Install dependencies

```bash
python -m pip install -r requirements.txt
```

### 5. Configure the environment

Create a `.env` file in the project root:

```text
OPENAI_API_KEY=your_api_key_here
```

Do not commit `.env` or API keys to source control.

### 6. Run Recovery Companion

```bash
python main.py
```

## Testing

Run the conventional unit-test suite:

```bash
python -m pytest -v
```

Run the Recovery Knowledge Standard evaluation suite:

```bash
python -m tests.run_rks_evals
```

Both test layers also run automatically through GitHub Actions.

## Technology Stack

- Python 3.12+
- OpenAI API
- python-dotenv
- pytest
- Git
- GitHub Actions

## Guiding Principles

Recovery Companion seeks to:

- Encourage human connection before AI dependence
- Reflect before advising
- Use curiosity before prescription
- Promote practical recovery action
- Recognize progress without shame
- Treat inferred motives and patterns tentatively
- Support rather than control Twelve-Step progression
- Protect user choice over when recovery information is analyzed by AI

## v1.0.0 Readiness

Release readiness is tracked in:

```text
docs/V1_ACCEPTANCE.md
```

`v1.0.0` will represent the first stable command-line MVP after the acceptance checklist and final regression testing are complete.

## Longer-Term Direction

Future development may include:

- Mobile application
- Secure cloud synchronization
- Long-term recovery memory
- Sponsor/sponsee sharing controlled by the user
- Expanded fellowship tools
- Notifications and recovery routines
- Production cloud infrastructure

## Disclaimer

Recovery Companion is a recovery-support and educational tool.

It is **not** a sponsor, therapist, physician, attorney, clergy member, or emergency service.

In an emergency, users should contact appropriate local emergency services.

## License

See `LICENSE.md`.