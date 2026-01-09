"""Unit tests for avatar registry."""

# ruff: noqa: D103
from pathlib import Path

from app.services.avatars import (
    AVATAR_GROUPS,
    AvatarGroup,
    get_all_avatars,
    get_avatar_group,
    get_avatar_unlock_level,
    get_level_1_avatars,
    get_random_level_1_avatar,
    is_avatar_unlocked,
)

STATIC_AVATARS_DIR = Path('static/avatars')


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
    assert len(level_1) == 7
    filenames = [filename for _, filename in level_1]
    assert 'animal-bear-fur-svgrepo-com.svg' in filenames
    assert 'animal-cachorro-dog-svgrepo-com.svg' in filenames
    assert 'animal-duck-ducks-svgrepo-com.svg' in filenames


def test_get_random_level_1_avatar_returns_level_1() -> None:
    group, filename = get_random_level_1_avatar()
    assert (group, filename) in get_level_1_avatars()
    assert AVATAR_GROUPS[group][filename] == 1


def test_get_avatar_unlock_level() -> None:
    assert get_avatar_unlock_level('animal-bear-fur-svgrepo-com.svg') == 1
    assert get_avatar_unlock_level('whale-animals-svgrepo-com.svg') == 100


def test_get_avatar_group() -> None:
    assert get_avatar_group('animal-bear-fur-svgrepo-com.svg') == AvatarGroup.ANIMALS


def test_get_all_avatars() -> None:
    all_avatars = get_all_avatars()
    assert 'animal-bear-fur-svgrepo-com.svg' in all_avatars
    group, level = all_avatars['animal-bear-fur-svgrepo-com.svg']
    assert group == AvatarGroup.ANIMALS
    assert level == 1


def test_is_avatar_unlocked() -> None:
    # Level 1 avatar should be unlocked for level 1 user
    assert is_avatar_unlocked('animal-bear-fur-svgrepo-com.svg', 1) is True
    # Level 100 avatar should be locked for level 1 user
    assert is_avatar_unlocked('whale-animals-svgrepo-com.svg', 1) is False
    # Level 100 avatar should be unlocked for level 100 user
    assert is_avatar_unlocked('whale-animals-svgrepo-com.svg', 100) is True
