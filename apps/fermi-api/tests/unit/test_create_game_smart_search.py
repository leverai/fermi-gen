"""Unit tests for smart-search gating in GameService.create_game.

These exercise the create-time guards only (reject a search when the flag is off;
null categories when a search is present), with the Firestore writers and client
mocked. No real Firestore/DB calls are made.
"""

# ruff: noqa: D103
from __future__ import annotations

import asyncio
from types import SimpleNamespace
from typing import Any, cast

import pytest
from fastapi import HTTPException

from app.schemas.endpoints import (
    GameCreateRequest,
    QuestionRoundSettings,
    RequestCategory,
)
from app.services.game import service as service_mod
from app.services.game.service import GameService


class _RecorderBatch:
    def __init__(self) -> None:
        self.updates: list[tuple[Any, dict]] = []

    def update(self, ref: Any, data: dict) -> None:
        self.updates.append((ref, data))

    async def commit(self) -> None:
        return None


class _FakeFirestore:
    def __init__(self) -> None:
        self.last_batch = _RecorderBatch()

    def batch(self) -> _RecorderBatch:
        return self.last_batch

    def collection(self, _name: str) -> Any:
        return SimpleNamespace(id='games-collection')


class _FakeLifecycleWriter:
    async def create_game(self, *, games_ref: Any, writer: Any) -> Any:
        return SimpleNamespace(id='game-abc')

    def set_ready(self, *, game_ref: Any, writer: Any) -> None:
        return None


class _FakePlayersWriter:
    def __init__(self) -> None:
        self.called = False

    def set_players(
        self,
        *,
        game_ref: Any,
        writer: Any,
        host_id: str,
        users: list[Any],
        max_players: int,
    ) -> None:
        self.called = True


class _FakeHostingRepo:
    def __init__(self, *, allowed: bool = True) -> None:
        self._allowed = allowed

    async def get_hostings_remaining(self, *, user_id: int, limit: int) -> bool:
        return self._allowed


def _make_service() -> GameService:
    svc = GameService(db_client=cast(Any, SimpleNamespace()))
    svc._lifecycle_writer = cast(Any, _FakeLifecycleWriter())
    svc._players_writer = cast(Any, _FakePlayersWriter())
    return svc


def _make_user() -> Any:
    return SimpleNamespace(id=1, firebase_uid='host-1')


def _persisted_settings(batch: _RecorderBatch) -> dict[str, Any]:
    # The create_game flow performs a single batch.update with the round settings.
    assert batch.updates, 'expected a batch.update with round settings'
    _, data = batch.updates[-1]
    return data['question_round_settings']


def test_create_game_rejects_search_when_flag_off(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(service_mod.settings, 'smart_search_enabled', False)
    monkeypatch.setattr(service_mod.settings, 'invite_url_base', None)
    svc = _make_service()
    payload = GameCreateRequest(
        question_round_settings=QuestionRoundSettings(
            difficulty=None,
            search_query='space scale',
        ),
    )
    fs = _FakeFirestore()
    request = SimpleNamespace(base_url='http://test/')

    with pytest.raises(HTTPException) as exc_info:
        asyncio.get_event_loop().run_until_complete(
            svc.create_game(
                request=cast(Any, request),
                payload=payload,
                current_user=_make_user(),
                firestore_client=cast(Any, fs),
                hosting_repo=cast(Any, _FakeHostingRepo(allowed=True)),
            ),
        )
    assert exc_info.value.status_code == 403
    # Rejected before persisting anything.
    assert fs.last_batch.updates == []


def test_create_game_nulls_categories_when_search_present(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(service_mod.settings, 'smart_search_enabled', True)
    monkeypatch.setattr(service_mod.settings, 'invite_url_base', None)
    svc = _make_service()
    payload = GameCreateRequest(
        question_round_settings=QuestionRoundSettings(
            difficulty=None,
            categories=[RequestCategory.PLANET_EARTH],
            search_query='space scale',
        ),
    )
    fs = _FakeFirestore()
    request = SimpleNamespace(base_url='http://test/')

    asyncio.get_event_loop().run_until_complete(
        svc.create_game(
            request=cast(Any, request),
            payload=payload,
            current_user=_make_user(),
            firestore_client=cast(Any, fs),
            hosting_repo=cast(Any, _FakeHostingRepo(allowed=True)),
        ),
    )
    persisted = _persisted_settings(fs.last_batch)
    # Search replaces categories: categories nulled, query preserved.
    assert persisted['categories'] is None
    assert persisted['search_query'] == 'space scale'


def test_create_game_keeps_categories_when_no_search(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(service_mod.settings, 'smart_search_enabled', True)
    monkeypatch.setattr(service_mod.settings, 'invite_url_base', None)
    svc = _make_service()
    payload = GameCreateRequest(
        question_round_settings=QuestionRoundSettings(
            difficulty=None,
            categories=[RequestCategory.PLANET_EARTH],
        ),
    )
    fs = _FakeFirestore()
    request = SimpleNamespace(base_url='http://test/')

    asyncio.get_event_loop().run_until_complete(
        svc.create_game(
            request=cast(Any, request),
            payload=payload,
            current_user=_make_user(),
            firestore_client=cast(Any, fs),
            hosting_repo=cast(Any, _FakeHostingRepo(allowed=True)),
        ),
    )
    persisted = _persisted_settings(fs.last_batch)
    assert persisted['categories'] == [RequestCategory.PLANET_EARTH.value]
    assert persisted['search_query'] is None
