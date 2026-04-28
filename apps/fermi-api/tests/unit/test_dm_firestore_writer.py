"""Unit tests for deathmatch/firestore_writer.py."""

from typing import Any
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.schemas.deathmatch import POINTS_STAKE, DMPlayer, DMState
from app.services.deathmatch.firestore_writer import (
    QUEUE_COLLECTION,
    DMFirestoreWriter,
)


def _make_player(
    pid: str = 'user-1',
    name: str | None = 'Alice',
    picture: str | None = None,
    points: int = 100,
) -> DMPlayer:
    return DMPlayer(player_id=pid, name=name, picture=picture, points=points)


# ---------------------------------------------------------------------------
# enqueue / dequeue
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
class TestEnqueueDequeue:
    async def test_enqueue_sets_document_with_player_data(self) -> None:
        mock_fs = MagicMock()
        mock_doc = MagicMock()
        mock_doc.set = AsyncMock()
        mock_fs.collection.return_value.document.return_value = mock_doc

        writer = DMFirestoreWriter(mock_fs)
        player = _make_player()
        await writer.enqueue_player(player)

        mock_fs.collection.assert_called_with(QUEUE_COLLECTION)
        mock_fs.collection().document.assert_called_with('user-1')
        mock_doc.set.assert_awaited_once()
        data = mock_doc.set.call_args[0][0]
        assert data['player_id'] == 'user-1'
        assert data['name'] == 'Alice'

    async def test_dequeue_deletes_document(self) -> None:
        mock_fs = MagicMock()
        mock_doc = MagicMock()
        mock_doc.delete = AsyncMock()
        mock_fs.collection.return_value.document.return_value = mock_doc

        writer = DMFirestoreWriter(mock_fs)
        await writer.dequeue_player('user-1')

        mock_fs.collection.assert_called_with(QUEUE_COLLECTION)
        mock_doc.delete.assert_awaited_once()


# ---------------------------------------------------------------------------
# create_match
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
class TestCreateMatch:
    async def test_creates_waiting_match_without_opponent(self) -> None:
        mock_fs = MagicMock()
        mock_doc = MagicMock()
        mock_doc.set = AsyncMock()
        mock_fs.collection.return_value.document.return_value = mock_doc

        writer = DMFirestoreWriter(mock_fs)
        match_id = await writer.create_match(_make_player(), None)

        assert isinstance(match_id, str)
        mock_doc.set.assert_awaited_once()
        data = mock_doc.set.call_args[0][0]
        assert data['state'] == int(DMState.WAITING_FOR_OPPONENT)
        assert data['player2'] is None
        assert data['player1_answered'] is False
        assert data['points_transferred'] == POINTS_STAKE

    async def test_creates_active_match_with_opponent(self) -> None:
        mock_fs = MagicMock()
        mock_doc = MagicMock()
        mock_doc.set = AsyncMock()
        mock_fs.collection.return_value.document.return_value = mock_doc

        writer = DMFirestoreWriter(mock_fs)
        p1 = _make_player('u1')
        p2 = _make_player('u2', 'Bob')
        match_id = await writer.create_match(p1, p2)

        assert isinstance(match_id, str)
        data = mock_doc.set.call_args[0][0]
        assert data['state'] == int(DMState.QUESTION_ACTIVE)
        assert data['player2']['player_id'] == 'u2'

    async def test_creates_match_with_question_data(self) -> None:
        mock_fs = MagicMock()
        mock_doc = MagicMock()
        mock_doc.set = AsyncMock()
        mock_fs.collection.return_value.document.return_value = mock_doc

        writer = DMFirestoreWriter(mock_fs)
        q_data = {'question_uid': 'q-1', 'question_text': 'How many?'}
        await writer.create_match(
            _make_player(),
            _make_player('u2'),
            question_data=q_data,
        )

        data = mock_doc.set.call_args[0][0]
        assert data['question_uid'] == 'q-1'
        assert data['question_text'] == 'How many?'


# ---------------------------------------------------------------------------
# get_match
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
class TestGetMatch:
    async def test_returns_dict_when_exists(self) -> None:
        mock_fs = MagicMock()
        snap = MagicMock()
        snap.to_dict.return_value = {'state': 1}
        mock_doc = MagicMock()
        mock_doc.get = AsyncMock(return_value=snap)
        mock_fs.collection.return_value.document.return_value = mock_doc

        writer = DMFirestoreWriter(mock_fs)
        result = await writer.get_match('m-1')

        assert result == {'state': 1}

    async def test_returns_none_when_missing(self) -> None:
        mock_fs = MagicMock()
        snap = MagicMock()
        snap.to_dict.return_value = None
        mock_doc = MagicMock()
        mock_doc.get = AsyncMock(return_value=snap)
        mock_fs.collection.return_value.document.return_value = mock_doc

        writer = DMFirestoreWriter(mock_fs)
        result = await writer.get_match('m-missing')

        assert result is None


# ---------------------------------------------------------------------------
# set_opponent_and_question
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
class TestSetOpponentAndQuestion:
    async def test_updates_match_with_opponent_and_question(self) -> None:
        mock_fs = MagicMock()
        mock_doc = MagicMock()
        mock_doc.update = AsyncMock()
        mock_fs.collection.return_value.document.return_value = mock_doc

        writer = DMFirestoreWriter(mock_fs)
        p2 = _make_player('u2', 'Bob')
        q_data: dict[str, Any] = {
            'question_uid': 'q-1',
            'answer_number': 42.0,
        }
        await writer.set_opponent_and_question('m-1', p2, q_data)

        mock_doc.update.assert_awaited_once()
        data = mock_doc.update.call_args[0][0]
        assert data['state'] == int(DMState.QUESTION_ACTIVE)
        assert data['player2']['player_id'] == 'u2'
        assert data['question_uid'] == 'q-1'


# ---------------------------------------------------------------------------
# finish_match
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
class TestFinishMatch:
    async def test_sets_state_to_finished(self) -> None:
        mock_fs = MagicMock()
        mock_doc = MagicMock()
        mock_doc.update = AsyncMock()
        mock_fs.collection.return_value.document.return_value = mock_doc

        writer = DMFirestoreWriter(mock_fs)
        await writer.finish_match('m-1')

        mock_doc.update.assert_awaited_once_with(
            {'state': int(DMState.MATCH_FINISHED)},
        )
