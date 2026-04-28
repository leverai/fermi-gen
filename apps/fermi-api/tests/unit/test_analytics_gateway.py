"""Unit tests for GameAnalyticsGateway."""

# ruff: noqa: D103
from __future__ import annotations

import asyncio
import uuid
from typing import Any, cast

from app.services.game.gateways.analytics_gateway import GameAnalyticsGateway


class _FakeUsersHistory:
    def __init__(self) -> None:
        self.history_calls: list[tuple[list[str], tuple[uuid.UUID, ...]]] = []

    async def add_questions_to_users_history(
        self,
        *,
        user_ids: list[str],
        question_uids: tuple[uuid.UUID, ...],
    ) -> None:
        self.history_calls.append((user_ids, question_uids))


class _FakeAnswers:
    def __init__(self) -> None:
        pass

    async def get_overall_avg_percentile(self, firebase_uid: str) -> int:
        return 85


class _FakeQuestionVotes:
    def __init__(self) -> None:
        self.set_calls: list[tuple[uuid.UUID, str, int]] = []

    async def set_verdict(
        self,
        *,
        question_uid: uuid.UUID,
        user_firebase_uid: str,
        verdict: int,
    ) -> int:
        self.set_calls.append((question_uid, user_firebase_uid, verdict))
        return verdict


class _FakeUsers:
    def __init__(self) -> None:
        pass

    async def get_xp(self, firebase_uid: str) -> int:
        return 1000

    async def get_points(self, firebase_uid: str) -> int:
        return 500


class _FakeDqAnswers:
    def __init__(self) -> None:
        pass

    async def count_user_answers(self, firebase_uid: str) -> int:
        return 10


class _FakeSurvivalRuns:
    def __init__(self) -> None:
        pass

    async def count_user_survival_runs(self, firebase_uid: str) -> int:
        return 5


class _FakeDbClient:
    def __init__(self) -> None:
        self.users_history = _FakeUsersHistory()
        self.answers = _FakeAnswers()
        self.question_votes = _FakeQuestionVotes()
        self.users = _FakeUsers()
        self.dq_answers = _FakeDqAnswers()
        self.survival_runs = _FakeSurvivalRuns()


def test_get_player_stats_aggregates_from_repos() -> None:
    db = _FakeDbClient()
    gw = GameAnalyticsGateway(db_client=cast(Any, db))

    stats = asyncio.get_event_loop().run_until_complete(
        gw.get_player_stats(player_id='u1'),
    )

    assert stats['total_daily_guesses'] == 10
    assert stats['total_survival_runs'] == 5
    assert stats['average_percentile'] == 85
    assert stats['xp'] == 1000
    assert stats['level'] == 11
    assert stats['points'] == 500


def test_set_user_vote_forwards_to_dal() -> None:
    db = _FakeDbClient()
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
