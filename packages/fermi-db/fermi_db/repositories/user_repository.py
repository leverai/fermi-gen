"""Repository for user-related database operations."""

import logging
import uuid
from typing import Any

from fermi_core import utcnow_naive
from sqlalchemy import update
from sqlmodel import select

from fermi_db.models.daily_question import DailyQuestionAnswer
from fermi_db.models.game import AnswerEvent, QuestionVote, UserQuestionHistory
from fermi_db.models.subscription import Subscription, SubscriptionTier
from fermi_db.models.survival import SurvivalRun
from fermi_db.models.user import User
from fermi_db.schemas import Locale

from . import BaseRepository

logger = logging.getLogger(__name__)


class UserRepository(BaseRepository):
    """Handles database operations related to users."""

    async def get_by_id(self, user_id: int) -> User | None:
        """Fetch a user by their ID."""
        return await self.session.get(User, user_id)

    async def get_user_with_tier(
        self,
        user_id: int,
    ) -> tuple[User, SubscriptionTier] | None:
        """Fetch a user and their subscription tier in a single query.

        Uses LEFT JOIN to fetch user and subscription together.

        Args:
            user_id: The user's database ID.

        Returns:
            Tuple of (User, SubscriptionTier) if user exists, None otherwise.
            Returns SubscriptionTier.FREE if no active subscription.

        """
        stmt = (
            select(User, Subscription)
            .outerjoin(Subscription, User.id == Subscription.user_id)
            .where(User.id == user_id)
        )
        result = await self.session.exec(stmt)
        row = result.one_or_none()
        if row is None:
            return None

        user, subscription = row
        # Determine tier: PRO only if subscription exists and is active
        tier = SubscriptionTier.FREE
        if subscription is not None and subscription.is_active:
            tier = subscription.tier
        return (user, tier)

    async def get_by_firebase_uid(self, firebase_uid: str) -> User | None:
        """Fetch a user by their Firebase UID."""
        result = await self.session.exec(
            select(User).where(User.firebase_uid == firebase_uid),
        )
        return result.one_or_none()

    async def get_by_firebase_uids(self, firebase_uids: list[str]) -> list[User]:
        """Fetch multiple users by their Firebase UIDs.

        Args:
            firebase_uids: List of Firebase UIDs to fetch.

        Returns:
            List of User objects matching the provided UIDs.

        """
        if not firebase_uids:
            return []
        result = await self.session.exec(
            select(User).where(User.firebase_uid.in_(firebase_uids)),  # type: ignore
        )
        return list(result.all())

    async def register_user(
        self,
        firebase_claims: dict[str, Any],
    ) -> User:
        """Create a new user from Firebase claims."""
        user = User(
            firebase_uid=firebase_claims['uid'],
            email=firebase_claims.get('email'),
            display_name=firebase_claims.get('name'),
            picture=firebase_claims.get('picture'),
            login_streak=1,
        )
        self.session.add(user)
        await self.session.commit()
        await self.session.refresh(user)
        return user

    async def login_user(
        self,
        user: User,
        firebase_claims: dict[str, Any],
    ) -> User:
        """Update a user's info at login: Firebase claims, login streak, updated_at."""
        # Email: update when provided
        user = await self._update_firebase_claims(user, firebase_claims)
        user = self._update_login_streak(user)
        user.updated_at = utcnow_naive()
        self.session.add(user)
        await self.session.commit()
        await self.session.refresh(user)
        return user

    async def _update_firebase_claims(
        self,
        user: User,
        firebase_claims: dict[str, Any],
    ) -> User:
        """Update a user's details from Firebase claims."""
        user.email = firebase_claims.get('email')
        # Picture: update when provided (leave existing otherwise)
        picture_claim = firebase_claims.get('picture')
        if picture_claim:
            user.picture = picture_claim
        return user

    async def update_locale(self, user_id: int, locale: Locale) -> User:
        """Update a user's locale."""
        user = await self.session.get(User, user_id)
        if user is None:
            raise ValueError(f'User with id {user_id} not found')
        user.locale = locale
        self.session.add(user)
        await self.session.commit()
        await self.session.refresh(user)
        return user

    async def update_user(
        self,
        user_id: int,
        display_name: str | None = None,
        picture: str | None = None,
    ) -> User:
        """Update a user's profile."""
        user = await self.session.get(User, user_id)
        if user is None:
            raise ValueError(f'User with id {user_id} not found')
        if not display_name and not picture:
            logger.warning('No display_name or picture provided for user %s', user_id)
            return user

        if display_name is not None:
            user.display_name = display_name
        if picture is not None:
            user.picture = picture

        user.updated_at = utcnow_naive()
        self.session.add(user)
        await self.session.commit()
        await self.session.refresh(user)
        return user

    def _update_login_streak(self, user: User) -> User:
        """Update the user's login streak based on last login at.

        Rules:
        - If the user has never logged in before (no last_login_at), start at 1.
        - If last login was today, do not change the streak.
        - If last login was yesterday, increment the streak by 1.
        - Otherwise, reset the streak to 1.
        """
        now = utcnow_naive()
        if user.last_login_at.date() == now.date():
            # Already counted today; nothing to do
            return user
        # Calculate day difference
        delta_days = (now - user.last_login_at).days
        if delta_days == 1:
            user.login_streak = user.login_streak + 1
        else:
            user.login_streak = 1

        user.last_login_at = now
        return user

    async def anonymize_user(self, user_id: int) -> None:
        """Anonymize a user's PII for GDPR-compliant deletion.

        Instead of deleting rows (which breaks analytics), this:
        1. Updates all related tables (answer_events, questions_votes, etc.)
           to use the new anonymized firebase_uid
        2. Replaces firebase_uid with 'anon_<uuid>'
        3. Clears email
        4. Sets active=False
        5. Updates updated_at timestamp

        All updates happen in a single transaction to ensure atomicity.

        This operation is idempotent - if the user doesn't exist or is already
        anonymized, it returns without error.
        """
        user = await self.get_by_id(user_id)
        if user is None or not user.active:
            # Idempotent: user doesn't exist or already anonymized
            return

        old_firebase_uid = user.firebase_uid
        new_firebase_uid = f'anon_{uuid.uuid4()}'

        # Update all tables that reference the old firebase_uid
        await self.session.execute(
            update(DailyQuestionAnswer)
            .where(DailyQuestionAnswer.user_firebase_uid == old_firebase_uid)
            .values(user_firebase_uid=new_firebase_uid),
        )
        await self.session.execute(
            update(QuestionVote)
            .where(QuestionVote.user_firebase_uid == old_firebase_uid)
            .values(user_firebase_uid=new_firebase_uid),
        )
        await self.session.execute(
            update(AnswerEvent)
            .where(AnswerEvent.user_firebase_id == old_firebase_uid)
            .values(user_firebase_id=new_firebase_uid),
        )
        await self.session.execute(
            update(SurvivalRun)
            .where(SurvivalRun.user_firebase_uid == old_firebase_uid)
            .values(user_firebase_uid=new_firebase_uid),
        )
        await self.session.execute(
            update(UserQuestionHistory)
            .where(UserQuestionHistory.user_id == old_firebase_uid)
            .values(user_id=new_firebase_uid),
        )

        # Anonymize user PII
        user.firebase_uid = new_firebase_uid
        user.email = None
        user.active = False
        user.updated_at = utcnow_naive()

        self.session.add(user)
        await self.session.commit()

    async def increment_xp(self, firebase_uid: str, amount: int) -> None:
        """Atomically increment a user's XP.

        Args:
            firebase_uid: The user's Firebase UID.
            amount: Amount of XP to add (must be non-negative).

        """
        if amount < 0:
            raise ValueError('XP increment must be non-negative')
        if amount == 0:
            return

        user = await self.get_by_firebase_uid(firebase_uid)
        assert user is not None
        user.xp = user.xp + amount
        self.session.add(user)
        # Note: caller should commit

    async def get_xp(self, firebase_uid: str) -> int:
        """Get a user's current XP.

        Args:
            firebase_uid: The user's Firebase UID.

        Returns:
            The user's XP value, or 0 if user not found.

        """
        user = await self.get_by_firebase_uid(firebase_uid)
        if user is None:
            return 0
        return user.xp

    async def increment_points(self, firebase_uid: str, amount: int) -> None:
        """Atomically increment a user's points.

        Args:
            firebase_uid: The user's Firebase UID.
            amount: Amount of points to add (must be non-negative).

        """
        if amount < 0:
            raise ValueError('Points increment must be non-negative')
        if amount == 0:
            return

        user = await self.get_by_firebase_uid(firebase_uid)
        assert user is not None
        user.points = user.points + amount
        self.session.add(user)

    async def spend_points(self, firebase_uid: str, amount: int) -> int:
        """Atomically deduct points from a user's balance.

        Args:
            firebase_uid: The user's Firebase UID.
            amount: Amount of points to deduct (must be positive).

        Returns:
            The remaining points balance after deduction.

        Raises:
            ValueError: If amount is not positive or balance is insufficient.

        """
        if amount <= 0:
            raise ValueError('Spend amount must be positive')

        user = await self.get_by_firebase_uid(firebase_uid)
        if user is None:
            raise ValueError(f'User with firebase_uid {firebase_uid} not found')
        if user.points < amount:
            raise ValueError(f'Insufficient points: have {user.points}, need {amount}')

        user.points = user.points - amount
        self.session.add(user)
        # Note: caller should commit
        return user.points

    async def get_points(self, firebase_uid: str) -> int:
        """Get a user's current points balance.

        Args:
            firebase_uid: The user's Firebase UID.

        Returns:
            The user's points value, or 0 if user not found.

        """
        user = await self.get_by_firebase_uid(firebase_uid)
        if user is None:
            return 0
        return user.points
