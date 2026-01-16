"""Unit tests for GameAnalyticsGateway."""

# ruff: noqa: D103
from __future__ import annotations

import asyncio
import uuid
from datetime import UTC, datetime
from types import SimpleNamespace
from typing import Any, cast

from fermi_db.models import AnswerEvent
from fermi_db.schemas import (
    AnswerBare,
    QuestionCategory,
    QuestionDifficulty,
)

from app.schemas.endpoints import (
    QuestionRoundSettings,
    QuestionSettings,
)
from app.services.game.gateways.analytics_gateway import GameAnalyticsGateway


class _FakeQuantiles:
    def __init__(self, **values: float) -> None:
        self._values = values

    def model_dump(self, *, exclude: set[str] | None = None) -> dict[str, float]:
        _ = exclude  # unused for this fake; values already exclude question_uid
        return dict(self._values)


class _FakeFermi:
    def __init__(self, call_log: list[str]) -> None:
        self._call_log = call_log
        self.last_get_params: dict[str, Any] | None = None

    async def get_unseen_random_questions(
        self,
        *,
        count: int,
        for_user_ids: list[str],
        categories: list[QuestionCategory] | None,
        difficulty: QuestionDifficulty | None,
    ) -> list[Any]:
        self.last_get_params = {
            'count': count,
            'for_user_ids': for_user_ids,
            'categories': categories,
            'difficulty': difficulty,
        }
        now = datetime(2024, 1, 1, tzinfo=UTC)
        # Two sample questions, unitful
        return [
            SimpleNamespace(
                uid=uuid.uuid4(),
                text='Q1',
                category=QuestionCategory.PLANET_EARTH,
                difficulty=QuestionDifficulty.MEDIUM,
                updated_at=now,
                unit='meter',
                number=1000.0,
                snippet='p',
            ),
            SimpleNamespace(
                uid=uuid.uuid4(),
                text='Q2',
                category=QuestionCategory.POP_CULTURE,
                difficulty=QuestionDifficulty.EASY,
                updated_at=now,
                unit='meter',
                number=1.0,
                snippet='p',
            ),
        ]


class _FakeUsersHistory:
    def __init__(self, call_log: list[str]) -> None:
        self._call_log = call_log
        self.history_calls: list[tuple[list[str], tuple[uuid.UUID, ...]]] = []

    async def add_questions_to_users_history(
        self,
        *,
        user_ids: list[str],
        question_uids: tuple[uuid.UUID, ...],
    ) -> None:
        self._call_log.append('history')
        self.history_calls.append((user_ids, question_uids))


class _FakeAnswers:
    def __init__(self, call_log: list[str]) -> None:
        self._call_log = call_log
        self.added: list[AnswerEvent] | None = None

    async def get_question_quantiles(self, question_uid: uuid.UUID) -> _FakeQuantiles:
        return _FakeQuantiles(
            p01=10.0,
            p05=20.0,
            p10=30.0,
            p25=40.0,
            p50=50.0,
            p60=60.0,
            p75=70.0,
            p80=80.0,
            p85=90.0,
            p90=100.0,
            p95=110.0,
            p99=120.0,
        )

    async def add_answers(self, events: list[AnswerEvent]) -> None:
        self._call_log.append('answers')
        self.added = events


class _FakeQuestionVotes:
    def __init__(self) -> None:
        self.set_calls: list[tuple[uuid.UUID, str, int]] = []
        self.counts: dict[uuid.UUID, tuple[int, int]] = {}

    async def set_verdict(
        self,
        *,
        question_uid: uuid.UUID,
        user_firebase_uid: str,
        verdict: int,
    ) -> int:
        self.set_calls.append((question_uid, user_firebase_uid, verdict))
        return verdict

    async def get_vote_counts(self, question_uid: uuid.UUID) -> tuple[int, int]:
        return self.counts.get(question_uid, (0, 0))

    async def get_upvotes(self, question_uid: uuid.UUID) -> int:
        return self.counts.get(question_uid, (0, 0))[0]

    async def get_downvotes(self, question_uid: uuid.UUID) -> int:
        return self.counts.get(question_uid, (0, 0))[1]

    async def get_players_vote_verdicts(
        self,
        question_uid: uuid.UUID,
        user_ids: list[str],
    ) -> dict[str, int]:
        return dict.fromkeys(user_ids, 1)


class _FakeUsers:
    def __init__(self) -> None:
        self.xp_store: dict[str, int] = {}

    async def increment_xp(self, firebase_uid: str, amount: int) -> None:
        """Mock increment_xp that tracks XP in memory."""
        if firebase_uid not in self.xp_store:
            self.xp_store[firebase_uid] = 0
        self.xp_store[firebase_uid] += amount

    async def get_xp(self, firebase_uid: str) -> int:
        """Mock get_xp that returns stored XP or 0."""
        return self.xp_store.get(firebase_uid, 0)


class _FakeDbClient:
    def __init__(self, call_log: list[str]) -> None:
        self.fermi = _FakeFermi(call_log)
        self.users_history = _FakeUsersHistory(call_log)
        self.answers = _FakeAnswers(call_log)
        self.question_votes = _FakeQuestionVotes()
        self.users = _FakeUsers()


def test_get_questions_and_answers_docs_general_mapping_and_shapes() -> None:
    log: list[str] = []
    db = _FakeDbClient(log)
    gw = GameAnalyticsGateway(db_client=cast(Any, db))

    qrs = QuestionRoundSettings(
        n_questions=2,
        categories=None,
        difficulty=None,
    )

    questions_docs, answers_docs = asyncio.get_event_loop().run_until_complete(
        gw.get_questions_and_answers_docs(user_ids=['u1'], question_round_settings=qrs),
    )

    # DB was called with categories None
    assert db.fermi.last_get_params is not None
    assert db.fermi.last_get_params['categories'] is None
    # Shapes
    assert len(questions_docs) == 2
    assert len(answers_docs) == 2
    assert questions_docs[0]['units'] is not None
    assert 'US' in questions_docs[0]['units']
    assert 'EU' in questions_docs[0]['units']
    # Quantiles populated
    assert set(answers_docs[0]['quantiles'].keys()) >= {
        'p01',
        'p05',
        'p10',
        'p25',
        'p50',
        'p60',
        'p75',
        'p80',
        'p85',
        'p90',
        'p95',
        'p99',
    }


def test__create_answer_events_transforms_inputs() -> None:
    log: list[str] = []
    db = _FakeDbClient(log)
    gw = GameAnalyticsGateway(db_client=cast(Any, db))
    game_id = 'g-1'
    qid = str(uuid.uuid4())

    players_results_docs = [
        {
            'question_uid': qid,
            'players_results': {
                'u1': {
                    'answer': AnswerBare(number=1.0, unit='meter'),
                    'correct_answer': AnswerBare(number=1.0, unit='meter'),
                    'score': {'number': 100.0, 'quantile': 0.9},
                },
                'u2': {
                    'answer': AnswerBare(number=2.0, unit='meter'),
                    'correct_answer': AnswerBare(number=1.0, unit='meter'),
                    'score': {'number': 80.0, 'quantile': 0.75},
                },
            },
            'revealed': True,
        },
    ]
    questions_settings = {
        qid: QuestionSettings(
            difficulty=QuestionDifficulty.MEDIUM,
            category=QuestionCategory.PLANET_EARTH,
        ),
    }

    events = gw._create_answer_events(
        game_id=game_id,
        players_results_docs=cast(Any, players_results_docs),
        questions_settings=questions_settings,
    )

    assert len(events) == 2
    assert all(isinstance(e, AnswerEvent) for e in events)
    assert all(str(e.game_id) == game_id for e in events)
    assert all(str(e.question_uid) == qid for e in events)
    # User ids preserved
    assert {e.user_firebase_id for e in events} == {'u1', 'u2'}


def test_archive_game_results_writes_answers_then_history() -> None:
    log: list[str] = []
    db = _FakeDbClient(log)
    gw = GameAnalyticsGateway(db_client=cast(Any, db))

    qid1, qid2 = str(uuid.uuid4()), str(uuid.uuid4())
    players_results_docs = [
        {
            'question_uid': qid1,
            'players_results': {
                'u1': {
                    'answer': AnswerBare(number=1.0, unit=None),
                    'correct_answer': AnswerBare(number=1.0, unit=None),
                    'score': {'number': 100.0, 'quantile': 0.9},
                },
            },
            'revealed': True,
        },
        {
            'question_uid': qid2,
            'players_results': {
                'u2': {
                    'answer': AnswerBare(number=2.0, unit=None),
                    'correct_answer': AnswerBare(number=1.0, unit=None),
                    'score': {'number': 80.0, 'quantile': 0.75},
                },
            },
            'revealed': True,
        },
    ]
    questions_settings = {
        qid1: QuestionSettings(
            difficulty=QuestionDifficulty.EASY,
            category=QuestionCategory.POP_CULTURE,
        ),
        qid2: QuestionSettings(
            difficulty=QuestionDifficulty.HARD,
            category=QuestionCategory.PLANET_EARTH,
        ),
    }

    asyncio.get_event_loop().run_until_complete(
        gw.archive_game_results(
            game_id='g-1',
            players_results_docs=cast(Any, players_results_docs),
            questions_settings=questions_settings,
        ),
    )

    # answers call happens before any history writes
    assert log[0] == 'answers'
    assert log.count('history') == 2
    # Verify history calls content
    assert db.users_history.history_calls[0][0] == ['u1']
    assert db.users_history.history_calls[1][0] == ['u2']


def test_set_user_vote_forwards_to_dal() -> None:
    log: list[str] = []
    db = _FakeDbClient(log)
    gw = GameAnalyticsGateway(db_client=cast(Any, db))
    qid = str(uuid.uuid4())

    verdict = asyncio.get_event_loop().run_until_complete(
        gw.set_user_vote(question_uid=qid, user_firebase_uid='u1', verdict=1),
    )

    assert verdict == 1
    assert len(db.question_votes.set_calls) == 1
    uid, user_id, v = db.question_votes.set_calls[0]
    assert uid == uuid.UUID(qid)
    assert user_id == 'u1'
    assert v == 1
