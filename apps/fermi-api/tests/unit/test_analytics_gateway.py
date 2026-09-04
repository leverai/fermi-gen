"""Unit tests for GameAnalyticsGateway."""

# ruff: noqa: D103
from __future__ import annotations

import asyncio
import uuid
from datetime import UTC, datetime
from types import SimpleNamespace
from typing import Any, cast

import pytest
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
from app.services.game.errors import SearchEmbeddingError, SearchNoResultsError
from app.services.game.gateways import analytics_gateway as gw_mod
from app.services.game.gateways.analytics_gateway import GameAnalyticsGateway


class _FakeQuantiles:
    def __init__(self, **values: float) -> None:
        self._values = values

    def model_dump(self, *, exclude: set[str] | None = None) -> dict[str, float]:
        _ = exclude  # unused for this fake; values already exclude question_uid
        return dict(self._values)


def _sample_question(text: str = 'Q') -> SimpleNamespace:
    """Build a minimal Fermi-like row with the fields the gateway/docs read."""
    return SimpleNamespace(
        uid=uuid.uuid4(),
        text=text,
        category=QuestionCategory.PLANET_EARTH,
        difficulty=QuestionDifficulty.MEDIUM,
        updated_at=datetime(2024, 1, 1, tzinfo=UTC),
        unit='meter',
        number=1000.0,
        snippet='p',
    )


class _FakeFermi:
    def __init__(self, call_log: list[str]) -> None:
        self._call_log = call_log
        self.last_get_params: dict[str, Any] | None = None
        # Smart-search controls / spies.
        self.last_similar_params: dict[str, Any] | None = None
        self.similar_rows: list[tuple[Any, float]] = []
        self.events: list[Any] = []
        self.insert_event_raises: bool = False

    async def get_unseen_random_questions(
        self,
        *,
        count: int,
        for_user_ids: list[str],
        categories: list[QuestionCategory] | None,
        difficulty: QuestionDifficulty | None,
    ) -> list[Any]:
        self._call_log.append('random')
        self.last_get_params = {
            'count': count,
            'for_user_ids': for_user_ids,
            'categories': categories,
            'difficulty': difficulty,
        }
        # Two sample questions, unitful
        return [_sample_question('Q1'), _sample_question('Q2')]

    async def get_unseen_similar_questions(
        self,
        *,
        query_embedding: list[float],
        count: int,
        for_user_ids: list[str],
        candidate_pool_size: int,
        similarity_floor: float,
        difficulty: QuestionDifficulty | None,
    ) -> list[tuple[Any, float]]:
        self._call_log.append('similar')
        self.last_similar_params = {
            'query_embedding': query_embedding,
            'count': count,
            'for_user_ids': for_user_ids,
            'candidate_pool_size': candidate_pool_size,
            'similarity_floor': similarity_floor,
            'difficulty': difficulty,
        }
        return self.similar_rows

    async def insert_smart_search_event(self, event: Any) -> None:
        self._call_log.append('event')
        if self.insert_event_raises:
            raise RuntimeError('telemetry boom')
        self.events.append(event)


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

    def _quantiles(self) -> _FakeQuantiles:
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

    async def get_question_quantiles(self, question_uid: uuid.UUID) -> _FakeQuantiles:
        return self._quantiles()

    async def get_questions_quantiles(
        self,
        question_uids: list[uuid.UUID],
    ) -> dict[uuid.UUID, _FakeQuantiles]:
        # Bulk: one entry per requested uid, mirroring the real repo's keying.
        self._call_log.append('quantiles_bulk')
        return {uid: self._quantiles() for uid in question_uids}

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

    async def get_upvotes_bulk(
        self,
        question_uids: list[uuid.UUID],
    ) -> dict[uuid.UUID, int]:
        # Bulk: mirror real repo -- only include uids that have upvotes (>0), so a
        # uid with zero upvotes is absent and the gateway must default it to 0.
        out: dict[uuid.UUID, int] = {}
        for uid in question_uids:
            up = self.counts.get(uid, (0, 0))[0]
            if up:
                out[uid] = up
        return out

    async def get_downvotes(self, question_uid: uuid.UUID) -> int:
        return self.counts.get(question_uid, (0, 0))[1]

    async def get_players_vote_verdicts(
        self,
        question_uid: uuid.UUID,
        user_ids: list[str],
    ) -> dict[str, int]:
        return dict.fromkeys(user_ids, 1)

    async def get_players_vote_verdicts_bulk(
        self,
        question_uids: list[uuid.UUID],
        user_ids: list[str],
    ) -> dict[uuid.UUID, dict[str, int]]:
        # Bulk: every requested uid present, pre-seeded for all users (here all 1
        # to match the per-uid fake's behavior).
        return {uid: dict.fromkeys(user_ids, 1) for uid in question_uids}


class _FakeUsers:
    def __init__(self) -> None:
        self.xp_store: dict[str, int] = {}
        self.points_store: dict[str, int] = {}

    async def increment_xp(self, firebase_uid: str, amount: int) -> None:
        """Mock increment_xp that tracks XP in memory."""
        if firebase_uid not in self.xp_store:
            self.xp_store[firebase_uid] = 0
        self.xp_store[firebase_uid] += amount

    async def get_xp(self, firebase_uid: str) -> int:
        """Mock get_xp that returns stored XP or 0."""
        return self.xp_store.get(firebase_uid, 0)

    async def increment_points(self, firebase_uid: str, amount: int) -> None:
        """Mock increment_points that tracks points in memory."""
        if firebase_uid not in self.points_store:
            self.points_store[firebase_uid] = 0
        self.points_store[firebase_uid] += amount

    async def get_points(self, firebase_uid: str) -> int:
        """Mock get_points that returns stored points or 0."""
        return self.points_store.get(firebase_uid, 0)


class _FakeSession:
    """Spy for the shared AsyncSession; records best-effort rollbacks."""

    def __init__(self) -> None:
        self.rollback_calls = 0

    async def rollback(self) -> None:
        self.rollback_calls += 1


class _FakeDbClient:
    def __init__(self, call_log: list[str]) -> None:
        self.fermi = _FakeFermi(call_log)
        self.users_history = _FakeUsersHistory(call_log)
        self.answers = _FakeAnswers(call_log)
        self.question_votes = _FakeQuestionVotes()
        self.users = _FakeUsers()
        # Shared session: the gateway rolls this back if telemetry fails so a
        # poisoned session can't break the surrounding request (regression: C1).
        self.session = _FakeSession()


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


def test_get_questions_and_answers_docs_bulk_order_and_missing_data() -> None:
    """Bulk path: docs keep input order; absent uids fall back to defaults.

    Locks the M1 refactor: the gateway fetches per-question aggregates in bulk
    (keyed by uid) but must reassemble strictly in the input `questions` order,
    with `order` = 1..N, and replicate the per-uid missing-data defaults:
    absent quantiles -> easy() cold-start (NOT all-zeros), absent upvotes -> 0,
    verdicts pre-seeded.
    """
    log: list[str] = []
    db = _FakeDbClient(log)

    # Three questions in a fixed order; q2 has no answer rows (absent from the
    # bulk quantiles result) and no upvotes (absent from the bulk upvotes result).
    q1, q2, q3 = (
        _sample_question('Q1'),
        _sample_question('Q2'),
        _sample_question('Q3'),
    )
    questions = [q1, q2, q3]

    async def fake_questions(**_: Any) -> list[Any]:
        return questions

    db.fermi.get_unseen_random_questions = fake_questions  # type: ignore[assignment]

    # Sparse bulk quantiles: q1 and q3 present (distinct p50), q2 absent.
    async def fake_quantiles(question_uids: list[uuid.UUID]) -> dict[uuid.UUID, Any]:
        log.append('quantiles_bulk')
        return {
            q1.uid: _FakeQuantiles(p50=111.0),
            q3.uid: _FakeQuantiles(p50=333.0),
        }

    db.answers.get_questions_quantiles = fake_quantiles  # type: ignore[assignment]

    # Sparse bulk upvotes: q1=5, q3=7, q2 absent (-> must default to 0).
    async def fake_upvotes(question_uids: list[uuid.UUID]) -> dict[uuid.UUID, int]:
        return {q1.uid: 5, q3.uid: 7}

    db.question_votes.get_upvotes_bulk = fake_upvotes  # type: ignore[assignment]

    # Verdicts: every requested uid present, pre-seeded (q1 actual upvote, rest 0).
    async def fake_verdicts(
        question_uids: list[uuid.UUID],
        user_ids: list[str],
    ) -> dict[uuid.UUID, dict[str, int]]:
        out = {uid: dict.fromkeys(user_ids, 0) for uid in question_uids}
        out[q1.uid] = dict.fromkeys(user_ids, 1)
        return out

    db.question_votes.get_players_vote_verdicts_bulk = fake_verdicts  # type: ignore[assignment]

    qrs = QuestionRoundSettings(n_questions=3, categories=None, difficulty=None)
    questions_docs, answers_docs = asyncio.get_event_loop().run_until_complete(
        gw_mod.GameAnalyticsGateway(
            db_client=cast(Any, db),
        ).get_questions_and_answers_docs(
            user_ids=['u1', 'u2'],
            question_round_settings=qrs,
        ),
    )

    # Order preserved: docs follow the input questions list, order = 1..N.
    assert [d['question_uid'] for d in questions_docs] == [
        str(q1.uid),
        str(q2.uid),
        str(q3.uid),
    ]
    assert [d['order'] for d in questions_docs] == [1, 2, 3]

    # Upvotes mapped per uid; the absent q2 defaults to 0 (per-uid parity).
    assert [d['upvotes'] for d in questions_docs] == [5, 0, 7]

    # Verdicts wired through per uid; q1 upvotes, q2/q3 pre-seeded NO_VOTE (0).
    assert questions_docs[0]['players_votes'] == {'u1': 1, 'u2': 1}
    assert questions_docs[1]['players_votes'] == {'u1': 0, 'u2': 0}

    # Quantiles mapped per uid; absent q2 -> easy() cold-start quantiles, matching
    # the per-uid path: a no-answer question has cnt=0 < MIN_QUANTILE_SAMPLE_SIZE,
    # so get_question_quantiles returns easy() (linear 1-1000), NOT all-zeros.
    assert answers_docs[0]['quantiles']['p50'] == 111.0
    assert answers_docs[2]['quantiles']['p50'] == 333.0
    assert answers_docs[1]['quantiles']['p50'] == 500.0


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


# --- Smart-search path -------------------------------------------------------
#
# Tests run the coroutine via run_until_complete to match this module's existing
# convention (the package sets asyncio_mode = "strict", so bare `async def` tests
# are not collected without an explicit marker). The embedder and DB are mocked;
# no real OpenAI/DB calls are made.


def _run(coro: Any) -> Any:
    return asyncio.get_event_loop().run_until_complete(coro)


def _patch_embed(
    monkeypatch: pytest.MonkeyPatch,
    vec: list[float] | None = None,
    *,
    raises: bool = False,
) -> dict[str, Any]:
    """Patch the embedder used by the gateway. Returns a spy dict."""
    spy: dict[str, Any] = {'calls': []}

    async def fake_embed(text: str) -> list[float]:
        spy['calls'].append(text)
        if raises:
            raise RuntimeError('openai down')
        return vec if vec is not None else [0.1, 0.2, 0.3]

    monkeypatch.setattr(gw_mod, 'aget_query_embedding_3small', fake_embed)
    return spy


def _patch_dials(
    monkeypatch: pytest.MonkeyPatch,
    *,
    pool: int = 25,
    floor: float = 0.30,
    min_results: int = 6,
) -> None:
    """Override the smart-search dials the gateway reads from settings."""
    monkeypatch.setattr(gw_mod.settings, 'smart_search_pool_size', pool)
    monkeypatch.setattr(gw_mod.settings, 'smart_search_similarity_floor', floor)
    monkeypatch.setattr(gw_mod.settings, 'smart_search_min_results', min_results)


def test_search_path_calls_similar_with_floor_pool_difficulty(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    log: list[str] = []
    db = _FakeDbClient(log)
    db.fermi.similar_rows = [(_sample_question(f'Q{i}'), 0.1 * i) for i in range(6)]
    _patch_embed(monkeypatch, [0.5, 0.6])
    _patch_dials(monkeypatch, pool=25, floor=0.30, min_results=6)
    gw = GameAnalyticsGateway(db_client=cast(Any, db))

    qrs = QuestionRoundSettings(
        n_questions=6,
        categories=None,
        difficulty=QuestionDifficulty.HARD,
        search_query='space scale',
    )
    questions_docs, answers_docs = _run(
        gw.get_questions_and_answers_docs(
            user_ids=['u1'],
            question_round_settings=qrs,
            game_id='g-1',
            host_user_id='host-1',
        ),
    )

    # Similar path used, legacy random path NOT used.
    assert 'similar' in log
    assert 'random' not in log
    params = db.fermi.last_similar_params
    assert params is not None
    assert params['query_embedding'] == [0.5, 0.6]
    assert params['count'] == 6
    assert params['for_user_ids'] == ['u1']
    assert params['candidate_pool_size'] == 25
    assert params['similarity_floor'] == 0.30
    assert params['difficulty'] == QuestionDifficulty.HARD
    assert len(questions_docs) == 6
    assert len(answers_docs) == 6


def test_category_path_calls_random_and_emits_no_event(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    log: list[str] = []
    db = _FakeDbClient(log)
    # Embedder patched to blow up if ever called on the legacy path.
    spy = _patch_embed(monkeypatch, raises=True)
    gw = GameAnalyticsGateway(db_client=cast(Any, db))

    qrs = QuestionRoundSettings(
        n_questions=2,
        categories=None,
        difficulty=None,
    )
    _run(
        gw.get_questions_and_answers_docs(
            user_ids=['u1'],
            question_round_settings=qrs,
            game_id='g-1',
            host_user_id='host-1',
        ),
    )

    assert 'random' in log
    assert 'similar' not in log
    assert spy['calls'] == []  # embedder never touched
    assert db.fermi.events == []  # legacy path emits no telemetry
    assert 'event' not in log


def test_search_embed_failure_raises_embedding_error_and_records_event(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    log: list[str] = []
    db = _FakeDbClient(log)
    _patch_embed(monkeypatch, raises=True)
    _patch_dials(monkeypatch)
    gw = GameAnalyticsGateway(db_client=cast(Any, db))

    qrs = QuestionRoundSettings(
        n_questions=6,
        categories=None,
        difficulty=None,
        search_query='space scale',
    )
    with pytest.raises(SearchEmbeddingError):
        _run(
            gw.get_questions_and_answers_docs(
                user_ids=['u1'],
                question_round_settings=qrs,
                game_id='g-1',
                host_user_id='host-1',
            ),
        )
    # Similar-questions never reached; embed_error event recorded.
    assert 'similar' not in log
    assert len(db.fermi.events) == 1
    assert db.fermi.events[0].outcome == 'embed_error'
    assert db.fermi.events[0].game_id == 'g-1'


@pytest.mark.parametrize('n_rows', [0, 3])
def test_search_too_few_raises_no_results_and_records_event(
    monkeypatch: pytest.MonkeyPatch,
    n_rows: int,
) -> None:
    """Both k=0 and 0<k<min_results -> SearchNoResultsError (not embed error)."""
    log: list[str] = []
    db = _FakeDbClient(log)
    db.fermi.similar_rows = [
        (_sample_question(f'Q{i}'), 0.1 * i) for i in range(n_rows)
    ]
    _patch_embed(monkeypatch, [0.1])
    _patch_dials(monkeypatch, min_results=6)
    gw = GameAnalyticsGateway(db_client=cast(Any, db))

    qrs = QuestionRoundSettings(
        n_questions=6,
        categories=None,
        difficulty=None,
        search_query='asdfqwer',
    )
    with pytest.raises(SearchNoResultsError) as exc_info:
        _run(
            gw.get_questions_and_answers_docs(
                user_ids=['u1'],
                question_round_settings=qrs,
                game_id='g-1',
                host_user_id='host-1',
            ),
        )
    assert exc_info.value.found == n_rows
    assert exc_info.value.query == 'asdfqwer'
    # The failed attempt remains attributable to the lobby that was started.
    assert len(db.fermi.events) == 1
    event = db.fermi.events[0]
    assert event.outcome == 'too_few'
    assert event.game_id == 'g-1'
    assert len(event.returned_similarities) == n_rows


def test_search_min_results_gate_uses_max_with_n_questions(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A custom n_questions above min_results still requires a full game."""
    log: list[str] = []
    db = _FakeDbClient(log)
    # 8 rows returned, n_questions=10, min_results=6 -> gate is max(6,10)=10 -> too few.
    db.fermi.similar_rows = [(_sample_question(f'Q{i}'), 0.05 * i) for i in range(8)]
    _patch_embed(monkeypatch, [0.1])
    _patch_dials(monkeypatch, min_results=6)
    gw = GameAnalyticsGateway(db_client=cast(Any, db))

    qrs = QuestionRoundSettings(
        n_questions=10,
        categories=None,
        difficulty=None,
        search_query='space scale',
    )
    with pytest.raises(SearchNoResultsError):
        _run(
            gw.get_questions_and_answers_docs(
                user_ids=['u1'],
                question_round_settings=qrs,
                game_id='g-1',
                host_user_id='host-1',
            ),
        )
    assert db.fermi.events[0].outcome == 'too_few'


def test_search_with_small_game_fetches_quality_pool_then_slices(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A two-question game can pass the six-candidate quality gate."""
    log: list[str] = []
    db = _FakeDbClient(log)
    db.fermi.similar_rows = [(_sample_question(f'Q{i}'), 0.05 * i) for i in range(6)]
    _patch_embed(monkeypatch, [0.1])
    _patch_dials(monkeypatch, pool=4, min_results=6)
    gw = GameAnalyticsGateway(db_client=cast(Any, db))

    qrs = QuestionRoundSettings(
        n_questions=2,
        categories=None,
        difficulty=None,
        search_query='space scale',
    )
    questions_docs, answers_docs = _run(
        gw.get_questions_and_answers_docs(
            user_ids=['u1'],
            question_round_settings=qrs,
            game_id='g-small',
            host_user_id='host-1',
        ),
    )

    params = db.fermi.last_similar_params
    assert params is not None
    assert params['count'] == 6
    assert params['candidate_pool_size'] == 6
    assert len(questions_docs) == 2
    assert len(answers_docs) == 2
    assert db.fermi.events[0].n == 2
    assert db.fermi.events[0].game_id == 'g-small'
    assert db.fermi.events[0].pool_size_used == 6


def test_search_success_records_ok_event_with_similarities(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    log: list[str] = []
    db = _FakeDbClient(log)
    # distances -> similarities = 1 - distance
    distances = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5]
    db.fermi.similar_rows = [
        (_sample_question(f'Q{i}'), d) for i, d in enumerate(distances)
    ]
    _patch_embed(monkeypatch, [0.1])
    _patch_dials(monkeypatch, pool=25, floor=0.30, min_results=6)
    gw = GameAnalyticsGateway(db_client=cast(Any, db))

    qrs = QuestionRoundSettings(
        n_questions=6,
        categories=None,
        difficulty=QuestionDifficulty.EASY,
        search_query='space scale',
    )
    _run(
        gw.get_questions_and_answers_docs(
            user_ids=['u1'],
            question_round_settings=qrs,
            game_id='g-42',
            host_user_id='host-1',
        ),
    )

    assert len(db.fermi.events) == 1
    event = db.fermi.events[0]
    assert event.outcome == 'ok'
    assert event.game_id == 'g-42'
    assert event.user_id == 'host-1'
    assert event.n == 6
    assert event.floor_used == 0.30
    assert event.pool_size_used == 25
    assert event.difficulty == QuestionDifficulty.EASY
    # similarities = 1 - distance, parallel to returned_uids.
    assert event.returned_similarities == pytest.approx([1 - d for d in distances])
    # uids are recorded as strings (JSON-serializable), parallel to similarities.
    assert len(event.returned_uids) == 6
    assert all(isinstance(u, str) for u in event.returned_uids)


def test_search_telemetry_failure_is_non_fatal(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A telemetry insert error must not break a successful game start."""
    log: list[str] = []
    db = _FakeDbClient(log)
    db.fermi.similar_rows = [(_sample_question(f'Q{i}'), 0.1 * i) for i in range(6)]
    db.fermi.insert_event_raises = True
    _patch_embed(monkeypatch, [0.1])
    _patch_dials(monkeypatch, min_results=6)
    gw = GameAnalyticsGateway(db_client=cast(Any, db))

    qrs = QuestionRoundSettings(
        n_questions=6,
        categories=None,
        difficulty=None,
        search_query='space scale',
    )
    # Does not raise despite telemetry blowing up.
    questions_docs, _ = _run(
        gw.get_questions_and_answers_docs(
            user_ids=['u1'],
            question_round_settings=qrs,
            game_id='g-1',
            host_user_id='host-1',
        ),
    )
    assert len(questions_docs) == 6
    # The failed telemetry insert must roll the shared session back, so the
    # downstream quantiles/votes reads don't hit a poisoned session (C1 fix).
    assert db.session.rollback_calls == 1
