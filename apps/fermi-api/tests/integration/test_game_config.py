"""Integration tests for GET /game/config."""

from collections.abc import Callable

from fastapi.testclient import TestClient


def _get_auth_headers(
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> dict[str, str]:
    # Unique-ish email per test run to avoid collisions; DB is truncated anyway.
    return get_api_auth_headers(
        'dev.user+config@example.com',
        'password123',
        'Dev Config',
    )


def test_game_config_categories_and_difficulties(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """GET /game/config returns categories and difficulties in expected shape.

    - Categories exclude OTHER
    - Category item has index, name, slug, theme, and absolute picture URL
    - Difficulties order is [EASY, MEDIUM, HARD]
    """
    headers = _get_auth_headers(get_api_auth_headers)
    resp = api_client.get('/api/v1/game/config', headers=headers)
    assert resp.status_code == 200
    data = resp.json()

    # Difficulties
    difficulties = data['difficulties']
    assert isinstance(difficulties, list)
    assert len(difficulties) == 3

    # Check order and shape
    difficulty_names = [d['name'] for d in difficulties]
    assert difficulty_names == ['EASY', 'MEDIUM', 'HARD']

    # Validate each difficulty has required fields
    for d in difficulties:
        assert isinstance(d['name'], str)
        assert d['name'] in ['EASY', 'MEDIUM', 'HARD']
        assert isinstance(d['slug'], str)
        assert d['slug']
        pic = d['picture']
        assert isinstance(pic, str)
        assert pic.startswith('http')
        assert '/static/difficulties/' in pic

    # Categories
    categories = data['categories']
    assert isinstance(categories, list)
    assert len(categories) > 0

    # names present
    names = [c['name'] for c in categories]
    assert 'OTHER' not in names  # excluded by design

    # Validate shape and absolute picture URL
    required_theme_keys = {
        'background',
        'foreground',
        'foreground_negative',
        'foreground_p30',
        'foreground_negative_p30',
    }
    for idx, c in enumerate(categories):
        assert c['index'] == idx
        assert isinstance(c['name'], str)
        assert c['name']
        assert isinstance(c['slug'], str)
        assert c['slug']
        assert set(c['theme'].keys()) == required_theme_keys
        pic = c['picture']
        assert isinstance(pic, str)
        assert pic.startswith('http')
        assert '/static/categories/' in pic
