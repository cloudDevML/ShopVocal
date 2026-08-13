from pydantic import BaseModel

class TextActionPayload(BaseModel):
    text: str
