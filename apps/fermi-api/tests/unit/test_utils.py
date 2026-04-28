"""Unit tests for services/game/utils.py helpers."""

# ruff: noqa: D103
from typing import Any

from fastapi import Request

from app.schemas.endpoints import GameConfigResponse, RequestCategory
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


def test_get_request_categories_order_and_general_present() -> None:
    cats = utils.get_request_categories()
    # Basic shape
    assert isinstance(cats, list)
    assert all(isinstance(c, GameConfigResponse.CategoryInfo) for c in cats)
    # Ordering and presence
    assert cats[0].name == RequestCategory.PLANET_EARTH
    assert cats[-1].name == RequestCategory.HUMANITY_BY_NUMBERS
