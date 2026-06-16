"""Repository for question vote operations."""

from collections.abc import Iterable, Sequence
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

    async def get_upvotes_bulk(
        self,
        question_uids: Sequence[UUID],
    ) -> dict[UUID, int]:
        """Return upvote counts for many questions in a single query.

        Bulk equivalent of :meth:`get_upvotes`. Returns a dict mapping each
        ``question_uid`` to its upvote count. A uid with no upvotes is absent from
        the result (the ``GROUP BY`` yields no row); callers must default a
        missing uid to ``0``, identical to the per-uid method.
        """
        if not question_uids:
            return {}
        stmt = (
            select(QuestionVote.question_uid, func.count())
            .where(
                (QuestionVote.question_uid.in_(list(question_uids)))  # pyright: ignore[reportAttributeAccessIssue]
                & (QuestionVote.verdict == int(VoteVerdict.UPVOTE)),
            )
            .group_by(QuestionVote.question_uid)  # pyright: ignore[reportArgumentType]
        )
        results = await self.session.exec(stmt)
        return {uid: int(count) for uid, count in results}

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

        # TODO: Only get verdict back
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

    async def get_players_vote_verdicts_bulk(
        self,
        question_uids: Sequence[UUID],
        user_ids: Sequence[str],
    ) -> dict[UUID, dict[str, VoteVerdict]]:
        """Return per-question verdicts for a set of users in a single query.

        Bulk equivalent of :meth:`get_players_vote_verdicts`. Returns a dict
        mapping every requested ``question_uid`` to a ``{firebase_uid: VoteVerdict}``
        dict that is pre-seeded with ``VoteVerdict.NO_VOTE`` for every id in
        ``user_ids`` and then updated with any actual votes found -- identical to
        the per-uid method, but for all questions at once. Every requested uid is
        present in the result (even ones with no votes), each seeded with NO_VOTE
        for all users.

        This totality is part of the contract: callers index the result directly
        (``result[uid]``), unlike the upvotes/quantiles bulk methods which omit
        empty uids and are read with a ``.get(uid, default)``. Do NOT "optimize"
        this to seed lazily (only uids that have votes) -- that would KeyError the
        callers on a question with no votes.
        """
        # Pre-seed every requested question with NO_VOTE for every user, so the
        # "user hasn't voted" default matches the per-uid method exactly and every
        # requested uid is always present in the result.
        verdicts: dict[UUID, dict[str, VoteVerdict]] = {
            uid: dict.fromkeys(user_ids, VoteVerdict.NO_VOTE) for uid in question_uids
        }
        if not question_uids or not user_ids:
            return verdicts

        stmt = select(QuestionVote).where(
            (QuestionVote.question_uid.in_(list(question_uids)))  # pyright: ignore[reportAttributeAccessIssue]
            & (QuestionVote.user_firebase_uid.in_(list(user_ids))),  # pyright: ignore[reportAttributeAccessIssue]
        )
        results = await self.session.exec(stmt)
        for result in results:
            # A vote could in principle exist for a uid not requested; guard with
            # the pre-seeded dict so we only fill in requested questions.
            question_verdicts = verdicts.get(result.question_uid)
            if question_verdicts is not None:
                question_verdicts[result.user_firebase_uid] = VoteVerdict(
                    result.verdict,
                )
        return verdicts

    async def get_player_vote_verdict(
        self,
        question_uid: UUID,
        user_firebase_uid: str,
    ) -> VoteVerdict:
        """Return a player's vote verdict for a question."""
        stmt = select(QuestionVote.verdict).where(
            (QuestionVote.question_uid == question_uid)
            & (QuestionVote.user_firebase_uid == user_firebase_uid),
        )
        result = await self.session.exec(stmt)
        verdict = result.one_or_none()
        return VoteVerdict(verdict) if verdict is not None else VoteVerdict.NO_VOTE
