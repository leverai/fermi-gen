"""Utility functions for the database repositories."""

import re
from typing import TYPE_CHECKING, Any

import randomname

if TYPE_CHECKING:
    from fastapi import Request


def _extract_animal_name_from_svgrepo_avatar(filename: str) -> str:
    """Extract and clean the animal name from SVG filenames like:
    ["animal" or "animals"-]<animal_name>-"svgrepo-com.svg"
    Removes unwanted tokens such as digits, 'cartoon', 'fauna', 'animals', 'wild-life'.
    Falls back to 'animal' if nothing meaningful remains.
    """
    # Step 1: Extract main name segment
    pattern = r'^(?:animals?-)?(.+?)-svgrepo-com\.svg$'
    match = re.match(pattern, filename)
    if not match:
        return 'animal'

    name = match.group(1).lower()

    # Step 2: Remove unwanted parts
    name = re.sub(r'\b(cartoon|fauna|animals?|wild-?life)\b', '', name)
    name = re.sub(r'\d+', '', name)  # remove digits
    name = re.sub(r'-+', '-', name)  # collapse multiple hyphens
    name = name.strip('-')  # trim leftover hyphens

    # Step 3: Fallback
    return name if name else 'animal'


def _get_random_avatar_path() -> str:
    """Get a random avatar path relative to `static` from level-1 pool."""
    from app.services.avatars import get_random_level_1_avatar

    return f'avatars/{get_random_level_1_avatar()}'


def enrich_firebase_claims(
    request: 'Request',
    firebase_claims: dict[str, Any],
) -> dict[str, Any]:
    """Enrich the firebase claims with a random avatar and display name if needed."""
    if not firebase_claims.get('picture'):
        avatar_path = _get_random_avatar_path()
        firebase_claims['picture'] = str(
            request.url_for('static', path=avatar_path),
        )
    if not firebase_claims.get('name'):
        firebase_claims['name'] = randomname.get_name(
            adj=(
                'food',
                'character',
                'age',
                'materials',
                'linguistics',
                'complexity',
                'emotions',
                'appearance',
                'speed',
                'physics',
                'algorithms',
            ),
            noun=randomname.NOUNS,
            sep=' ',
        ).title()

    return firebase_claims
