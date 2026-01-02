"""API routes for the dashboard."""

import logging

from fastapi import APIRouter, HTTPException
from fermi_db import DatabaseClient, FermiUpdate
from fermi_db.session import session_context

from app.schemas import CommitRequest, CommitResponse, FermiEntryResponse

logger = logging.getLogger(__name__)
router = APIRouter(prefix='/api')


@router.get('/questions/pending', response_model=list[FermiEntryResponse])
async def get_pending_questions(limit: int = 100) -> list[FermiEntryResponse]:
    """Get questions pending review.

    Args:
        limit: Maximum number of questions to return (default 100)

    Returns:
        List of Fermi entries awaiting review

    """
    async with session_context() as session:
        db = DatabaseClient(session)
        entries = await db.fermi.get_pending_review(limit=limit)
        return [FermiEntryResponse.model_validate(e) for e in entries]


@router.post('/questions/commit', response_model=CommitResponse)
async def commit_changes(request: CommitRequest) -> CommitResponse:
    """Commit staged changes to the database.

    Args:
        request: List of updates to apply

    Returns:
        Number of entries updated

    """
    if not request.updates:
        return CommitResponse(updated_count=0, message='No updates to commit')

    try:
        async with session_context() as session:
            db = DatabaseClient(session)
            # Convert Pydantic models to dataclass
            updates = [
                FermiUpdate(
                    uid=u.uid,
                    text=u.text,
                    number=u.number,
                    unit=u.unit,
                    snippet=u.snippet,
                    difficulty=u.difficulty,
                    category=u.category,
                    status=u.status,
                    gpt_5_1_number=u.gpt_5_1_number,
                    gpt_5_1_unit=u.gpt_5_1_unit,
                    gpt_5_mini_number=u.gpt_5_mini_number,
                    gpt_5_mini_unit=u.gpt_5_mini_unit,
                    gpt_5_nano_number=u.gpt_5_nano_number,
                    gpt_5_nano_unit=u.gpt_5_nano_unit,
                    is_daily_question=u.is_daily_question,
                    gemini_flash_1_number=u.gemini_flash_1_number,
                    gemini_flash_1_unit=u.gemini_flash_1_unit,
                    gemini_flash_2_number=u.gemini_flash_2_number,
                    gemini_flash_2_unit=u.gemini_flash_2_unit,
                    gemini_flash_3_number=u.gemini_flash_3_number,
                    gemini_flash_3_unit=u.gemini_flash_3_unit,
                    gemini_flash_4_number=u.gemini_flash_4_number,
                    gemini_flash_4_unit=u.gemini_flash_4_unit,
                    gemini_flash_5_number=u.gemini_flash_5_number,
                    gemini_flash_5_unit=u.gemini_flash_5_unit,
                )
                for u in request.updates
            ]
            updated_count = await db.fermi.bulk_update(updates)
            logger.info('Committed %d changes', updated_count)
            return CommitResponse(
                updated_count=updated_count,
                message=f'Successfully updated {updated_count} entries',
            )
    except Exception as e:
        logger.exception('Error committing changes')
        raise HTTPException(status_code=500, detail=str(e)) from e
