"""Unit tests for StartGameUseCase: search-error mapping and the start claim.

Two concerns are covered here without a Firestore emulator or real OpenAI:

1. Search-error -> HTTP mapping. The two smart-search failure modes must map to
   distinct HTTP responses:
   - SearchEmbeddingError -> 503 (retryable; OpenAI down/timeout).
   - SearchNoResultsError -> 422 with a stable `code` (not retryable).

2. The start "claim" (defense against a double/retried start). A start whose
   claim cannot be taken (state already past LOBBY_READY, or a fresh claim
   already held) fails fast with 409 and never reaches the expensive question
   fetch.

The Firestore transaction is exercised at the use-case level by replacing
``TransactionRunner.run`` with a passthrough that drives the use case's claim
function with a recording fake transaction. Real Firestore transaction
semantics (concurrent-write abort/retry) are covered by the integration tests.
"""

# ruff: noqa: D103
from __future__ import annotations

import asyncio
import datetime
from types import SimpleNamespace
from typing import Any, cast

import pytest
from fastapi import HTTPException

import app.services.game.use_cases.start_game as start_game_module
from app.schemas.game import GameState
from app.services.game.errors import SearchEmbeddingError, SearchNoResultsError
from app.services.game.use_cases.start_game import StartGameUseCase
from app.services.game.writers.lifecycle_writer import (
    START_CLAIM_TTL,
    GameLifecycleWriter,
)


class _Recorder:
    """Records ``update``/``set`` like a Firestore batch or transaction."""

    def __init__(self) -> None:
        self.updates: list[tuple[Any, dict]] = []
        self.sets: list[tuple[Any, dict]] = []

    def update(self, ref: Any, data: dict) -> None:
        self.updates.append((ref, data))

    def set(self, ref: Any, data: dict) -> None:
        self.sets.append((ref, data))


class _FakeRepo:
    """Returns a startable game owned by the host with one active player.

    ``state`` and ``start_claimed_at`` are configurable so we can simulate an
    already-started game or a game with a fresh claim already held.
    """

    def __init__(
        self,
        host: str,
        *,
        state: GameState = GameState.LOBBY_READY,
        start_claimed_at: datetime.datetime | None = None,
    ) -> None:
        self._host = host
        self._state = state
        self._start_claimed_at = start_claimed_at
        self.read_count = 0

    async def get_game_fields(
        self,
        game_ref: Any,
        *,
        fields: list[str],
        tx: Any = None,
    ) -> dict:
        self.read_count += 1
        return {
            'host': self._host,
            'players': {self._host: {'is_active': True}},
            'state': int(self._state),
            'n_questions': 6,
            'question_round_settings': {
                'n_questions': 6,
                'categories': None,
                'difficulty': None,
                'search_query': 'space scale',
            },
            'start_claimed_at': self._start_claimed_at,
        }


class _RaisingGateway:
    def __init__(self, exc: Exception) -> None:
        self._exc = exc
        self.call_count = 0

    async def get_questions_and_answers_docs(
        self,
        *,
        question_round_settings: Any,
        user_ids: list[str],
        game_id: str | None = None,
        host_user_id: str | None = None,
    ) -> Any:
        self.call_count += 1
        raise self._exc


class _ExplodingGateway:
    """Fails the test if it is ever called (claim must short-circuit first)."""

    def __init__(self) -> None:
        self.call_count = 0

    async def get_questions_and_answers_docs(self, **_kwargs: Any) -> Any:
        self.call_count += 1
        raise AssertionError('question fetch must not run when start is claimed')


class _FakeFirestore:
    """Minimal async Firestore client: doc refs, batches and a fake transaction."""

    def __init__(self) -> None:
        self.batches: list[_Recorder] = []
        self.committed: list[_Recorder] = []

    def collection(self, _name: str) -> Any:
        return SimpleNamespace(document=lambda _gid: SimpleNamespace(id=_gid))

    def batch(self) -> Any:
        recorder = _Recorder()
        self.batches.append(recorder)

        async def _commit() -> None:
            self.committed.append(recorder)

        # Attach an async commit to the recorder instance.
        recorder.commit = _commit  # type: ignore[attr-defined]
        return recorder


def _patch_txn_runner(
    monkeypatch: pytest.MonkeyPatch,
    tx_recorder: _Recorder,
) -> None:
    """Replace TransactionRunner.run with a passthrough using a fake tx.

    Avoids binding the unit test to Firestore's async_transactional internals;
    the real concurrent-write abort/retry path is covered by integration tests.
    """

    async def _run(self: Any, func: Any) -> Any:
        return await func(tx_recorder)

    monkeypatch.setattr(
        start_game_module.TransactionRunner,
        'run',
        _run,
    )


def _make_use_case(
    *,
    gateway: Any,
    repo: _FakeRepo,
    client: _FakeFirestore,
) -> StartGameUseCase:
    return StartGameUseCase(
        firestore_client=cast(Any, client),
        repo=cast(Any, repo),
        db_gateway=cast(Any, gateway),
        lifecycle=GameLifecycleWriter(),
        questions=cast(Any, SimpleNamespace()),
        players_answers=cast(Any, SimpleNamespace()),
    )


def test_embedding_error_maps_to_503(monkeypatch: pytest.MonkeyPatch) -> None:
    host = 'host-1'
    tx = _Recorder()
    _patch_txn_runner(monkeypatch, tx)
    client = _FakeFirestore()
    gateway = _RaisingGateway(SearchEmbeddingError('boom'))
    use_case = _make_use_case(
        gateway=gateway,
        repo=_FakeRepo(host),
        client=client,
    )
    user = SimpleNamespace(firebase_uid=host)

    with pytest.raises(HTTPException) as exc_info:
        asyncio.run(
            use_case.execute(game_id='g-1', current_user=cast(Any, user)),
        )
    assert exc_info.value.status_code == 503
    # Machine-detectable via a stable `code` (not display text), like the 422.
    detail = exc_info.value.detail
    assert isinstance(detail, dict)
    assert detail['code'] == 'search_embedding_error'
    assert 'try again' in detail['message']
    # Claim was taken (stamped on the tx) and then released on failure.
    assert tx.updates
    assert 'start_claimed_at' in tx.updates[0][1]
    assert client.committed, 'claim should be released via a committed batch'


def test_no_results_error_maps_to_422_with_code(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    host = 'host-1'
    tx = _Recorder()
    _patch_txn_runner(monkeypatch, tx)
    use_case = _make_use_case(
        gateway=_RaisingGateway(SearchNoResultsError(query='asdfqwer', found=0)),
        repo=_FakeRepo(host),
        client=_FakeFirestore(),
    )
    user = SimpleNamespace(firebase_uid=host)

    with pytest.raises(HTTPException) as exc_info:
        asyncio.run(
            use_case.execute(game_id='g-1', current_user=cast(Any, user)),
        )
    # 422, NOT 503 -- and machine-detectable via a stable `code`.
    assert exc_info.value.status_code == 422
    assert exc_info.value.status_code != 503
    detail = exc_info.value.detail
    assert isinstance(detail, dict)
    assert detail['code'] == 'search_no_results'
    assert 'asdfqwer' in detail['message']


def test_start_when_already_started_returns_409_without_fetch(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A start on a game past LOBBY_READY 409s and never fetches questions."""
    host = 'host-1'
    tx = _Recorder()
    _patch_txn_runner(monkeypatch, tx)
    gateway = _ExplodingGateway()
    use_case = _make_use_case(
        gateway=gateway,
        repo=_FakeRepo(host, state=GameState.QUESTION_N),
        client=_FakeFirestore(),
    )
    user = SimpleNamespace(firebase_uid=host)

    with pytest.raises(HTTPException) as exc_info:
        asyncio.run(
            use_case.execute(game_id='g-1', current_user=cast(Any, user)),
        )
    assert exc_info.value.status_code == 409
    assert gateway.call_count == 0
    # No claim stamped, since the state check rejected first.
    assert tx.updates == []


def test_start_when_claim_already_held_returns_409_without_fetch(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A second start while a fresh claim is held 409s and never fetches."""
    host = 'host-1'
    tx = _Recorder()
    _patch_txn_runner(monkeypatch, tx)
    gateway = _ExplodingGateway()
    fresh_claim = datetime.datetime.now(datetime.UTC)
    use_case = _make_use_case(
        gateway=gateway,
        repo=_FakeRepo(
            host,
            state=GameState.LOBBY_READY,
            start_claimed_at=fresh_claim,
        ),
        client=_FakeFirestore(),
    )
    user = SimpleNamespace(firebase_uid=host)

    with pytest.raises(HTTPException) as exc_info:
        asyncio.run(
            use_case.execute(game_id='g-1', current_user=cast(Any, user)),
        )
    assert exc_info.value.status_code == 409
    assert gateway.call_count == 0


def test_stale_claim_is_reclaimed(monkeypatch: pytest.MonkeyPatch) -> None:
    """A claim older than the TTL is treated as stale and may be reclaimed.

    We can't run the full happy path without faking the question writers, so we
    assert via the writer directly that a stale claim does not block, while a
    fresh one does. This guards against a crashed start deadlocking the game.
    """
    lw = GameLifecycleWriter()
    now = datetime.datetime.now(datetime.UTC)
    stale = now - START_CLAIM_TTL - datetime.timedelta(seconds=1)
    fresh = now - datetime.timedelta(seconds=1)
    ref = SimpleNamespace(id='g-1')

    # Stale claim -> reclaimed (a new claim is written).
    recorder = _Recorder()
    lw.claim_start(
        cast(Any, ref),
        cast(Any, recorder),
        state=GameState.LOBBY_READY,
        claimed_at=stale,
        now=now,
    )
    assert recorder.updates
    assert 'start_claimed_at' in recorder.updates[0][1]

    # Fresh claim -> conflict.
    from app.services.game.errors import StateConflictError

    with pytest.raises(StateConflictError):
        lw.claim_start(
            cast(Any, ref),
            cast(Any, _Recorder()),
            state=GameState.LOBBY_READY,
            claimed_at=fresh,
            now=now,
        )
