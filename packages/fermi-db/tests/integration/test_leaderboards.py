"""Behavioral tests for the Survival and Precision Rush leaderboards.

Both leaderboards are raw-SQL CTEs (``DISTINCT ON`` to pick each user's best
run, ``DENSE_RANK`` for tied ranks, ``INNER JOIN "user"`` for display fields) --
Postgres-only constructs. These assert the user-visible ranking behavior: best
run per user, shared ranks on ties, the active-vs-completed tie-break, and that
runs whose user row is missing are dropped by the join.

The repositories return ``LeaderboardRow`` / ``PRLeaderboardRow`` which are
``TypedDict``s, so rows are plain dicts accessed by key.
"""

import datetime
import uuid
from collections.abc import Sequence
from typing import Any

from fermi_db.models.precision_rush import PrecisionRushRun
from fermi_db.models.survival import SurvivalRun
from fermi_db.models.user import User
from fermi_db.repositories.precision_rush_run_repository import (
    PrecisionRushRunRepository,
)
from fermi_db.repositories.survival_run_repository import SurvivalRunRepository
from sqlmodel.ext.asyncio.session import AsyncSession


def _user(uid: str, name: str | None = None) -> User:
    return User(firebase_uid=uid, display_name=name or f'name-{uid}')


def _survival_run(
    uid: str,
    streak: int,
    *,
    is_completed: bool = True,
    started_at: datetime.datetime | None = None,
) -> SurvivalRun:
    return SurvivalRun(
        user_firebase_uid=uid,
        current_question_uid=str(uuid.uuid4()),
        streak=streak,
        is_completed=is_completed,
        started_at=started_at or datetime.datetime(2026, 6, 1),  # noqa: DTZ001
    )


def _pr_run(
    uid: str,
    total_tas: float,
    *,
    is_completed: bool = True,
    started_at: datetime.datetime | None = None,
) -> PrecisionRushRun:
    return PrecisionRushRun(
        user_firebase_uid=uid,
        current_question_uid=str(uuid.uuid4()),
        total_tas=total_tas,
        is_completed=is_completed,
        started_at=started_at or datetime.datetime(2026, 6, 1),  # noqa: DTZ001
    )


async def _seed(session: AsyncSession, rows: Sequence[Any]) -> None:
    session.add_all(rows)
    await session.commit()


def _uids(board: Sequence[Any]) -> list[str]:
    """Leaderboard order of user ids."""
    return [row['user_firebase_uid'] for row in board]


def _ranks(board: Sequence[Any]) -> dict[str, int]:
    """Map of user id -> rank."""
    return {row['user_firebase_uid']: row['rank'] for row in board}


# --------------------------------------------------------------------------- #
# Survival leaderboard
# --------------------------------------------------------------------------- #


async def test_survival_leaderboard_uses_best_streak_per_user(
    session: AsyncSession,
) -> None:
    """A user with several runs appears once, at their highest streak."""
    repo = SurvivalRunRepository(session)
    await _seed(
        session,
        [_user('alice'), _survival_run('alice', 3), _survival_run('alice', 7)],
    )

    board = await repo.get_leaderboard()

    assert _uids(board) == ['alice']
    assert board[0]['streak'] == 7


async def test_survival_leaderboard_dense_ranks_ties(session: AsyncSession) -> None:
    """Tied streaks share a rank and the next rank is contiguous (dense)."""
    repo = SurvivalRunRepository(session)
    await _seed(
        session,
        [
            _user('a'),
            _user('b'),
            _user('c'),
            _survival_run('a', 10),
            _survival_run('b', 10),
            _survival_run('c', 5),
        ],
    )

    board = await repo.get_leaderboard()

    assert _ranks(board) == {'a': 1, 'b': 1, 'c': 2}  # dense: 5 is rank 2, not 3


async def test_survival_leaderboard_drops_runs_without_user_row(
    session: AsyncSession,
) -> None:
    """The INNER JOIN on "user" excludes runs whose user row is missing."""
    repo = SurvivalRunRepository(session)
    await _seed(
        session,
        [
            _user('registered'),
            _survival_run('registered', 8),
            _survival_run('orphan', 99),  # no matching user row
        ],
    )

    board = await repo.get_leaderboard()

    assert _uids(board) == ['registered']
    assert await repo.get_user_leaderboard_entry('orphan') is None


async def test_survival_best_run_prefers_active_over_completed_same_streak(
    session: AsyncSession,
) -> None:
    """At a user's best streak, an active run is chosen over a completed one.

    DISTINCT ON orders ``is_completed ASC``, so the active (False) run wins, and
    the user's displayed entry is marked active.
    """
    repo = SurvivalRunRepository(session)
    await _seed(
        session,
        [
            _user('alice'),
            _survival_run('alice', 7, is_completed=True),
            _survival_run('alice', 7, is_completed=False),
        ],
    )

    entry = await repo.get_user_leaderboard_entry('alice')

    assert entry is not None
    assert entry['streak'] == 7
    assert entry['is_completed'] is False


async def test_survival_user_entry_returns_rank_or_none(
    session: AsyncSession,
) -> None:
    """get_user_leaderboard_entry yields the ranked row, or None with no runs."""
    repo = SurvivalRunRepository(session)
    await _seed(
        session,
        [
            _user('leader'),
            _user('runner_up'),
            _survival_run('leader', 20),
            _survival_run('runner_up', 10),
        ],
    )

    leader = await repo.get_user_leaderboard_entry('leader')
    runner_up = await repo.get_user_leaderboard_entry('runner_up')

    assert leader is not None
    assert leader['rank'] == 1
    assert runner_up is not None
    assert runner_up['rank'] == 2
    assert await repo.get_user_leaderboard_entry('never_played') is None


async def test_survival_leaderboard_filters_by_started_at_window(
    session: AsyncSession,
) -> None:
    """Period leaderboards only count runs started within the window."""
    repo = SurvivalRunRepository(session)
    await _seed(
        session,
        [
            _user('old'),
            _user('recent'),
            _survival_run('old', 50, started_at=datetime.datetime(2026, 1, 1)),  # noqa: DTZ001
            _survival_run('recent', 5, started_at=datetime.datetime(2026, 6, 1)),  # noqa: DTZ001
        ],
    )

    board = await repo.get_leaderboard(start_date=datetime.datetime(2026, 5, 1))  # noqa: DTZ001

    assert _uids(board) == ['recent']


# --------------------------------------------------------------------------- #
# Precision Rush leaderboard
# --------------------------------------------------------------------------- #


async def test_pr_leaderboard_counts_only_completed_runs(
    session: AsyncSession,
) -> None:
    """Only completed runs count, and a user is ranked by their best total_tas."""
    repo = PrecisionRushRunRepository(session)
    await _seed(
        session,
        [
            _user('alice'),
            _pr_run('alice', 90.0, is_completed=True),
            _pr_run('alice', 99.0, is_completed=False),  # in-progress: ignored
        ],
    )

    board = await repo.get_leaderboard()

    assert _uids(board) == ['alice']
    assert board[0]['best_tas'] == 90.0


async def test_pr_leaderboard_dense_ranks_ties(session: AsyncSession) -> None:
    """Tied total_tas share a rank; ranking is contiguous (dense)."""
    repo = PrecisionRushRunRepository(session)
    await _seed(
        session,
        [
            _user('a'),
            _user('b'),
            _user('c'),
            _pr_run('a', 100.0),
            _pr_run('b', 100.0),
            _pr_run('c', 50.0),
        ],
    )

    board = await repo.get_leaderboard()

    assert _ranks(board) == {'a': 1, 'b': 1, 'c': 2}


async def test_pr_leaderboard_drops_runs_without_user_row(
    session: AsyncSession,
) -> None:
    """The INNER JOIN on "user" excludes completed runs with no user row."""
    repo = PrecisionRushRunRepository(session)
    await _seed(
        session,
        [
            _user('registered'),
            _pr_run('registered', 80.0),
            _pr_run('orphan', 95.0),  # no matching user row
        ],
    )

    board = await repo.get_leaderboard()

    assert _uids(board) == ['registered']


async def test_pr_user_entry_returns_rank_or_none(session: AsyncSession) -> None:
    """get_user_leaderboard_entry yields the ranked row, or None with no runs."""
    repo = PrecisionRushRunRepository(session)
    await _seed(
        session,
        [
            _user('leader'),
            _user('runner_up'),
            _pr_run('leader', 99.0),
            _pr_run('runner_up', 60.0),
        ],
    )

    leader = await repo.get_user_leaderboard_entry('leader')
    runner_up = await repo.get_user_leaderboard_entry('runner_up')

    assert leader is not None
    assert leader['rank'] == 1
    assert runner_up is not None
    assert runner_up['rank'] == 2
    assert await repo.get_user_leaderboard_entry('never_played') is None
