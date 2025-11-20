"""Unit tests for services/game/utils.py helpers."""

# ruff: noqa: D103
from typing import Any

import pytest
from fastapi import HTTPException
from starlette.requests import Request

from app.schemas.endpoints import GameConfigResponse, RequestCategory
from app.schemas.game import GameState
from app.services.game import utils


def _make_request(base: str = 'http://example.com') -> Request:
    scope: dict[str, Any] = {
        'type': 'http',
        'http_version': '1.1',
        'method': 'GET',
        'scheme': 'http',
        'path': '/',
        'raw_path': b'/',
        'headers': [],
        'query_string': b'',
        'server': (base.replace('http://', ''), 80),
        'client': ('testclient', 50000),
    }
    return Request(scope)


def test_assert_state_in_raises_on_mismatch() -> None:
    with pytest.raises(HTTPException) as excinfo:
        utils.assert_state_in(GameState.QUESTION_N, GameState.LOBBY_READY)
    assert excinfo.value.status_code == 409
    assert 'State conflict' in excinfo.value.detail
    assert 'LOBBY_READY' in excinfo.value.detail
    assert 'QUESTION_N' in excinfo.value.detail


def test_assert_state_in_noop_on_match() -> None:
    # Should not raise
    utils.assert_state_in(
        GameState.LOBBY_READY,
        GameState.LOBBY_NOT_READY,
        GameState.LOBBY_READY,
    )


def test_assert_state_le_raises_when_greater() -> None:
    with pytest.raises(HTTPException) as excinfo:
        utils.assert_state_le(GameState.QUESTION_LAST, GameState.QUESTION_N)
    assert excinfo.value.status_code == 409
    assert 'State conflict' in excinfo.value.detail
    assert 'QUESTION_LAST' in excinfo.value.detail
    assert 'QUESTION_N' in excinfo.value.detail


def test_assert_state_le_noop_when_leq() -> None:
    utils.assert_state_le(GameState.LOBBY_READY, GameState.QUESTION_N)


def test_get_request_categories_order_and_general_present() -> None:
    cats = utils.get_request_categories()
    # Basic shape
    assert isinstance(cats, list)
    assert all(isinstance(c, GameConfigResponse.CategoryInfo) for c in cats)
    # Ordering and presence
    assert cats[0].name == RequestCategory.PLANET_EARTH
    assert cats[-1].name == RequestCategory.HUMANITY_BY_NUMBERS
    # Picture is relative without Request
    assert cats[0].picture.startswith('/static/categories/')


def test_get_request_categories_builds_absolute_picture_with_request() -> None:
    req = _make_request('http://example.com')
    cats = utils.get_request_categories(req)
    assert cats[0].picture.startswith('http://example.com/static/categories/')
