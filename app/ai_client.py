from openai import OpenAI

from app.config import MODEL_NAME, OPENAI_API_KEY


client = OpenAI(api_key=OPENAI_API_KEY)


def generate_response(user_message: str, instructions: str) -> str:
    response = client.responses.create(
        model=MODEL_NAME,
        instructions=instructions,
        input=user_message,
        store=False,
    )

    return response.output_text