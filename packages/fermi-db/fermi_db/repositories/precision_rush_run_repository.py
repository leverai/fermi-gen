"""Repository for Precision Rush run operations."""

import datetime
from typing import cast

from fermi_core.utils import utcnow_naive
from sqlalchemy import text
from sqlmodel import func, select, update
from typing_extensions import TypedDict

from fermi_db.models.precision_rush import PrecisionRushRun

from . import BaseRepository


class PRLeaderboardRow(TypedDict):
    """Single row in the Precision Rush leaderboard."""

    rank: int
    user_firebase_uid: str
    display_name: str | None
    picture: str | None
    best_tas: float


class PrecisionRushRunRepository(BaseRepository):
    """Repository for Precision Rush run database operations."""

    # --- CRUD ---

    async def create_run(
        self,
        user_firebase_uid: str,
        question_uid: str,
        deadline: datetime.datetime | None = None,
    ) -> PrecisionRushRun:
        """Create a new Precision Rush run."""
        run = PrecisionRushRun(
            user_firebase_uid=user_firebase_uid,
            current_question_uid=question_uid,
            current_deadline=deadline,
        )
        self.session.add(run)
        await self.session.commit()
        await self.session.refresh(run)
        return run

    async def get_run_by_id(self, run_id: int) -> PrecisionRushRun | None:
        """Get a run by its ID."""
        return await self.session.get(PrecisionRushRun, run_id)

    async def get_active_run(self, user_firebase_uid: str) -> PrecisionRushRun | None:
        """Get the user's active (not completed) run, if any."""
        stmt = select(PrecisionRushRun).where(
            PrecisionRushRun.user_firebase_uid == user_firebase_uid,  # type: ignore
            PrecisionRushRun.is_completed == False,  # noqa: E712
        )
        result = await self.session.exec(stmt)
        return result.first()

    async def end_run(self, run_id: int) -> PrecisionRushRun:
        """Mark a run as completed."""
        stmt = select(PrecisionRushRun).where(PrecisionRushRun.id == run_id)
        result = await self.session.exec(stmt)
        run = result.first()
        if run is None:
            raise ValueError(f'Precision Rush run {run_id} not found')
        run.is_completed = True
        run.ended_at = utcnow_naive()
        await self.session.commit()
        await self.session.refresh(run)
        return run

    # --- Score submission ---

    async def submit_score(
        self,
        run_id: int,
        tas: float,
    ) -> PrecisionRushRun:
        """Increment questions_answered and add TAS.

        Automatically mark as completed after 6 questions.
        """
        stmt = select(PrecisionRushRun).where(PrecisionRushRun.id == run_id)
        result = await self.session.exec(stmt)
        run = result.first()
        if run is None:
            raise ValueError(f'Precision Rush run {run_id} not found')
        run.questions_answered += 1
        run.total_tas += tas
        if run.questions_answered >= 6:
            run.is_completed = True
            run.ended_at = utcnow_naive()
        await self.session.commit()
        await self.session.refresh(run)
        return run

    async def set_current_question(
        self,
        run_id: int,
        question_uid: str,
        deadline: datetime.datetime | None = None,
    ) -> PrecisionRushRun:
        """Set the current question for a run."""
        stmt = (
            update(PrecisionRushRun)
            .where(PrecisionRushRun.id == run_id)  # type: ignore
            .values(current_question_uid=question_uid, current_deadline=deadline)
        )
        result = await self.session.exec(stmt)  # type: ignore
        if result.rowcount == 0:
            raise ValueError(f'Precision Rush run {run_id} not found')
        await self.session.commit()
        return cast(PrecisionRushRun, await self.get_run_by_id(run_id))

    # --- Stats ---

    async def count_user_runs(self, user_firebase_uid: str) -> int:
        """Count total completed runs for a user."""
        stmt = select(func.count(PrecisionRushRun.id)).where(  # type: ignore
            PrecisionRushRun.user_firebase_uid == user_firebase_uid,  # type: ignore
            PrecisionRushRun.is_completed == True,  # noqa: E712
        )
        result = await self.session.execute(stmt)
        return result.scalar() or 0

    async def get_user_best_tas(self, user_firebase_uid: str) -> float:
        """Get the user's best total TAS across completed runs."""
        stmt = select(func.max(PrecisionRushRun.total_tas)).where(  # type: ignore
            PrecisionRushRun.user_firebase_uid == user_firebase_uid,  # type: ignore
            PrecisionRushRun.is_completed == True,  # noqa: E712
        )
        result = await self.session.execute(stmt)
        return result.scalar() or 0.0

    async def get_user_average_tas(self, user_firebase_uid: str) -> float:
        """Get the user's average TAS across completed runs."""
        stmt = select(func.avg(PrecisionRushRun.total_tas)).where(  # type: ignore
            PrecisionRushRun.user_firebase_uid == user_firebase_uid,  # type: ignore
            PrecisionRushRun.is_completed == True,  # noqa: E712
        )
        result = await self.session.execute(stmt)
        return result.scalar() or 0.0

    # --- Daily limits ---

    async def count_today_runs(self, user_firebase_uid: str) -> int:
        """Count runs started today (UTC) for a user."""
        day_start = self._get_day_start_utc()
        stmt = select(func.count(PrecisionRushRun.id)).where(  # type: ignore
            PrecisionRushRun.user_firebase_uid == user_firebase_uid,  # type: ignore
            PrecisionRushRun.started_at >= day_start,
        )
        result = await self.session.execute(stmt)
        return result.scalar() or 0

    async def get_runs_remaining_today(self, user_firebase_uid: str, limit: int) -> int:
        """Get remaining runs for a user today."""
        count = await self.count_today_runs(user_firebase_uid)
        return max(0, limit - count)

    @staticmethod
    def _get_day_start_utc() -> datetime.datetime:
        """Get the start of the current day (00:00 UTC)."""
        now = datetime.datetime.now(datetime.UTC).replace(tzinfo=None)
        return now.replace(hour=0, minute=0, second=0, microsecond=0)

    # --- Leaderboard ---

    async def get_leaderboard(
        self,
        limit: int = 25,
        offset: int = 0,
        start_date: datetime.datetime | None = None,
        end_date: datetime.datetime | None = None,
    ) -> list[PRLeaderboardRow]:
        """Get paginated global leaderboard ranked by best total TAS.

        Use dense ranking (ties share same rank).
        """
        time_filter = ''
        params: dict = {'limit': limit, 'offset': offset}
        if start_date is not None:
            time_filter += ' AND started_at >= :start_date'
            params['start_date'] = start_date
        if end_date is not None:
            time_filter += ' AND started_at < :end_date'
            params['end_date'] = end_date

        query = text(f"""
            WITH best_runs AS (
                SELECT DISTINCT ON (user_firebase_uid)
                    user_firebase_uid, total_tas
                FROM precision_rush_runs
                WHERE is_completed = true{time_filter}
                ORDER BY user_firebase_uid, total_tas DESC
            ),
            ranked AS (
                SELECT
                    user_firebase_uid, total_tas,
                    DENSE_RANK() OVER (ORDER BY total_tas DESC) as rank
                FROM best_runs
            )
            SELECT r.rank, r.user_firebase_uid, u.display_name, u.picture,
                   r.total_tas as best_tas
            FROM ranked r
            JOIN "user" u ON u.firebase_uid = r.user_firebase_uid
            ORDER BY r.rank, r.user_firebase_uid
            LIMIT :limit OFFSET :offset
        """)  # noqa: S608
        result = await self.session.execute(query, params)
        return [
            PRLeaderboardRow(
                rank=row.rank,
                user_firebase_uid=row.user_firebase_uid,
                display_name=row.display_name,
                picture=row.picture,
                best_tas=row.best_tas,
            )
            for row in result.fetchall()
        ]

    async def get_user_leaderboard_entry(
        self,
        user_firebase_uid: str,
        start_date: datetime.datetime | None = None,
        end_date: datetime.datetime | None = None,
    ) -> PRLeaderboardRow | None:
        """Get a specific user's leaderboard entry with rank."""
        time_filter = ''
        params: dict = {'user_firebase_uid': user_firebase_uid}
        if start_date is not None:
            time_filter += ' AND started_at >= :start_date'
            params['start_date'] = start_date
        if end_date is not None:
            time_filter += ' AND started_at < :end_date'
            params['end_date'] = end_date

        query = text(f"""
            WITH best_runs AS (
                SELECT DISTINCT ON (user_firebase_uid)
                    user_firebase_uid, total_tas
                FROM precision_rush_runs
                WHERE is_completed = true{time_filter}
                ORDER BY user_firebase_uid, total_tas DESC
            ),
            ranked AS (
                SELECT
                    user_firebase_uid, total_tas,
                    DENSE_RANK() OVER (ORDER BY total_tas DESC) as rank
                FROM best_runs
            )
            SELECT r.rank, r.user_firebase_uid, u.display_name, u.picture,
                   r.total_tas as best_tas
            FROM ranked r
            JOIN "user" u ON u.firebase_uid = r.user_firebase_uid
            WHERE r.user_firebase_uid = :user_firebase_uid
        """)  # noqa: S608
        result = await self.session.execute(query, params)
        row = result.fetchone()
        if row is None:
            return None
        return PRLeaderboardRow(
            rank=row.rank,
            user_firebase_uid=row.user_firebase_uid,
            display_name=row.display_name,
            picture=row.picture,
            best_tas=row.best_tas,
        )

    async def get_leaderboard_total_count(
        self,
        start_date: datetime.datetime | None = None,
        end_date: datetime.datetime | None = None,
    ) -> int:
        """Get total number of users on the leaderboard."""
        stmt = select(func.count(func.distinct(PrecisionRushRun.user_firebase_uid)))
        if start_date is not None:
            stmt = stmt.where(PrecisionRushRun.started_at >= start_date)
        if end_date is not None:
            stmt = stmt.where(PrecisionRushRun.started_at < end_date)
        stmt = stmt.where(
            PrecisionRushRun.is_completed == True,  # noqa: E712
        )
        result = await self.session.execute(stmt)
        return result.scalar() or 0
