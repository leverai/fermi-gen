"""Unit type definitions for Fermi questions.

UnitInfo schema used across fermi-api and fermi-etl for dimensional questions.
"""

from typing_extensions import TypedDict


class UnitInfo(TypedDict):
    """Information about a unit."""

    id: str
    name: str
    abbreviation: str
