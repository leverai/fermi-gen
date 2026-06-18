"""Behavioral tests for UserRepository's cross-table and join queries.

``anonymize_user`` rewrites a user's firebase id across every referencing table
in one transaction and flips the user's PII/active flags -- the GDPR deletion
path. ``get_user_with_tier`` LEFT JOINs the subscription to resolve a tier.
Both span multiple tables, so they are tested against real Postgres.
"""

import uuid
from collections.abc import Sequence
from typing import Any

from fermi_db.models.game import AnswerEvent, QuestionVote, UserQuestionHistory
from fermi_db.models.precision_rush import PrecisionRushRun
from fermi_db.models.subscription import Subscription, SubscriptionTier
from fermi_db.models.survival import SurvivalRun
from fermi_db.models.user import User
from fermi_db.repositories.user_repository import UserRepository
from fermi_db.schemas import QuestionCategory, QuestionDifficulty
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession


def _user(firebase_uid: str, *, active: bool = True) -> User:
    return User(
        firebase_uid=firebase_uid,
        email=f'{firebase_uid}@example.com',
        display_name=firebase_uid,
        active=active,
    )


def _answer_event(user_firebase_id: str) -> AnswerEvent:
    return AnswerEvent(
        question_uid=uuid.uuid4(),
        question_difficulty=QuestionDifficulty.MEDIUM,
        question_category=QuestionCategory.OTHER,
        user_firebase_id=user_firebase_id,
        game_id='g1',
        answer={'number': 1.0, 'unit': None},
        correct_answer={'number': 1.0, 'unit': None},
        score_number=1.0,
        score_quantile=0.5,
    )


def _vote(user_firebase_uid: str) -> QuestionVote:
    return QuestionVote(question_uid=uuid.uuid4(), user_firebase_uid=user_firebase_uid)


def _survival(user_firebase_uid: str) -> SurvivalRun:
    return SurvivalRun(user_firebase_uid=user_firebase_uid, current_question_uid='q')


def _history(user_id: str) -> UserQuestionHistory:
    return UserQuestionHistory(user_id=user_id, question_uid=uuid.uuid4())


def _precision_rush(user_firebase_uid: str) -> PrecisionRushRun:
    return PrecisionRushRun(
        user_firebase_uid=user_firebase_uid,
        current_question_uid='q',
    )


async def _seed(session: AsyncSession, rows: Sequence[Any]) -> None:
    session.add_all(rows)
    await session.commit()


async def _rows_for(
    session: AsyncSession,
    model: type,
    column: Any,
    value: str,
) -> list:
    return list((await session.exec(select(model).where(column == value))).all())


# Tables anonymize_user rewrites that we can seed without an FK chain.
# (daily_question_answers is also rewritten, via the same UPDATE; it needs a
# fermi -> daily_questions -> answer chain to seed, so it is covered by reading.)
_REWRITTEN = (
    (AnswerEvent, AnswerEvent.user_firebase_id),
    (QuestionVote, QuestionVote.user_firebase_uid),
    (SurvivalRun, SurvivalRun.user_firebase_uid),
    (UserQuestionHistory, UserQuestionHistory.user_id),
)


# --------------------------------------------------------------------------- #
# anonymize_user
# --------------------------------------------------------------------------- #


async def test_anonymize_rewrites_references_and_clears_pii(
    session: AsyncSession,
) -> None:
    """All referencing rows move to the new anon id; the user PII is cleared."""
    repo = UserRepository(session)
    old = 'victim'
    user = _user(old)
    await _seed(
        session,
        [user, _answer_event(old), _vote(old), _survival(old), _history(old)],
    )

    await repo.anonymize_user(user.id)

    new_uid = user.firebase_uid
    assert new_uid.startswith('anon_')
    assert user.email is None
    assert user.active is False

    for model, column in _REWRITTEN:
        assert await _rows_for(session, model, column, old) == []  # rewritten away
        assert len(await _rows_for(session, model, column, new_uid)) == 1


async def test_anonymize_does_not_rewrite_precision_rush_runs(
    session: AsyncSession,
) -> None:
    """A precision_rush_runs row keeps the OLD firebase id after anonymization.

    NOTE: this pins *current* behavior. ``anonymize_user`` rewrites five tables
    but omits ``precision_rush_runs`` (also keyed by ``user_firebase_uid``),
    leaving a PII linkage behind -- almost certainly an oversight from when PR
    mode was added. Flagged for the fermi-api follow-up; the test documents it so
    a fix is a deliberate, visible change.
    """
    repo = UserRepository(session)
    old = 'victim'
    user = _user(old)
    await _seed(session, [user, _precision_rush(old)])

    await repo.anonymize_user(user.id)

    assert (
        len(
            await _rows_for(
                session,
                PrecisionRushRun,
                PrecisionRushRun.user_firebase_uid,
                old,
            ),
        )
        == 1
    )
    assert (
        await _rows_for(
            session,
            PrecisionRushRun,
            PrecisionRushRun.user_firebase_uid,
            user.firebase_uid,
        )
        == []
    )


async def test_anonymize_is_idempotent_and_safe_on_missing(
    session: AsyncSession,
) -> None:
    """Re-anonymizing is a no-op, and an unknown id raises nothing."""
    repo = UserRepository(session)
    user = _user('victim')
    await _seed(session, [user])

    await repo.anonymize_user(user.id)
    anon_uid = user.firebase_uid
    assert anon_uid.startswith('anon_')

    # Second call: user is already inactive -> no-op, id unchanged.
    await repo.anonymize_user(user.id)
    assert user.firebase_uid == anon_uid

    # Unknown id: returns without error.
    await repo.anonymize_user(999_999)


async def test_anonymize_leaves_other_users_untouched(
    session: AsyncSession,
) -> None:
    """Only the target user's rows are rewritten; bystanders are unaffected."""
    repo = UserRepository(session)
    victim, bystander = _user('victim'), _user('bystander')
    await _seed(
        session,
        [victim, bystander, _answer_event('victim'), _answer_event('bystander')],
    )

    await repo.anonymize_user(victim.id)

    assert bystander.firebase_uid == 'bystander'
    assert bystander.active is True
    assert (
        len(
            await _rows_for(
                session,
                AnswerEvent,
                AnswerEvent.user_firebase_id,
                'bystander',
            ),
        )
        == 1
    )


# --------------------------------------------------------------------------- #
# get_user_with_tier
# --------------------------------------------------------------------------- #


def _subscription(
    user_id: int,
    *,
    tier: SubscriptionTier,
    is_active: bool,
) -> Subscription:
    return Subscription(
        user_id=user_id,
        revenuecat_user_id=f'rc-{user_id}',
        tier=tier,
        is_active=is_active,
    )


async def test_get_user_with_tier_defaults_to_free_without_subscription(
    session: AsyncSession,
) -> None:
    """A user with no subscription row resolves to FREE."""
    repo = UserRepository(session)
    user = _user('u')
    await _seed(session, [user])

    result = await repo.get_user_with_tier(user.id)

    assert result is not None
    fetched, tier = result
    assert fetched.id == user.id
    assert tier == SubscriptionTier.FREE


async def test_get_user_with_tier_returns_pro_for_active_subscription(
    session: AsyncSession,
) -> None:
    """An active PRO subscription resolves to PRO."""
    repo = UserRepository(session)
    user = _user('u')
    await _seed(session, [user])
    await _seed(
        session,
        [_subscription(user.id, tier=SubscriptionTier.PRO, is_active=True)],
    )

    result = await repo.get_user_with_tier(user.id)

    assert result is not None
    _, tier = result
    assert tier == SubscriptionTier.PRO


async def test_get_user_with_tier_inactive_subscription_is_free(
    session: AsyncSession,
) -> None:
    """An inactive subscription does NOT grant PRO (is_active gate)."""
    repo = UserRepository(session)
    user = _user('u')
    await _seed(session, [user])
    await _seed(
        session,
        [_subscription(user.id, tier=SubscriptionTier.PRO, is_active=False)],
    )

    result = await repo.get_user_with_tier(user.id)

    assert result is not None
    _, tier = result
    assert tier == SubscriptionTier.FREE


async def test_get_user_with_tier_unknown_user_returns_none(
    session: AsyncSession,
) -> None:
    """No user row -> None."""
    repo = UserRepository(session)
    assert await repo.get_user_with_tier(999_999) is None
