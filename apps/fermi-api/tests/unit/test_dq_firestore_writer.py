"""Unit tests for daily_question/firestore_writer.py."""

import datetime
from typing import Any
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.services.daily_question.firestore_writer import DQFirestoreWriter
from app.services.daily_question.schemas import DQWindowStatus


class TestDateToDocId:
    """Tests for _date_to_doc_id formatting."""

    def test_formats_date_as_yyyy_mm_dd(self) -> None:
        """Ensures the date is formatted as 'YYYY-MM-DD'."""
        mock_fs = MagicMock()
        writer = DQFirestoreWriter(mock_fs)

        result = writer._date_to_doc_id(datetime.date(2024, 12, 18))
        assert result == '2024-12-18'

    def test_pads_single_digit_months(self) -> None:
        """Ensures single-digit months are zero-padded."""
        mock_fs = MagicMock()
        writer = DQFirestoreWriter(mock_fs)

        result = writer._date_to_doc_id(datetime.date(2024, 1, 5))
        assert result == '2024-01-05'


@pytest.mark.asyncio
class TestCreateDqDocument:
    """Tests for create_dq_document."""

    async def test_creates_document_with_not_started_status(self) -> None:
        """Ensures a document is created with the NOT_STARTED status."""
        mock_fs = MagicMock()
        mock_doc_ref = MagicMock()
        mock_doc_ref.set = AsyncMock()
        mock_fs.collection.return_value.document.return_value = mock_doc_ref

        writer = DQFirestoreWriter(mock_fs)

        date = datetime.date(2024, 12, 18)
        window_start = datetime.datetime(2024, 12, 18, 12, 0, 0)  # noqa: DTZ001
        window_end = datetime.datetime(2024, 12, 19, 2, 0, 0)  # noqa: DTZ001

        await writer.create_dq_document(
            date=date,
            question_uid='test-uid-123',
            window_start_utc=window_start,
            window_end_utc=window_end,
        )

        mock_fs.collection.assert_called_once_with('daily_questions')
        mock_fs.collection().document.assert_called_once_with('2024-12-18')
        mock_doc_ref.set.assert_awaited_once()

        # Verify the document data
        call_args = mock_doc_ref.set.call_args
        doc_data: dict[str, Any] = call_args[0][0]
        assert doc_data['status'] == DQWindowStatus.NOT_STARTED
        assert doc_data['question_uid'] == 'test-uid-123'
        assert doc_data['results_ready'] is False


@pytest.mark.asyncio
class TestActivateDqDocument:
    """Tests for activate_dq_document (ACTIVE flip + optional invite_url branch)."""

    async def test_sets_status_active_without_invite_url(self) -> None:
        """Ensures the document status is updated to ACTIVE without an invite_url."""
        mock_fs = MagicMock()
        mock_doc_ref = MagicMock()
        mock_doc_ref.update = AsyncMock()
        mock_fs.collection.return_value.document.return_value = mock_doc_ref

        writer = DQFirestoreWriter(mock_fs)

        await writer.activate_dq_document(datetime.date(2024, 12, 18))

        mock_doc_ref.update.assert_awaited_once_with(
            {'status': DQWindowStatus.ACTIVE},
        )

    async def test_includes_invite_url_when_provided(self) -> None:
        """Ensures the invite_url is included when provided."""
        mock_fs = MagicMock()
        mock_doc_ref = MagicMock()
        mock_doc_ref.update = AsyncMock()
        mock_fs.collection.return_value.document.return_value = mock_doc_ref

        writer = DQFirestoreWriter(mock_fs)

        await writer.activate_dq_document(
            datetime.date(2024, 12, 18),
            invite_url='https://fermi.app/dq/2024-12-18',
        )

        mock_doc_ref.update.assert_awaited_once_with(
            {
                'status': DQWindowStatus.ACTIVE,
                'invite_url': 'https://fermi.app/dq/2024-12-18',
            },
        )


@pytest.mark.asyncio
class TestRecordUserStart:
    """Tests for record_user_start."""

    async def test_creates_user_session_with_submitted_false(self) -> None:
        """Ensures a user session document is created with submitted set to False."""
        mock_fs = MagicMock()
        mock_session_ref = MagicMock()
        mock_session_ref.set = AsyncMock()
        (
            mock_fs.collection.return_value.document.return_value.collection.return_value.document.return_value
        ) = mock_session_ref

        writer = DQFirestoreWriter(mock_fs)

        date = datetime.date(2024, 12, 18)
        user_id = 'user-firebase-uid'
        started_at = datetime.datetime(2024, 12, 18, 14, 0, 0)  # noqa: DTZ001
        deadline = datetime.datetime(2024, 12, 18, 14, 0, 30)  # noqa: DTZ001

        await writer.record_user_start(date, user_id, started_at, deadline)

        mock_session_ref.set.assert_awaited_once()
        call_args = mock_session_ref.set.call_args
        session_data: dict[str, Any] = call_args[0][0]
        assert session_data['started_at'] == started_at
        assert session_data['answer_deadline'] == deadline
        assert session_data['submitted'] is False


@pytest.mark.asyncio
class TestGetUserSession:
    """Tests for get_user_session."""

    async def test_returns_none_when_not_exists(self) -> None:
        """Ensures None is returned when the user session document does not exist."""
        mock_fs = MagicMock()
        mock_doc = MagicMock()
        mock_doc.exists = False
        mock_session_ref = MagicMock()
        mock_session_ref.get = AsyncMock(return_value=mock_doc)
        (
            mock_fs.collection.return_value.document.return_value.collection.return_value.document.return_value
        ) = mock_session_ref

        writer = DQFirestoreWriter(mock_fs)

        result = await writer.get_user_session(datetime.date(2024, 12, 18), 'user-id')

        assert result is None

    async def test_returns_session_data_when_exists(self) -> None:
        """Ensures session data is returned when the user session document exists."""
        mock_fs = MagicMock()
        session_data = {
            'started_at': datetime.datetime(2024, 12, 18, 14, 0, 0),  # noqa: DTZ001
            'answer_deadline': datetime.datetime(2024, 12, 18, 14, 0, 30),  # noqa: DTZ001
            'submitted': False,
        }
        mock_doc = MagicMock()
        mock_doc.exists = True
        mock_doc.to_dict.return_value = session_data
        mock_session_ref = MagicMock()
        mock_session_ref.get = AsyncMock(return_value=mock_doc)
        (
            mock_fs.collection.return_value.document.return_value.collection.return_value.document.return_value
        ) = mock_session_ref

        writer = DQFirestoreWriter(mock_fs)

        result = await writer.get_user_session(datetime.date(2024, 12, 18), 'user-id')

        assert result is not None
        assert result['submitted'] is False
