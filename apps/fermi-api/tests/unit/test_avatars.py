"""Unit tests for avatar registry."""

# ruff: noqa: D103
from pathlib import Path

from app.services.avatars import (
    AVATAR_GROUPS,
    AvatarGroup,
    get_level_1_avatars,
    get_random_level_1_avatar,
)

API_DIR = Path(__file__).parent.parent.parent
STATIC_AVATARS_DIR = API_DIR / 'static/avatars'


def test_avatars_registry_matches_static_files() -> None:
    """Ensure AVATAR_GROUPS registry exactly matches files in static/avatars/
    subdirectories.
    """
    for group in AvatarGroup:
        group_dir = STATIC_AVATARS_DIR / group
        if not group_dir.exists():
            # Empty groups (letters, folks) should have no registry entries
            assert not AVATAR_GROUPS[group], (
                f'Registry has entries for non-existent group: {group}'
            )
            continue

        # Get all SVG files from the group directory
        static_files = {f.name for f in group_dir.glob('*.svg')}
        registry_files = set(AVATAR_GROUPS[group].keys())

        # Check for missing files in registry
        missing_in_registry = static_files - registry_files
        assert not missing_in_registry, (
            f'Files in static/avatars/{group}/ not in AVATAR_GROUPS registry: '
            f'{missing_in_registry}'
        )

        # Check for extra files in registry
        extra_in_registry = registry_files - static_files
        assert not extra_in_registry, (
            f'Files in AVATAR_GROUPS[{group}] not in static/avatars/{group}/: '
            f'{extra_in_registry}'
        )


def test_get_level_1_avatars_returns_correct_avatars() -> None:
    level_1 = get_level_1_avatars()
    assert len(level_1) == 26


def test_get_random_level_1_avatar_returns_level_1() -> None:
    group, filename = get_random_level_1_avatar()
    assert (group, filename) in get_level_1_avatars()
    assert AVATAR_GROUPS[group][filename] == 1
