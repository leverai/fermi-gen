"""Base classes for Fermi category."""

from typing import Literal, TypeAlias

from pydantic import BaseModel, Field

TypeCategory: TypeAlias = Literal[
    'PLANET_EARTH',  # Everything terrestrial: land, oceans, animals, etc.
    'HUMANITY_BY_NUMBERS',  # Questions about people, behavior, culture.
    'POP_CULTURE',  # Music, movies, TV, etc.
    'SHOWER_THOUGHTS',  # Random thoughts, not related to any other category.
    'COSMIC_PERSPECTIVE',  # Questions about the universe.
    'OTHER',  # Random thoughts, not related to any other category.
]


class QuestionCategory(BaseModel):
    """Single `category` item."""

    category: TypeCategory = Field(..., description='The question category.')
