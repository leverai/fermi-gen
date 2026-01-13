"""Repository for survival run operations."""

import datetime

from fermi_core.utils import utcnow_naive
from sqlmodel import select, update

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
        run.passed = passed
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
        stmt = (
            update(SurvivalRun)
            .where(SurvivalRun.id == run_id)  # type: ignore
            .values(current_question_uid=question_uid)
            .values(current_deadline=deadline)
            .returning(SurvivalRun)
        )

        result = await self.session.exec(stmt)  # type: ignore
        updated_run = result.first()

        if updated_run is None:
            raise ValueError(f'Survival run {run_id} not found')

        await self.session.commit()

        return updated_run

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
            select(SurvivalRun.questions_answered)
            .where(
                SurvivalRun.user_firebase_uid == user_firebase_uid,  # type: ignore
                SurvivalRun.is_completed == True,  # noqa: E712
            )
            .order_by(SurvivalRun.questions_answered.desc())  # type: ignore
            .limit(1)
        )
        result = (await self.session.exec(stmt)).first()
        return (result or 1) - 1

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
