"""Common schemas for the Fermi core."""

from typing import TypedDict


class QuestionTextState(TypedDict):
    """State for the question chain."""

    question_text: str
