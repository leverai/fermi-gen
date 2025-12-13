"""Repository for Fermi table operations."""

import uuid
from dataclasses import dataclass

from sqlmodel import select

from fermi_db.models import Fermi
from fermi_db.repositories import BaseRepository
from fermi_db.schemas import QuestionCategory, QuestionDifficulty, QuestionStatus


@dataclass
class FermiUpdate:
    """Represents an update to a Fermi entry."""

    uid: uuid.UUID
    text: str | None = None
    number: float | None = None
    unit: str | None = None
    snippet: str | None = None
    difficulty: QuestionDifficulty | None = None
    category: QuestionCategory | None = None
    status: QuestionStatus | None = None
    # LLM answer fields
    gpt_5_1_number: float | None = None
    gpt_5_1_unit: str | None = None
    gpt_5_mini_number: float | None = None
    gpt_5_mini_unit: str | None = None
    gpt_5_nano_number: float | None = None
    gpt_5_nano_unit: str | None = None


class FermiRepository(BaseRepository):
    """Handle database operations for the Fermi table."""

    async def get_pending_review(self, limit: int = 100) -> list[Fermi]:
        """Get entries with PENDING_REVIEW status.

        Args:
            limit: Maximum number of entries to return

        Returns:
            List of Fermi entries awaiting review

        """
        statement = (
            select(Fermi)
            .where(Fermi.status == QuestionStatus.PENDING_REVIEW)
            .order_by(Fermi.created_at.desc())  # type: ignore
            .limit(limit)
        )
        result = await self.session.exec(statement)
        return list(result.all())

    async def get_by_uid(self, uid: uuid.UUID) -> Fermi | None:
        """Get a single Fermi entry by its UID.

        Args:
            uid: The unique identifier of the entry

        Returns:
            The Fermi entry if found, None otherwise

        """
        statement = select(Fermi).where(Fermi.uid == uid)
        result = await self.session.exec(statement)
        return result.first()

    async def bulk_update(self, updates: list[FermiUpdate]) -> int:
        """Bulk update Fermi entries.

        Args:
            updates: List of FermiUpdate objects containing the changes

        Returns:
            Number of entries updated

        """
        if not updates:
            return 0

        updated_count = 0
        for update in updates:
            entry = await self.get_by_uid(update.uid)
            if entry is None:
                continue

            # Apply non-None updates
            if update.text is not None:
                entry.text = update.text
            if update.number is not None:
                entry.number = update.number
            if update.unit is not None:
                entry.unit = update.unit
            if update.snippet is not None:
                entry.snippet = update.snippet
            if update.difficulty is not None:
                entry.difficulty = update.difficulty
            if update.category is not None:
                entry.category = update.category
            if update.status is not None:
                entry.status = update.status
            if update.gpt_5_1_number is not None:
                entry.gpt_5_1_number = update.gpt_5_1_number
            if update.gpt_5_1_unit is not None:
                entry.gpt_5_1_unit = update.gpt_5_1_unit
            if update.gpt_5_mini_number is not None:
                entry.gpt_5_mini_number = update.gpt_5_mini_number
            if update.gpt_5_mini_unit is not None:
                entry.gpt_5_mini_unit = update.gpt_5_mini_unit
            if update.gpt_5_nano_number is not None:
                entry.gpt_5_nano_number = update.gpt_5_nano_number
            if update.gpt_5_nano_unit is not None:
                entry.gpt_5_nano_unit = update.gpt_5_nano_unit

            self.session.add(entry)
            updated_count += 1

        await self.session.commit()
        return updated_count
