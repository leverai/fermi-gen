"""Avatar registry with level gating.

This module defines all available avatars and their unlock levels.
"""

import random

# Avatar filenames mapped to their unlock level.
# Level 1 avatars are available immediately to new players.
# Other levels are placeholders - adjust as needed.
AVATARS: dict[str, int] = {
    # Level 1 - Starter animals
    'animal-bear-fur-svgrepo-com.svg': 1,
    'animal-cachorro-dog-svgrepo-com.svg': 1,
    'animal-duck-ducks-svgrepo-com.svg': 1,
    'animal-elefante-elephant-svgrepo-com.svg': 1,
    'animal-girafa-giraffe-svgrepo-com.svg': 1,
    'animal-leao-lion-svgrepo-com.svg': 1,
    'animal-tiger-tigers-svgrepo-com.svg': 1,
    # Distributed across levels 2-100 (adjust as needed)
    'animals-christmas-deer-svgrepo-com.svg': 5,
    'animals-otter-svgrepo-com.svg': 8,
    'animals-philippine-tarsier-svgrepo-com.svg': 12,
    'animals-rat-svgrepo-com.svg': 15,
    'anteater-svgrepo-com.svg': 18,
    'bee-svgrepo-com.svg': 22,
    'beetle-svgrepo-com.svg': 25,
    'bird-svgrepo-com (1).svg': 28,
    'bird-svgrepo-com (2).svg': 32,
    'bird-svgrepo-com (3).svg': 35,
    'bird-svgrepo-com (4).svg': 38,
    'bird-svgrepo-com.svg': 42,
    'butterfly-animals-svgrepo-com.svg': 45,
    'butterfly-svgrepo-com.svg': 48,
    'cheetah-svgrepo-com.svg': 52,
    'chipmunk-svgrepo-com.svg': 55,
    'crocodile-svgrepo-com.svg': 58,
    'elephant-svgrepo-com.svg': 62,
    'giraffe-svgrepo-com.svg': 65,
    'ladybug-svgrepo-com.svg': 68,
    'llama-svgrepo-com.svg': 72,
    'moose-svgrepo-com.svg': 75,
    'ostrich-svgrepo-com.svg': 78,
    'owl-svgrepo-com.svg': 82,
    'panther-svgrepo-com.svg': 85,
    'porcupine-wild-life-svgrepo-com.svg': 88,
    'sheep-2-svgrepo-com.svg': 90,
    'siberian-husky-svgrepo-com.svg': 92,
    'spider-svgrepo-com.svg': 95,
    'toucan-svgrepo-com.svg': 97,
    'whale-animals-svgrepo-com.svg': 100,
}


def get_level_1_avatars() -> list[str]:
    """Return list of avatar filenames available at level 1."""
    return [name for name, level in AVATARS.items() if level == 1]


def get_random_level_1_avatar() -> str:
    """Return a random avatar filename from level 1 pool."""
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
    return AVATARS[filename]


def is_avatar_unlocked(filename: str, user_level: int) -> bool:
    """Check if an avatar is unlocked for a given user level.

    Args:
        filename: Avatar filename.
        user_level: The user's current level.

    Returns:
        True if the user can use this avatar.

    """
    return user_level >= AVATARS.get(filename, 1)
