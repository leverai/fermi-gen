"""Repository for question vote operations."""

from collections.abc import Iterable
from uuid import UUID

from fermi_core.utils import utcnow_naive
from sqlmodel import func, select

from fermi_db.exceptions import QuestionNotFoundError
from fermi_db.models import Fermi, QuestionVote, VoteVerdict

from . import BaseRepository


class QuestionVotesRepository(BaseRepository):
    """Handles CRUD and toggle logic for per-user question votes."""

    async def get_vote(
        self,
        question_uid: UUID,
        user_firebase_uid: str,
    ) -> QuestionVote | None:
        """Get a user's vote for a question, if any."""
        statement = select(QuestionVote).where(
            (QuestionVote.question_uid == question_uid)
            & (QuestionVote.user_firebase_uid == user_firebase_uid),
        )
        result = await self.session.exec(statement)
        return result.one_or_none()

    async def set_verdict(
        self,
        *,
        question_uid: UUID,
        user_firebase_uid: str,
        verdict: VoteVerdict,
    ) -> VoteVerdict:
        """Create or update a user's verdict for a question.

        Returns the resulting verdict after applying toggle rules.
        """
        # Coerce to enum in case callers pass raw ints
        try:
            # Ensure question exists for FK sanity
            qres = await self.session.exec(
                select(Fermi.uid).where(
                    Fermi.uid == question_uid,
                ),
            )
            _ = qres.one()
        except Exception as exc:
            raise QuestionNotFoundError(question_uid) from exc

        existing_vote = await self.get_vote(question_uid, user_firebase_uid)
        verdict_int = int(VoteVerdict(verdict))
        if existing_vote and int(existing_vote.verdict) == verdict_int:
            return verdict

        if existing_vote:
            # Current verdict is different from requested verdict. Add them.
            # Update existing and commit.
            existing_vote.verdict = VoteVerdict(
                int(existing_vote.verdict) + verdict_int,
            )
            existing_vote.updated_at = utcnow_naive()
            self.session.add(existing_vote)
            await self.session.commit()
            return VoteVerdict(int(existing_vote.verdict))

        new_vote = QuestionVote(
            question_uid=question_uid,
            user_firebase_uid=user_firebase_uid,
            verdict=verdict_int,
        )
        self.session.add(new_vote)
        await self.session.commit()
        return VoteVerdict(verdict_int)

    async def _get_vote_count(self, question_uid: UUID, verdict: VoteVerdict) -> int:
        """Return vote count for a question and verdict."""
        stmt = (
            select(func.count())
            .select_from(QuestionVote)
            .where(
                (QuestionVote.question_uid == question_uid)
                & (QuestionVote.verdict == int(verdict)),
            )
        )
        return (await self.session.exec(stmt)).one()

    async def get_upvotes(self, question_uid: UUID) -> int:
        """Return upvotes counted from questions_votes."""
        return await self._get_vote_count(question_uid, VoteVerdict.UPVOTE)

    async def get_downvotes(self, question_uid: UUID) -> int:
        """Return downvotes counted from questions_votes."""
        return await self._get_vote_count(question_uid, VoteVerdict.DOWNVOTE)

    async def get_players_vote_verdicts(
        self,
        question_uid: UUID,
        user_ids: Iterable[str],
    ) -> dict[str, VoteVerdict]:
        """Return verdicts for a collection of user ids.
        Return object is like {firebase_uid: VoteVerdict}.
        Note, if user hasn't voted, return 0 for the verdict.
        """
        verdicts: dict[str, VoteVerdict] = dict.fromkeys(user_ids, VoteVerdict.NO_VOTE)
        stmt = select(QuestionVote).where(
            (QuestionVote.question_uid == question_uid)
            & (QuestionVote.user_firebase_uid.in_(user_ids)),  # pyright: ignore[reportAttributeAccessIssue]
        )
        results = await self.session.exec(stmt)
        verdicts.update(
            {
                result.user_firebase_uid: VoteVerdict(result.verdict)
                for result in results
            },
        )
        return verdicts
