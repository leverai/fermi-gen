"""Unit tests for avatar registry."""

# ruff: noqa: D103
from pathlib import Path

from app.services.avatars import (
    AVATARS,
    get_avatar_unlock_level,
    get_level_1_avatars,
    get_random_level_1_avatar,
    is_avatar_unlocked,
)

STATIC_AVATARS_DIR = Path('static/avatars')


def test_avatars_registry_matches_static_files() -> None:
    """Ensure AVATARS registry exactly matches files in static/avatars/."""
    # Get all SVG files from static directory (excluding subdirectories like bots/)
    static_files = {f.name for f in STATIC_AVATARS_DIR.glob('*.svg')}
    registry_files = set(AVATARS.keys())

    # Check for missing files in registry
    missing_in_registry = static_files - registry_files
    assert not missing_in_registry, (
        f'Files in static/avatars/ not in AVATARS registry: {missing_in_registry}'
    )

    # Check for extra files in registry
    extra_in_registry = registry_files - static_files
    assert not extra_in_registry, (
        f'Files in AVATARS registry not in static/avatars/: {extra_in_registry}'
    )


def test_get_level_1_avatars_returns_correct_avatars() -> None:
    level_1 = get_level_1_avatars()
    assert len(level_1) == 7
    assert 'animal-bear-fur-svgrepo-com.svg' in level_1
    assert 'animal-cachorro-dog-svgrepo-com.svg' in level_1
    assert 'animal-duck-ducks-svgrepo-com.svg' in level_1


def test_get_random_level_1_avatar_returns_level_1() -> None:
    avatar = get_random_level_1_avatar()
    assert avatar in get_level_1_avatars()
    assert AVATARS[avatar] == 1


def test_get_avatar_unlock_level() -> None:
    assert get_avatar_unlock_level('animal-bear-fur-svgrepo-com.svg') == 1
    assert get_avatar_unlock_level('whale-animals-svgrepo-com.svg') == 100


def test_is_avatar_unlocked() -> None:
    # Level 1 avatar should be unlocked for level 1 user
    assert is_avatar_unlocked('animal-bear-fur-svgrepo-com.svg', 1) is True
    # Level 100 avatar should be locked for level 1 user
    assert is_avatar_unlocked('whale-animals-svgrepo-com.svg', 1) is False
    # Level 100 avatar should be unlocked for level 100 user
    assert is_avatar_unlocked('whale-animals-svgrepo-com.svg', 100) is True
