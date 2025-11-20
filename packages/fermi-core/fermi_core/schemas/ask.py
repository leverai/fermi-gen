"""Schemas for the ask chain."""

from typing import TypedDict

from pydantic import BaseModel, Field


class AskState(TypedDict):
    """State for the ask chain."""

    num_questions: int
    seed: str


class QuestionRaw(BaseModel):
    """Raw question schema."""

    text: str = Field(..., description='The question text itself.')


class AskQuestionBatch(BaseModel):
    """The `ask` output type."""

    questions: list[QuestionRaw] = Field(description='The list of questions.')
