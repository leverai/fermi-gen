"""Behavioral tests pinning UserRepository's login-streak date math.

The streak lives in ``UserRepository._update_login_streak`` and is driven from
the public ``login_user`` entry point (called on every non-first login). The
math has two distinct comparisons that are easy to conflate:

* the *same-day* guard is **calendar-day** based (``last_login_at.date() ==
  now.date()``), and
* the *increment* test is a **24h-rolling** delta (``(now - last_login_at).days
  == 1``), not a calendar-day delta.

That split is the subtle part, so the tests drive ``last_login_at`` to
controlled offsets from ``utcnow_naive()`` and assert ``login_streak`` after
each transition. We use generous (half-day) offsets so a test never straddles a
``.days`` rounding boundary and turns flaky on the wall clock.

``register_user`` is the genuine "first login ever" path (it sets
``login_streak = 1`` directly and never touches ``_update_login_streak``); the
docstring's ``last_login_at is None`` branch is unreachable because the model
defaults ``last_login_at`` via ``utcnow_naive`` -- pinned below.
"""

from datetime import datetime, timedelta

import pytest
from fermi_core import utcnow_naive
from fermi_db.models.user import User
from fermi_db.repositories.user_repository import UserRepository
from sqlmodel.ext.asyncio.session import AsyncSession

_CLAIMS = {'uid': 'u-streak', 'email': 'u-streak@example.com', 'name': 'Streaky'}


def _user(*, last_login_at: datetime, login_streak: int) -> User:
    """Build a persisted-shape User with an explicit streak position."""
    return User(
        firebase_uid='u-streak',
        email='u-streak@example.com',
        display_name='Streaky',
        login_streak=login_streak,
        last_login_at=last_login_at,
    )


async def _seed(session: AsyncSession, user: User) -> None:
    session.add(user)
    await session.commit()
    await session.refresh(user)


# --------------------------------------------------------------------------- #
# First login ever
# --------------------------------------------------------------------------- #


async def test_register_user_starts_streak_at_one(session: AsyncSession) -> None:
    """The real first-login path (``register_user``) seeds the streak at 1."""
    repo = UserRepository(session)

    user = await repo.register_user(_CLAIMS)

    assert user.login_streak == 1


# --------------------------------------------------------------------------- #
# login_user -> _update_login_streak transitions
# --------------------------------------------------------------------------- #


async def test_same_calendar_day_relogin_leaves_streak_unchanged(
    session: AsyncSession,
) -> None:
    """A second login on the same calendar day does not move the streak."""
    repo = UserRepository(session)
    # Earlier the same UTC day (same .date()), regardless of hour gap.
    earlier_today = utcnow_naive().replace(hour=0, minute=1, second=0, microsecond=0)
    user = _user(last_login_at=earlier_today, login_streak=5)
    await _seed(session, user)

    await repo.login_user(user, _CLAIMS)

    assert user.login_streak == 5


async def test_next_day_login_increments_streak(session: AsyncSession) -> None:
    """A login ~1 day after the last (delta.days == 1) increments by one."""
    repo = UserRepository(session)
    # 1.5 days ago: a different calendar date AND (now - then).days == 1.
    yesterday = utcnow_naive() - timedelta(days=1, hours=12)
    user = _user(last_login_at=yesterday, login_streak=3)
    await _seed(session, user)

    await repo.login_user(user, _CLAIMS)

    assert user.login_streak == 4


async def test_gap_longer_than_one_day_resets_streak_to_one(
    session: AsyncSession,
) -> None:
    """A gap of more than a day (delta.days > 1) resets the streak to 1.

    This reset branch was previously uncovered everywhere -- it is the whole
    point of this file.
    """
    repo = UserRepository(session)
    five_days_ago = utcnow_naive() - timedelta(days=5)
    user = _user(last_login_at=five_days_ago, login_streak=10)
    await _seed(session, user)

    await repo.login_user(user, _CLAIMS)

    assert user.login_streak == 1


async def test_different_calendar_day_but_under_24h_resets_not_increments(
    session: AsyncSession,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A new calendar day reached in <24h resets (delta.days == 0), not +1.

    DIVERGENCE pin: the docstring frames the increment as "last login was
    yesterday", but the code increments only when the *24h-rolling* delta is
    exactly 1 day. A login that crosses midnight after a short gap (e.g. 23:30
    -> next-day 06:00) is a new calendar day yet ``(now - then).days == 0``, so
    it falls through to the reset branch and the streak drops to 1 instead of
    incrementing. This test pins that real behavior.

    The repo clock is pinned via ``monkeypatch`` so the now/last_login
    relationship is fixed regardless of the wall clock -- a real-``utcnow``
    version hard-fails whenever the suite runs between 23:30 and 24:00 UTC
    (the seeded "yesterday 23:30" becomes >=24h old and ``.days`` flips to 1).
    """
    repo = UserRepository(session)
    # Fixed "now" at 06:00, and a last login at 23:30 the *previous* calendar
    # day: .date() differs while the 24h-rolling delta is still 0 days.
    fixed_now = datetime(2024, 6, 1, 6, 0, 0)  # noqa: DTZ001
    prev_calendar_day = datetime(2024, 5, 31, 23, 30, 0)  # noqa: DTZ001
    assert prev_calendar_day.date() != fixed_now.date()
    assert (fixed_now - prev_calendar_day).days == 0
    monkeypatch.setattr(
        'fermi_db.repositories.user_repository.utcnow_naive',
        lambda: fixed_now,
    )
    user = _user(last_login_at=prev_calendar_day, login_streak=7)
    await _seed(session, user)

    await repo.login_user(user, _CLAIMS)

    assert user.login_streak == 1


async def test_streak_update_advances_last_login_at(session: AsyncSession) -> None:
    """On any streak-changing login, last_login_at is moved forward to now."""
    repo = UserRepository(session)
    yesterday = utcnow_naive() - timedelta(days=1, hours=12)
    user = _user(last_login_at=yesterday, login_streak=1)
    await _seed(session, user)

    await repo.login_user(user, _CLAIMS)

    assert user.last_login_at > yesterday
