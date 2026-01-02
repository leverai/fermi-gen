"""Pydantic schemas for dashboard API."""

import uuid
from typing import Any

from fermi_db.schemas import QuestionCategory, QuestionDifficulty, QuestionStatus
from pydantic import BaseModel


class FermiEntryResponse(BaseModel):
    """Full Fermi entry data for frontend display."""

    uid: uuid.UUID
    question_id: int
    text: str
    question_source: dict[str, Any] | None
    answer_id: int
    number: float
    unit: str | None
    snippet: str
    used_ai_overview: bool
    difficulty: QuestionDifficulty | None
    category: QuestionCategory | None
    status: QuestionStatus
    gpt_5_1_number: float
    gpt_5_1_unit: str | None
    gpt_5_mini_number: float
    gpt_5_mini_unit: str | None
    gpt_5_nano_number: float
    gpt_5_nano_number: float
    gpt_5_nano_unit: str | None
    # Gemini Flash answers
    gemini_flash_1_number: float
    gemini_flash_1_unit: str | None
    gemini_flash_2_number: float
    gemini_flash_2_unit: str | None
    gemini_flash_3_number: float
    gemini_flash_3_unit: str | None
    gemini_flash_4_number: float
    gemini_flash_4_unit: str | None
    gemini_flash_5_number: float
    gemini_flash_5_unit: str | None

    is_daily_question: bool

    model_config = {'from_attributes': True}


class FermiUpdateRequest(BaseModel):
    """Single entry update with all editable fields."""

    uid: uuid.UUID
    text: str | None = None
    number: float | None = None
    unit: str | None = None
    snippet: str | None = None
    difficulty: QuestionDifficulty | None = None
    category: QuestionCategory | None = None
    status: QuestionStatus | None = None
    gpt_5_1_number: float | None = None
    gpt_5_1_unit: str | None = None
    gpt_5_mini_number: float | None = None
    gpt_5_mini_unit: str | None = None
    gpt_5_nano_number: float | None = None
    gpt_5_nano_unit: str | None = None
    # Gemini Flash answers
    gemini_flash_1_number: float | None = None
    gemini_flash_1_unit: str | None = None
    gemini_flash_2_number: float | None = None
    gemini_flash_2_unit: str | None = None
    gemini_flash_3_number: float | None = None
    gemini_flash_3_unit: str | None = None
    gemini_flash_4_number: float | None = None
    gemini_flash_4_unit: str | None = None
    gemini_flash_5_number: float | None = None
    gemini_flash_5_unit: str | None = None

    is_daily_question: bool | None = None


class CommitRequest(BaseModel):
    """Request to commit staged changes."""

    updates: list[FermiUpdateRequest]


class CommitResponse(BaseModel):
    """Response from commit operation."""

    updated_count: int
    message: str
