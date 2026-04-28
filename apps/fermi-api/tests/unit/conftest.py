"""Unit-test fixtures for writer modules.

Only fixtures currently used by unit tests are included.
"""

from collections.abc import Callable
from types import SimpleNamespace
from typing import TYPE_CHECKING

import pytest

if TYPE_CHECKING:
    from fermi_db.models.user import User


class RecorderWriter:
    """Record Firestore-like mutations for assertions.

    Expose ``update`` and ``set`` to mimic batch/transaction surface.
    """

    def __init__(self) -> None:
        """Initialize empty recordings."""
        self.updates: list[tuple[object, dict]] = []
        self.sets: list[tuple[object, dict]] = []

    def update(self, ref: object, data: dict) -> None:
        """Record an update call."""
        self.updates.append((ref, data))

    def set(self, ref: object, data: dict) -> None:
        """Record a set call."""
        self.sets.append((ref, data))


@pytest.fixture
def recorder_writer() -> RecorderWriter:
    """Return a fresh writer recorder for each test."""
    return RecorderWriter()


@pytest.fixture
def fake_doc_ref() -> object:
    """Provide a lightweight fake Firestore document reference."""
    return SimpleNamespace(id='game-test')


@pytest.fixture
def user_factory() -> Callable[..., 'User']:
    """Return a factory that produces user-like objects for writers."""

    def _make(uid: str, name: str | None = 'n', picture: str | None = None) -> 'User':
        return SimpleNamespace(  # type: ignore[return-value]
            firebase_uid=uid,
            display_name=name,
            picture=picture,
        )

    return _make
