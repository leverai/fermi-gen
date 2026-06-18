"""Behavioral tests for QuestionVotesRepository.

``set_verdict`` is not a plain toggle: it ADDS verdict values (so UPVOTE then
DOWNVOTE nets to NO_VOTE), re-applying the same verdict is idempotent (it does
NOT toggle off), and it guards on the question existing in ``fermi``. The two
bulk readers have deliberately *opposite* emptiness contracts -- upvote counts
omit empty uids, while player verdicts are total and seed NO_VOTE. All of this
is real query/transaction behavior, so it is exercised against Postgres here.
"""

import datetime
import uuid
from collections.abc import Sequence
from typing import Any

import pytest
from fermi_db.exceptions import QuestionNotFoundError
from fermi_db.models import Fermi, QuestionVote, VoteVerdict
from fermi_db.repositories.question_votes_repository import QuestionVotesRepository
from fermi_db.schemas import QuestionDifficulty, QuestionStatus
from sqlmodel.ext.asyncio.session import AsyncSession


def _fermi(uid: uuid.UUID) -> Fermi:
    """Minimal valid Fermi row; only ``uid`` matters for the vote FK guard."""
    now = datetime.datetime(2026, 1, 1)  # noqa: DTZ001
    return Fermi(
        uid=uid,
        question_id=int(uuid.uuid4().int % 2_000_000_000),
        text='q',
        question_source={},
        answer_id=int(uuid.uuid4().int % 2_000_000_000),
        number=1.0,
        unit=None,
        snippet='snippet',
        used_ai_overview=False,
        difficulty=QuestionDifficulty.MEDIUM,
        category=None,
        embedding=None,
        random_sort_key=0,
        created_at=now,
        updated_at=now,
        status=QuestionStatus.APPROVED,
        is_daily_question=False,
        gpt_5_1_number=1.0,
        gpt_5_1_unit=None,
        gpt_5_mini_number=1.0,
        gpt_5_mini_unit=None,
        gpt_5_nano_number=1.0,
        gpt_5_nano_unit=None,
        gemini_flash_1_number=1.0,
        gemini_flash_1_unit=None,
        gemini_flash_2_number=1.0,
        gemini_flash_2_unit=None,
        gemini_flash_3_number=1.0,
        gemini_flash_3_unit=None,
        gemini_flash_4_number=1.0,
        gemini_flash_4_unit=None,
        gemini_flash_5_number=1.0,
        gemini_flash_5_unit=None,
    )


def _vote(question_uid: uuid.UUID, user: str, verdict: VoteVerdict) -> QuestionVote:
    return QuestionVote(
        question_uid=question_uid,
        user_firebase_uid=user,
        verdict=int(verdict),
    )


async def _seed(session: AsyncSession, rows: Sequence[Any]) -> None:
    session.add_all(rows)
    await session.commit()


async def _seed_question(session: AsyncSession, uid: uuid.UUID) -> None:
    await _seed(session, [_fermi(uid)])


# --------------------------------------------------------------------------- #
# set_verdict  (create / additive toggle / FK guard)
# --------------------------------------------------------------------------- #


async def test_set_verdict_creates_upvote(session: AsyncSession) -> None:
    """A first upvote creates the row and is counted."""
    repo = QuestionVotesRepository(session)
    q = uuid.uuid4()
    await _seed_question(session, q)

    result = await repo.set_verdict(
        question_uid=q,
        user_firebase_uid='u',
        verdict=VoteVerdict.UPVOTE,
    )

    assert result == VoteVerdict.UPVOTE
    assert await repo.get_upvotes(q) == 1


async def test_set_verdict_same_verdict_is_idempotent(session: AsyncSession) -> None:
    """Re-applying the same verdict keeps it (does NOT toggle the vote off)."""
    repo = QuestionVotesRepository(session)
    q = uuid.uuid4()
    await _seed_question(session, q)

    await repo.set_verdict(
        question_uid=q,
        user_firebase_uid='u',
        verdict=VoteVerdict.UPVOTE,
    )
    result = await repo.set_verdict(
        question_uid=q,
        user_firebase_uid='u',
        verdict=VoteVerdict.UPVOTE,
    )

    assert result == VoteVerdict.UPVOTE
    assert await repo.get_upvotes(q) == 1  # still exactly one upvote


async def test_set_verdict_opposite_nets_to_no_vote(session: AsyncSession) -> None:
    """Upvote then downvote sums to NO_VOTE (1 + -1 = 0), clearing both counts."""
    repo = QuestionVotesRepository(session)
    q = uuid.uuid4()
    await _seed_question(session, q)

    await repo.set_verdict(
        question_uid=q,
        user_firebase_uid='u',
        verdict=VoteVerdict.UPVOTE,
    )
    result = await repo.set_verdict(
        question_uid=q,
        user_firebase_uid='u',
        verdict=VoteVerdict.DOWNVOTE,
    )

    assert result == VoteVerdict.NO_VOTE
    assert await repo.get_upvotes(q) == 0
    assert await repo.get_downvotes(q) == 0


async def test_set_verdict_can_revote_after_netting_to_neutral(
    session: AsyncSession,
) -> None:
    """After netting to NO_VOTE, a fresh upvote re-activates (0 + 1 = 1)."""
    repo = QuestionVotesRepository(session)
    q = uuid.uuid4()
    await _seed_question(session, q)

    await repo.set_verdict(
        question_uid=q,
        user_firebase_uid='u',
        verdict=VoteVerdict.UPVOTE,
    )
    await repo.set_verdict(
        question_uid=q,
        user_firebase_uid='u',
        verdict=VoteVerdict.DOWNVOTE,
    )
    result = await repo.set_verdict(
        question_uid=q,
        user_firebase_uid='u',
        verdict=VoteVerdict.UPVOTE,
    )

    assert result == VoteVerdict.UPVOTE
    assert await repo.get_upvotes(q) == 1


async def test_set_verdict_on_unknown_question_raises(session: AsyncSession) -> None:
    """Voting on a question with no fermi row raises QuestionNotFoundError."""
    repo = QuestionVotesRepository(session)

    with pytest.raises(QuestionNotFoundError):
        await repo.set_verdict(
            question_uid=uuid.uuid4(),  # never seeded
            user_firebase_uid='u',
            verdict=VoteVerdict.UPVOTE,
        )


# --------------------------------------------------------------------------- #
# get_upvotes_bulk  (counts only upvotes; omits empty uids)
# --------------------------------------------------------------------------- #


async def test_get_upvotes_bulk_counts_upvotes_and_omits_empty(
    session: AsyncSession,
) -> None:
    """Only UPVOTEs are counted; a uid with no upvotes is absent from the dict."""
    repo = QuestionVotesRepository(session)
    q_up, q_down, q_none = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()
    await _seed(
        session,
        [
            _vote(q_up, 'a', VoteVerdict.UPVOTE),
            _vote(q_up, 'b', VoteVerdict.UPVOTE),
            _vote(q_up, 'c', VoteVerdict.DOWNVOTE),  # not counted
            _vote(q_down, 'a', VoteVerdict.DOWNVOTE),  # no upvotes
        ],
    )

    counts = await repo.get_upvotes_bulk([q_up, q_down, q_none])

    assert counts == {q_up: 2}  # q_down and q_none omitted (caller defaults to 0)


async def test_get_upvotes_bulk_empty_input(session: AsyncSession) -> None:
    """No uids requested -> empty dict."""
    repo = QuestionVotesRepository(session)
    assert await repo.get_upvotes_bulk([]) == {}


# --------------------------------------------------------------------------- #
# get_players_vote_verdicts_bulk  (total; seeds NO_VOTE; filters to requested)
# --------------------------------------------------------------------------- #


async def test_player_verdicts_bulk_is_total_and_filters_users(
    session: AsyncSession,
) -> None:
    """Every requested question is present (seeded NO_VOTE), votes are filled in.

    A question with no votes still appears (all NO_VOTE), and votes by users not
    in the requested set are ignored.
    """
    repo = QuestionVotesRepository(session)
    voted, silent = uuid.uuid4(), uuid.uuid4()
    await _seed(
        session,
        [
            _vote(voted, 'a', VoteVerdict.UPVOTE),
            _vote(voted, 'b', VoteVerdict.DOWNVOTE),
            _vote(voted, 'stranger', VoteVerdict.UPVOTE),  # not in requested users
        ],
    )

    result = await repo.get_players_vote_verdicts_bulk([voted, silent], ['a', 'b', 'c'])

    assert set(result) == {voted, silent}  # totality: both questions present
    assert result[voted] == {
        'a': VoteVerdict.UPVOTE,
        'b': VoteVerdict.DOWNVOTE,
        'c': VoteVerdict.NO_VOTE,  # requested but did not vote
    }
    assert result[silent] == {
        'a': VoteVerdict.NO_VOTE,
        'b': VoteVerdict.NO_VOTE,
        'c': VoteVerdict.NO_VOTE,
    }
