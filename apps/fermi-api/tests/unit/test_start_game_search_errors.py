"""Unit tests for StartGameUseCase search-error -> HTTP mapping.

The two smart-search failure modes must map to distinct HTTP responses:
- SearchEmbeddingError -> 503 (retryable; OpenAI down/timeout).
- SearchNoResultsError -> 422 with a stable `code` (not retryable; broaden query).

The gateway and Firestore repo/client are mocked; no real DB/OpenAI calls.
"""

# ruff: noqa: D103
from __future__ import annotations

import asyncio
from types import SimpleNamespace
from typing import Any, cast

import pytest
from fastapi import HTTPException

from app.schemas.game import GameState
from app.services.game.errors import SearchEmbeddingError, SearchNoResultsError
from app.services.game.use_cases.start_game import StartGameUseCase


class _FakeRepo:
    """Returns a startable game owned by the host with one active player."""

    def __init__(self, host: str) -> None:
        self._host = host

    async def get_game_fields(self, game_ref: Any, *, fields: list[str]) -> dict:
        return {
            'host': self._host,
            'players': {self._host: {'is_active': True}},
            'state': int(GameState.LOBBY_READY),
            'n_questions': 6,
            'question_round_settings': {
                'n_questions': 6,
                'categories': None,
                'difficulty': None,
                'search_query': 'space scale',
            },
        }


class _RaisingGateway:
    def __init__(self, exc: Exception) -> None:
        self._exc = exc

    async def get_questions_and_answers_docs(
        self,
        *,
        question_round_settings: Any,
        user_ids: list[str],
        game_id: str | None = None,
        host_user_id: str | None = None,
    ) -> Any:
        raise self._exc


class _FakeFirestore:
    def collection(self, _name: str) -> Any:
        return SimpleNamespace(document=lambda _gid: SimpleNamespace(id=_gid))


def _make_use_case(exc: Exception, host: str) -> StartGameUseCase:
    return StartGameUseCase(
        firestore_client=cast(Any, _FakeFirestore()),
        repo=cast(Any, _FakeRepo(host)),
        db_gateway=cast(Any, _RaisingGateway(exc)),
        lifecycle=cast(Any, SimpleNamespace()),
        questions=cast(Any, SimpleNamespace()),
        players_answers=cast(Any, SimpleNamespace()),
    )


def test_embedding_error_maps_to_503() -> None:
    host = 'host-1'
    use_case = _make_use_case(SearchEmbeddingError('boom'), host)
    user = SimpleNamespace(firebase_uid=host)

    with pytest.raises(HTTPException) as exc_info:
        asyncio.get_event_loop().run_until_complete(
            use_case.execute(game_id='g-1', current_user=cast(Any, user)),
        )
    assert exc_info.value.status_code == 503


def test_no_results_error_maps_to_422_with_code() -> None:
    host = 'host-1'
    use_case = _make_use_case(
        SearchNoResultsError(query='asdfqwer', found=0),
        host,
    )
    user = SimpleNamespace(firebase_uid=host)

    with pytest.raises(HTTPException) as exc_info:
        asyncio.get_event_loop().run_until_complete(
            use_case.execute(game_id='g-1', current_user=cast(Any, user)),
        )
    # 422, NOT 503 -- and machine-detectable via a stable `code`.
    assert exc_info.value.status_code == 422
    assert exc_info.value.status_code != 503
    detail = exc_info.value.detail
    assert isinstance(detail, dict)
    assert detail['code'] == 'search_no_results'
    assert 'asdfqwer' in detail['message']
