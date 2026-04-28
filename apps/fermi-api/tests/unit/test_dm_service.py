"""Unit tests for deathmatch/service.py."""

from types import SimpleNamespace
from typing import Any
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import HTTPException
from fermi_db.schemas import AnswerBare

from app.schemas.deathmatch import (
    POINTS_STAKE,
    DMAnswerResponse,
    DMLeaveResponse,
    DMPlayer,
    DMQueueResponse,
    DMResultResponse,
    DMState,
)
from app.services.deathmatch.service import DeathMatchService

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_player(
    pid: str = 'user-1',
    name: str | None = 'Alice',
    points: int = 100,
) -> DMPlayer:
    return DMPlayer(player_id=pid, name=name, picture=None, points=points)


def _make_match(
    *,
    state: DMState = DMState.QUESTION_ACTIVE,
    p1_id: str = 'user-1',
    p2_id: str = 'bot-gpt51',
    question_uid: str = '12345678-1234-5678-1234-567812345678',
    answer_number: float = 100.0,
    answer_unit: str | None = None,
    p1_answered: bool = False,
    p2_answered: bool = False,
    p1_score: float = 0.0,
    p2_score: float = 0.0,
    winner: str | None = None,
) -> dict[str, Any]:
    return {
        'state': int(state),
        'player1': {
            'player_id': p1_id,
            'name': 'Alice',
            'picture': None,
            'points': 100,
        },
        'player2': {'player_id': p2_id, 'name': 'GPT', 'picture': None, 'points': 0},
        'question_uid': question_uid,
        'question_text': 'How many?',
        'answer_number': answer_number,
        'answer_unit': answer_unit,
        'player1_answered': p1_answered,
        'player2_answered': p2_answered,
        'player1_score': p1_score,
        'player2_score': p2_score,
        'winner': winner,
        'points_transferred': POINTS_STAKE,
    }


def _mock_db_client() -> MagicMock:
    """Build a mock DatabaseClient with async repo methods."""
    db = MagicMock()
    db.users.get_points = AsyncMock(return_value=200)
    db.users.increment_points = AsyncMock()
    db.users.increment_xp = AsyncMock()
    db.users.spend_points = AsyncMock(return_value=150)
    db.session.commit = AsyncMock()
    db.answers.add_answers = AsyncMock()
    db.answers.get_question_quantiles = AsyncMock(
        return_value=SimpleNamespace(
            model_dump=lambda exclude=None: {
                'p01': 10,
                'p05': 20,
                'p10': 30,
                'p25': 40,
                'p50': 50,
                'p60': 60,
                'p75': 70,
                'p80': 80,
                'p85': 90,
                'p90': 100,
                'p95': 110,
                'p99': 120,
            },
        ),
    )
    db.question_votes.get_upvotes = AsyncMock(return_value=5)
    db.users_history.add_questions_to_users_history = AsyncMock()

    import datetime
    import uuid

    fermi = SimpleNamespace(
        uid=uuid.UUID('12345678-1234-5678-1234-567812345678'),
        text='How many stars?',
        number=100.0,
        unit=None,
        category=None,
        difficulty=None,
        snippet='About 100.',
        created_at=datetime.datetime(2024, 1, 1),  # noqa: DTZ001
        gpt_5_1_number=95.0,
        gpt_5_1_unit=None,
        gpt_5_mini_number=80.0,
        gpt_5_mini_unit=None,
        gpt_5_nano_number=60.0,
        gpt_5_nano_unit=None,
        gemini_flash_1_number=70.0,
        gemini_flash_1_unit=None,
        gemini_flash_2_number=65.0,
        gemini_flash_2_unit=None,
        gemini_flash_3_number=55.0,
        gemini_flash_3_unit=None,
        gemini_flash_4_number=50.0,
        gemini_flash_4_unit=None,
        gemini_flash_5_number=45.0,
        gemini_flash_5_unit=None,
    )
    db.fermi.get_unseen_random_questions = AsyncMock(return_value=[fermi])
    return db


# ---------------------------------------------------------------------------
# _get_player_slot
# ---------------------------------------------------------------------------


class TestGetPlayerSlot:
    def test_returns_player1_when_match(self) -> None:
        match = _make_match(p1_id='uid-a')
        assert DeathMatchService._get_player_slot(match, 'uid-a') == 'player1'

    def test_returns_player2_when_match(self) -> None:
        match = _make_match(p2_id='uid-b')
        assert DeathMatchService._get_player_slot(match, 'uid-b') == 'player2'

    def test_returns_none_when_not_in_match(self) -> None:
        match = _make_match()
        assert DeathMatchService._get_player_slot(match, 'stranger') is None


# ---------------------------------------------------------------------------
# _build_status_response
# ---------------------------------------------------------------------------


class TestBuildStatusResponse:
    def test_identifies_player1_correctly(self) -> None:
        match = _make_match(p1_id='me', p1_answered=True, p2_answered=False)
        resp = DeathMatchService._build_status_response('m-1', match, 'me')
        assert resp.your_answered is True
        assert resp.opponent_answered is False
        assert resp.state == DMState.QUESTION_ACTIVE

    def test_identifies_player2_correctly(self) -> None:
        match = _make_match(p2_id='me', p1_answered=True, p2_answered=False)
        resp = DeathMatchService._build_status_response('m-1', match, 'me')
        assert resp.your_answered is False
        assert resp.opponent_answered is True

    def test_includes_question_when_present(self) -> None:
        match = _make_match()
        resp = DeathMatchService._build_status_response('m-1', match, 'user-1')
        assert resp.question is not None
        assert resp.question.question_uid == '12345678-1234-5678-1234-567812345678'

    def test_no_question_when_uid_missing(self) -> None:
        match = _make_match()
        match['question_uid'] = None
        resp = DeathMatchService._build_status_response('m-1', match, 'user-1')
        assert resp.question is None


# ---------------------------------------------------------------------------
# queue
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
class TestQueue:
    @patch('app.services.deathmatch.service.DMFirestoreWriter')
    async def test_returns_waiting_when_no_opponent(
        self,
        mock_writer_cls: MagicMock,
    ) -> None:
        writer = mock_writer_cls.return_value
        writer.pop_waiting_opponent = AsyncMock(return_value=None)
        writer.create_match = AsyncMock(return_value='match-1')
        writer.enqueue_player = AsyncMock()

        db = _mock_db_client()
        svc = DeathMatchService(db)
        result = await svc.queue('uid-1', 'Alice', None, MagicMock())

        assert isinstance(result, DMQueueResponse)
        assert result.status == 'waiting'
        assert result.match_id == 'match-1'
        writer.enqueue_player.assert_awaited_once()

    @patch('app.services.deathmatch.service.DMFirestoreWriter')
    async def test_returns_matched_when_opponent_found(
        self,
        mock_writer_cls: MagicMock,
    ) -> None:
        opponent = _make_player('uid-2', 'Bob')
        writer = mock_writer_cls.return_value
        writer.pop_waiting_opponent = AsyncMock(return_value=opponent)
        writer.create_match = AsyncMock(return_value='match-2')

        db = _mock_db_client()
        svc = DeathMatchService(db)
        result = await svc.queue('uid-1', 'Alice', None, MagicMock())

        assert result.status == 'matched'
        assert result.match_id == 'match-2'


# ---------------------------------------------------------------------------
# submit_answer
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
class TestSubmitAnswer:
    @patch('app.services.deathmatch.service.DMFirestoreWriter')
    async def test_raises_404_when_match_not_found(
        self,
        mock_writer_cls: MagicMock,
    ) -> None:
        writer = mock_writer_cls.return_value
        writer.get_match = AsyncMock(return_value=None)

        svc = DeathMatchService(_mock_db_client())
        with pytest.raises(HTTPException) as exc_info:
            await svc.submit_answer(
                'bad-id',
                'uid-1',
                AnswerBare(number=1, unit=None),
                MagicMock(),
            )
        assert exc_info.value.status_code == 404

    @patch('app.services.deathmatch.service.DMFirestoreWriter')
    async def test_raises_409_when_not_active(
        self,
        mock_writer_cls: MagicMock,
    ) -> None:
        writer = mock_writer_cls.return_value
        writer.get_match = AsyncMock(
            return_value=_make_match(state=DMState.MATCH_FINISHED),
        )

        svc = DeathMatchService(_mock_db_client())
        with pytest.raises(HTTPException) as exc_info:
            await svc.submit_answer(
                'm-1',
                'user-1',
                AnswerBare(number=1, unit=None),
                MagicMock(),
            )
        assert exc_info.value.status_code == 409

    @patch('app.services.deathmatch.service.DMFirestoreWriter')
    async def test_raises_403_when_not_in_match(
        self,
        mock_writer_cls: MagicMock,
    ) -> None:
        writer = mock_writer_cls.return_value
        writer.get_match = AsyncMock(return_value=_make_match())

        svc = DeathMatchService(_mock_db_client())
        with pytest.raises(HTTPException) as exc_info:
            await svc.submit_answer(
                'm-1',
                'stranger',
                AnswerBare(number=1, unit=None),
                MagicMock(),
            )
        assert exc_info.value.status_code == 403

    @patch('app.services.deathmatch.service.DMFirestoreWriter')
    async def test_returns_waiting_when_opponent_not_answered(
        self,
        mock_writer_cls: MagicMock,
    ) -> None:
        writer = mock_writer_cls.return_value
        match = _make_match()
        writer.get_match = AsyncMock(return_value=match)
        # After submit, only p1 answered
        writer.submit_player_answer = AsyncMock(
            return_value={**match, 'player1_answered': True, 'player2_answered': False},
        )

        svc = DeathMatchService(_mock_db_client())
        result = await svc.submit_answer(
            'm-1',
            'user-1',
            AnswerBare(number=50, unit=None),
            MagicMock(),
        )
        assert isinstance(result, DMAnswerResponse)
        assert result.waiting_for_opponent is True

    @patch('app.services.deathmatch.service.DMFirestoreWriter')
    async def test_returns_result_when_both_answered(
        self,
        mock_writer_cls: MagicMock,
    ) -> None:
        writer = mock_writer_cls.return_value
        match = _make_match(p2_id='bot-gpt51')
        writer.get_match = AsyncMock(return_value=match)
        resolved = {
            **match,
            'player1_answered': True,
            'player2_answered': True,
            'player1_score': 5000.0,
            'player2_score': 3000.0,
            'player1_answer': {'number': 90, 'unit': None},
            'player2_answer': {'number': 50, 'unit': None},
            'winner': 'user-1',
            'state': int(DMState.QUESTION_RESOLVED),
        }
        writer.submit_player_answer = AsyncMock(return_value=resolved)
        writer.finish_match = AsyncMock()

        db = _mock_db_client()
        svc = DeathMatchService(db)
        result = await svc.submit_answer(
            'm-1',
            'user-1',
            AnswerBare(number=90, unit=None),
            MagicMock(),
        )
        assert isinstance(result, DMResultResponse)
        assert result.winner == 'user-1'
        writer.finish_match.assert_awaited_once()


# ---------------------------------------------------------------------------
# get_result
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
class TestGetResult:
    @patch('app.services.deathmatch.service.DMFirestoreWriter')
    async def test_raises_404_when_match_not_found(
        self,
        mock_writer_cls: MagicMock,
    ) -> None:
        writer = mock_writer_cls.return_value
        writer.get_match = AsyncMock(return_value=None)

        svc = DeathMatchService(_mock_db_client())
        with pytest.raises(HTTPException) as exc_info:
            await svc.get_result('bad', 'uid-1', MagicMock())
        assert exc_info.value.status_code == 404

    @patch('app.services.deathmatch.service.DMFirestoreWriter')
    async def test_raises_409_when_not_resolved(
        self,
        mock_writer_cls: MagicMock,
    ) -> None:
        writer = mock_writer_cls.return_value
        writer.get_match = AsyncMock(
            return_value=_make_match(state=DMState.QUESTION_ACTIVE),
        )

        svc = DeathMatchService(_mock_db_client())
        with pytest.raises(HTTPException) as exc_info:
            await svc.get_result('m-1', 'user-1', MagicMock())
        assert exc_info.value.status_code == 409

    @patch('app.services.deathmatch.service.DMFirestoreWriter')
    async def test_returns_result_for_resolved_match(
        self,
        mock_writer_cls: MagicMock,
    ) -> None:
        writer = mock_writer_cls.return_value
        match = _make_match(
            state=DMState.QUESTION_RESOLVED,
            p1_answered=True,
            p2_answered=True,
            p1_score=5000.0,
            p2_score=3000.0,
            winner='user-1',
        )
        match['player1_answer'] = {'number': 90, 'unit': None}
        match['player2_answer'] = {'number': 50, 'unit': None}
        writer.get_match = AsyncMock(return_value=match)

        db = _mock_db_client()
        svc = DeathMatchService(db)
        result = await svc.get_result('m-1', 'user-1', MagicMock())

        assert isinstance(result, DMResultResponse)
        assert result.winner == 'user-1'
        assert result.your_score == 5000.0
        assert result.opponent_score == 3000.0


# ---------------------------------------------------------------------------
# leave
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
class TestLeave:
    @patch('app.services.deathmatch.service.DMFirestoreWriter')
    async def test_leave_waiting_match_deletes_it(
        self,
        mock_writer_cls: MagicMock,
    ) -> None:
        writer = mock_writer_cls.return_value
        writer.dequeue_player = AsyncMock()
        writer.get_match = AsyncMock(
            return_value=_make_match(state=DMState.WAITING_FOR_OPPONENT),
        )

        mock_fs = MagicMock()
        mock_doc = MagicMock()
        mock_doc.delete = AsyncMock()
        mock_fs.collection.return_value.document.return_value = mock_doc

        svc = DeathMatchService(_mock_db_client())
        result = await svc.leave('m-1', 'user-1', mock_fs)

        assert isinstance(result, DMLeaveResponse)
        assert result.forfeited is False
        writer.dequeue_player.assert_awaited_once()

    @patch('app.services.deathmatch.service.DMFirestoreWriter')
    async def test_leave_active_match_forfeits(
        self,
        mock_writer_cls: MagicMock,
    ) -> None:
        writer = mock_writer_cls.return_value
        writer.dequeue_player = AsyncMock()
        match = _make_match(state=DMState.QUESTION_ACTIVE, p2_id='user-2')
        writer.get_match = AsyncMock(return_value=match)
        writer.forfeit_match = AsyncMock(
            return_value={
                **match,
                'winner': 'user-2',
                'state': int(DMState.MATCH_FINISHED),
            },
        )

        db = _mock_db_client()
        svc = DeathMatchService(db)
        result = await svc.leave('m-1', 'user-1', MagicMock())

        assert result.forfeited is True
        writer.forfeit_match.assert_awaited_once()

    @patch('app.services.deathmatch.service.DMFirestoreWriter')
    async def test_leave_nonexistent_match_returns_no_forfeit(
        self,
        mock_writer_cls: MagicMock,
    ) -> None:
        writer = mock_writer_cls.return_value
        writer.dequeue_player = AsyncMock()
        writer.get_match = AsyncMock(return_value=None)

        svc = DeathMatchService(_mock_db_client())
        result = await svc.leave('m-1', 'user-1', MagicMock())

        assert result.forfeited is False


# ---------------------------------------------------------------------------
# check_and_match
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
class TestCheckAndMatch:
    @patch('app.services.deathmatch.service.DMFirestoreWriter')
    async def test_raises_404_when_match_not_found(
        self,
        mock_writer_cls: MagicMock,
    ) -> None:
        writer = mock_writer_cls.return_value
        writer.get_match = AsyncMock(return_value=None)

        svc = DeathMatchService(_mock_db_client())
        with pytest.raises(HTTPException) as exc_info:
            await svc.check_and_match('bad', 'uid-1', MagicMock())
        assert exc_info.value.status_code == 404

    @patch('app.services.deathmatch.service.DMFirestoreWriter')
    async def test_returns_status_when_already_matched(
        self,
        mock_writer_cls: MagicMock,
    ) -> None:
        writer = mock_writer_cls.return_value
        match = _make_match(state=DMState.QUESTION_ACTIVE)
        writer.get_match = AsyncMock(return_value=match)

        svc = DeathMatchService(_mock_db_client())
        result = await svc.check_and_match('m-1', 'user-1', MagicMock())

        assert result.state == DMState.QUESTION_ACTIVE

    @patch('app.services.deathmatch.service.DMFirestoreWriter')
    async def test_matches_with_bot_when_waiting(
        self,
        mock_writer_cls: MagicMock,
    ) -> None:
        writer = mock_writer_cls.return_value
        waiting_match = _make_match(state=DMState.WAITING_FOR_OPPONENT)
        active_match = _make_match(state=DMState.QUESTION_ACTIVE)
        writer.get_match = AsyncMock(side_effect=[waiting_match, active_match])
        writer.set_opponent_and_question = AsyncMock()
        writer.dequeue_player = AsyncMock()
        writer.submit_player_answer = AsyncMock(return_value=active_match)

        db = _mock_db_client()
        svc = DeathMatchService(db)
        result = await svc.check_and_match('m-1', 'user-1', MagicMock())

        writer.set_opponent_and_question.assert_awaited_once()
        writer.dequeue_player.assert_awaited_once()
        assert result.state == DMState.QUESTION_ACTIVE
