"""Avatar registry with level gating and grouping.

This module defines all available avatars organized by group with their unlock levels.
"""

import random
from enum import StrEnum


class AvatarGroup(StrEnum):
    """Avatar group/category enum."""

    ANIMALS = 'animals'
    LETTERS = 'letters'
    FOLKS = 'folks'


# Avatar groups: dict mapping group -> (filename -> unlock_level)
# Each group corresponds to a subdirectory under static/avatars/
AVATAR_GROUPS: dict[AvatarGroup, dict[str, int]] = {
    AvatarGroup.LETTERS: {
        'a.svg': 1,
        'b.svg': 1,
        'c.svg': 1,
        'd.svg': 1,
        'e.svg': 1,
        'f.svg': 1,
        'g.svg': 1,
        'h.svg': 1,
        'i.svg': 1,
        'j.svg': 1,
        'k.svg': 1,
        'l.svg': 1,
        'm.svg': 1,
        'n.svg': 1,
        'o.svg': 1,
        'p.svg': 1,
        'q.svg': 1,
        'r.svg': 1,
        's.svg': 1,
        't.svg': 1,
        'u.svg': 1,
        'v.svg': 1,
        'w.svg': 1,
        'x.svg': 1,
        'y.svg': 1,
        'z.svg': 1,
    },
    AvatarGroup.ANIMALS: {
        # Level 1 - Starter animals
        'toucan.svg': 3,
        'beetle.svg': 3,
        'bird2.svg': 6,
        'bird3.svg': 6,
        'moose.svg': 9,
        # Higher Levels
        'sloth.svg': 15,
        'ladybug.svg': 18,
        'panther.svg': 21,
        'porcupine.svg': 21,
        'bee.svg': 24,
        'cheetah.svg': 27,
        'owl.svg': 30,
        'bird.svg': 33,
        'flamingo.svg': 36,
        'deer.svg': 39,
        'fox.svg': 42,
    },
    AvatarGroup.FOLKS: {
        'two.svg': 5,
        'three.svg': 5,
        'four.svg': 5,
        'five.svg': 5,
        'six.svg': 5,
        'seven.svg': 5,
        'eight.svg': 5,
        'nine.svg': 5,
        'ten.svg': 5,
    },
}


def get_all_avatars() -> dict[str, tuple[AvatarGroup, int]]:
    """Return all avatars as filename -> (group, unlock_level)."""
    result: dict[str, tuple[AvatarGroup, int]] = {}
    for group, avatars in AVATAR_GROUPS.items():
        for filename, level in avatars.items():
            result[filename] = (group, level)
    return result


def get_level_1_avatars() -> list[tuple[AvatarGroup, str]]:
    """Return list of (group, filename) tuples available at level 1."""
    result: list[tuple[AvatarGroup, str]] = []
    for group, avatars in AVATAR_GROUPS.items():
        for filename, level in avatars.items():
            if level == 1:
                result.append((group, filename))
    return result


def get_random_level_1_avatar() -> tuple[AvatarGroup, str]:
    """Return a random (group, filename) from level 1 pool."""
    return random.choice(get_level_1_avatars())


def get_avatar_unlock_level(filename: str) -> int:
    """Get the unlock level for an avatar.

    Args:
        filename: Avatar filename (e.g., 'animal-bear-fur-svgrepo-com.svg').

    Returns:
        The level required to unlock this avatar.

    Raises:
        KeyError: If the avatar filename is not in the registry.

    """
    for avatars in AVATAR_GROUPS.values():
        if filename in avatars:
            return avatars[filename]
    raise KeyError(f'Avatar not found: {filename}')


def get_avatar_group(filename: str) -> AvatarGroup:
    """Get the group for an avatar.

    Args:
        filename: Avatar filename.

    Returns:
        The group this avatar belongs to.

    Raises:
        KeyError: If the avatar filename is not in the registry.

    """
    for group, avatars in AVATAR_GROUPS.items():
        if filename in avatars:
            return group
    raise KeyError(f'Avatar not found: {filename}')


def is_avatar_unlocked(filename: str, user_level: int) -> bool:
    """Check if an avatar is unlocked for a given user level.

    Args:
        filename: Avatar filename.
        user_level: The user's current level.

    Returns:
        True if the user can use this avatar.

    """
    try:
        return user_level >= get_avatar_unlock_level(filename)
    except KeyError:
        return True  # Unknown avatars default to unlocked
