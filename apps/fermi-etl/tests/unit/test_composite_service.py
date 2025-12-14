"""Unit tests for composite_service.py."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.config import ETLConfig
from app.services.answer_service import AnswerResult
from app.services.composite_service import _run_answer_workflow
from app.services.enrichment_service import EnrichmentResult
from app.services.llm_answer_service import LLMAnswerResult
from app.services.question_service import QuestionBatchResult


@pytest.fixture
def mock_config() -> MagicMock:
    """Create a mock ETLConfig."""
    config = MagicMock(spec=ETLConfig)
    config.llm_answer_models = ['gpt-5.1', 'gpt-5-mini', 'gpt-5-nano']
    config.gemini_flash_temperature = 1.5
    return config


@pytest.fixture
def question_result() -> QuestionBatchResult:
    """Create a sample QuestionBatchResult."""
    return QuestionBatchResult(
        questions_requested=2,
        questions_generated=2,
        questions_yielded=2,
        questions_rejected=0,
        yield_rate=1.0,
        new_question_ids=[1, 2],
        duplicate_question_ids=[],
        details={},
    )


@pytest.mark.asyncio
async def test_run_answer_workflow_calls_gemini_flash(
    mock_config: MagicMock, question_result: QuestionBatchResult
) -> None:
    """Test that _run_answer_workflow calls gemini_flash_answer_questions."""
    # Mock all the service functions
    with (
        patch(
            'app.services.composite_service.answer_questions',
            new_callable=AsyncMock,
        ) as mock_answer,
        patch(
            'app.services.composite_service.enrich_categories',
            new_callable=AsyncMock,
        ) as mock_category,
        patch(
            'app.services.composite_service.enrich_difficulties',
            new_callable=AsyncMock,
        ) as mock_difficulty,
        patch(
            'app.services.composite_service.llm_answer_questions',
            new_callable=AsyncMock,
        ) as mock_llm_answer,
        patch(
            'app.services.composite_service.gemini_flash_answer_questions',
            new_callable=AsyncMock,
        ) as mock_gemini_flash,
        patch(
            'app.services.composite_service.sync_fermi_table',
            new_callable=AsyncMock,
        ),
    ):
        # Set up mock return values
        mock_answer.return_value = AnswerResult(
            questions_requested=2,
            questions_answered=2,
            questions_failed=0,
            success_rate=1.0,
            details={},
        )

        mock_category.return_value = EnrichmentResult(
            enriched=2,
            skipped=0,
            details={},
        )

        mock_difficulty.return_value = EnrichmentResult(
            enriched=2,
            skipped=0,
            details={},
        )

        mock_llm_answer.return_value = LLMAnswerResult(
            model='gpt-5.1',
            questions_answered=2,
            questions_skipped=0,
            details={},
        )

        mock_gemini_flash.return_value = LLMAnswerResult(
            model='gemini-flash',
            questions_answered=2,
            questions_skipped=0,
            details={},
        )

        # Run the workflow
        result = await _run_answer_workflow(question_result, mock_config)

        # Verify gemini_flash_answer_questions was called
        mock_gemini_flash.assert_called_once_with(
            limit=2,
            config=mock_config,
        )

        # Verify the result includes Gemini Flash in llm_answer_results
        assert result.success is True
        assert result.llm_answer_results is not None
        assert len(result.llm_answer_results) == 4  # 3 GPT + 1 Gemini Flash
        assert result.llm_answer_results[-1].model == 'gemini-flash'


@pytest.mark.asyncio
async def test_run_answer_workflow_continues_if_gemini_flash_fails(
    mock_config: MagicMock,
    question_result: QuestionBatchResult,
) -> None:
    """Test that workflow continues if Gemini Flash answering fails."""
    with (
        patch(
            'app.services.composite_service.answer_questions',
            new_callable=AsyncMock,
        ) as mock_answer,
        patch(
            'app.services.composite_service.enrich_categories',
            new_callable=AsyncMock,
        ) as mock_category,
        patch(
            'app.services.composite_service.enrich_difficulties',
            new_callable=AsyncMock,
        ) as mock_difficulty,
        patch(
            'app.services.composite_service.llm_answer_questions',
            new_callable=AsyncMock,
        ) as mock_llm_answer,
        patch(
            'app.services.composite_service.gemini_flash_answer_questions',
            new_callable=AsyncMock,
        ) as mock_gemini_flash,
        patch(
            'app.services.composite_service.sync_fermi_table',
            new_callable=AsyncMock,
        ),
    ):
        # Set up mock return values
        mock_answer.return_value = AnswerResult(
            questions_requested=2,
            questions_answered=2,
            questions_failed=0,
            success_rate=1.0,
            details={},
        )

        mock_category.return_value = EnrichmentResult(
            enriched=2,
            skipped=0,
            details={},
        )

        mock_difficulty.return_value = EnrichmentResult(
            enriched=2,
            skipped=0,
            details={},
        )

        mock_llm_answer.return_value = LLMAnswerResult(
            model='gpt-5.1',
            questions_answered=2,
            questions_skipped=0,
            details={},
        )

        # Make Gemini Flash fail
        mock_gemini_flash.side_effect = Exception('Gemini Flash API error')

        # Run the workflow
        result = await _run_answer_workflow(question_result, mock_config)

        # Verify workflow still succeeds
        assert result.success is True
        # Only 3 GPT models, Gemini Flash result not added
        assert len(result.llm_answer_results) == 3
