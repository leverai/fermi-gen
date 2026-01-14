"""Repository for survival run operations."""

import datetime
from typing import cast

from fermi_core.utils import utcnow_naive
from sqlmodel import func, select, update

from fermi_db.models import SurvivalRun

from . import BaseRepository


class SurvivalRunRepository(BaseRepository):
    """Repository for survival run database operations."""

    async def create_run(
        self,
        user_firebase_uid: str,
        question_uid: str,
        deadline: datetime.datetime | None = None,
    ) -> SurvivalRun:
        """Create a new survival run for a user."""
        run = SurvivalRun(
            user_firebase_uid=user_firebase_uid,
            current_question_uid=question_uid,
            current_deadline=deadline,
        )
        self.session.add(run)
        await self.session.commit()
        await self.session.refresh(run)
        return run

    async def get_run_by_id(self, run_id: int) -> SurvivalRun | None:
        """Get a run by its ID."""
        return await self.session.get(SurvivalRun, run_id)

    async def get_active_run(self, user_firebase_uid: str) -> SurvivalRun | None:
        """Get the user's active (not completed) run, if any."""
        stmt = select(SurvivalRun).where(
            SurvivalRun.user_firebase_uid == user_firebase_uid,  # type: ignore
            SurvivalRun.is_completed == False,  # noqa: E712
        )
        result = await self.session.exec(stmt)
        return result.first()

    async def get_active_run_id(self, user_firebase_uid: str) -> int | None:
        """Get the user's active run ID, if any."""
        stmt = (
            select(SurvivalRun.id)
            .where(
                SurvivalRun.user_firebase_uid == user_firebase_uid,  # type: ignore
                SurvivalRun.is_completed == False,  # noqa: E712
            )
            .order_by(SurvivalRun.started_at.desc())  # type: ignore
            .limit(1)
        )
        result = await self.session.exec(stmt)
        return result.first() or None

    async def end_run(self, run_id: int) -> SurvivalRun:
        """Mark a run as completed."""
        stmt = select(SurvivalRun).where(SurvivalRun.id == run_id)
        result = await self.session.exec(stmt)
        run = result.first()
        if run is None:
            raise ValueError(f'Survival run {run_id} not found')
        run.is_completed = True
        run.ended_at = utcnow_naive()
        await self.session.commit()
        await self.session.refresh(run)
        return run

    async def submit_score(
        self,
        run_id: int,
        score: float,
        *,
        passed: bool,
    ) -> SurvivalRun:
        """Increment run's questions_answered and add to total_score.

        If the run is not passed, mark it as completed.
        """
        stmt = select(SurvivalRun).where(SurvivalRun.id == run_id)
        result = await self.session.exec(stmt)
        run = result.first()
        if run is None:
            raise ValueError(f'Survival run {run_id} not found')
        run.questions_answered += 1
        run.total_score += score
        if not passed:
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
    ) -> SurvivalRun:
        """Set the current question for a run efficiently."""
        # 1. Perform the update (fast, no returning)
        stmt = (
            update(SurvivalRun)
            .where(SurvivalRun.id == run_id)  # type: ignore
            .values(current_question_uid=question_uid, current_deadline=deadline)
        )
        result = await self.session.exec(stmt)  # type: ignore

        if result.rowcount == 0:
            raise ValueError(f'Survival run {run_id} not found')

        await self.session.commit()

        # 2. Fetch the fresh object (standard select)
        # This ensures you have a true ORM instance
        return cast(SurvivalRun, await self.get_run_by_id(run_id))

    async def get_user_best_run(self, user_firebase_uid: str) -> SurvivalRun | None:
        """Get the user's best run by questions_answered."""
        stmt = (
            select(SurvivalRun)
            .where(
                SurvivalRun.user_firebase_uid == user_firebase_uid,  # type: ignore
                SurvivalRun.is_completed == True,  # noqa: E712
            )
            .order_by(SurvivalRun.questions_answered.desc())  # type: ignore
            .limit(1)
        )
        result = await self.session.exec(stmt)
        return result.first()

    async def get_user_best_streak(self, user_firebase_uid: str) -> int:
        """Get the user's best streak of completed runs."""
        stmt = (
            select(SurvivalRun.questions_answered, SurvivalRun.is_completed)
            .where(
                SurvivalRun.user_firebase_uid == user_firebase_uid,  # type: ignore
            )
            .order_by(SurvivalRun.questions_answered.desc())  # type: ignore
            .order_by(SurvivalRun.is_completed.asc())  # type: ignore
            .limit(1)
        )
        result = (await self.session.exec(stmt)).first()
        if result is None:
            return 0
        q_answered, is_completed = result
        if is_completed:
            return q_answered - 1
        return q_answered

    async def get_current_streak(self, user_firebase_uid: str) -> int:
        """Get the user's current active run streak."""
        stmt = (
            select(SurvivalRun.questions_answered)
            .where(
                SurvivalRun.user_firebase_uid == user_firebase_uid,  # type: ignore
                SurvivalRun.is_completed == False,  # noqa: E712
            )
            .order_by(SurvivalRun.started_at.desc())  # type: ignore
            .limit(1)
        )
        result = (await self.session.exec(stmt)).first()
        return result or 0

    async def count_user_runs(self, user_firebase_uid: str) -> int:
        """Count total completed runs for a user."""
        from sqlmodel import func

        stmt = select(func.count(SurvivalRun.id)).where(  # type: ignore
            SurvivalRun.user_firebase_uid == user_firebase_uid,  # type: ignore
            SurvivalRun.is_completed == True,  # noqa: E712
        )
        result = await self.session.execute(stmt)
        return result.scalar() or 0

    async def get_user_total_questions(self, user_firebase_uid: str) -> int:
        """Get total questions answered across all completed runs."""
        from sqlmodel import func

        stmt = select(func.sum(SurvivalRun.questions_answered)).where(  # type: ignore
            SurvivalRun.user_firebase_uid == user_firebase_uid,  # type: ignore
            SurvivalRun.is_completed == True,  # noqa: E712
        )
        result = await self.session.execute(stmt)
        return result.scalar() or 0

    async def get_user_average_streak(self, user_firebase_uid: str) -> float:
        """Get average questions per completed run."""
        from sqlmodel import func

        stmt = select(func.avg(SurvivalRun.questions_answered)).where(  # type: ignore
            SurvivalRun.user_firebase_uid == user_firebase_uid,  # type: ignore
            SurvivalRun.is_completed == True,  # noqa: E712
        )
        result = await self.session.execute(stmt)
        return result.scalar() or 0.0

    async def count_today_runs(self, user_firebase_uid: str) -> int:
        """Count runs started today (UTC midnight to now) for a user.

        Args:
            user_firebase_uid: The user's Firebase UID.

        Returns:
            Number of runs started today.

        """
        from sqlmodel import func

        day_start = self._get_day_start_utc()
        stmt = select(func.count(SurvivalRun.id)).where(  # type: ignore
            SurvivalRun.user_firebase_uid == user_firebase_uid,  # type: ignore
            SurvivalRun.started_at >= day_start,
        )
        result = await self.session.execute(stmt)
        return result.scalar() or 0

    async def get_runs_remaining_today(
        self,
        user_firebase_uid: str,
        limit: int,
    ) -> int:
        """Get remaining runs for a user today.

        Args:
            user_firebase_uid: The user's Firebase UID.
            limit: Maximum runs allowed per day.

        Returns:
            Number of runs remaining (0 if at limit).

        """
        count = await self.count_today_runs(user_firebase_uid)
        return max(0, limit - count)

    @staticmethod
    def _get_day_start_utc() -> datetime.datetime:
        """Get the start of the current day (00:00 UTC).

        Returns:
            datetime at 00:00:00 of the current day.

        """
        now = datetime.datetime.now(datetime.UTC).replace(tzinfo=None)
        return now.replace(hour=0, minute=0, second=0, microsecond=0)

    async def count_user_survival_runs(self, user_firebase_uid: str) -> int:
        """Count survival runs for a user."""
        stmt = select(func.count(SurvivalRun.id)).where(  # type: ignore
            SurvivalRun.user_firebase_uid == user_firebase_uid,
        )  # type: ignore
        result = await self.session.exec(stmt)
        return result.one() or 0
