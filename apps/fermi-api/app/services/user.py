"""User service."""

import logging
from typing import TYPE_CHECKING

import firebase_admin
from fermi_db.schemas import Locale
from firebase_admin import auth
from starlette.concurrency import run_in_threadpool

if TYPE_CHECKING:
    from fermi_db.repositories.user_repository import UserRepository


logger = logging.getLogger(__name__)


class UserService:
    """Service for user-related operations."""

    def __init__(self, user_repository: 'UserRepository'):
        """Initialize the user service."""
        self._user_repository = user_repository
        if not firebase_admin._apps:
            firebase_admin.initialize_app()

    async def set_locale(self, user_id: int, locale: Locale) -> None:
        """Set a user's locale."""
        await self._user_repository.update_locale(user_id, locale)

    async def update_user_profile(
        self,
        user_id: int,
        display_name: str | None = None,
        picture: str | None = None,
    ) -> None:
        """Update a user's profile."""
        await self._user_repository.update_user(
            user_id,
            display_name=display_name,
            picture=picture,
        )

    async def delete_user(self, user_id: int) -> None:
        """Delete a user's account and anonymize their data.

        This method:
        1. Deletes the Firebase account (so the user can't log in)
        2. Anonymizes PII in the database (firebase_uid, email) to preserve analytics
        """
        # Get user to retrieve firebase_uid before anonymization
        user = await self._user_repository.get_by_id(user_id)
        if user is None or not user.active:
            # Idempotent: user doesn't exist or already deleted
            return

        firebase_uid = user.firebase_uid

        # Delete Firebase account
        # This works with both production Firebase and the emulator
        # (if Firebase Admin is configured to use the emulator)
        try:
            # Use thread pool for blocking I/O call
            await run_in_threadpool(auth.delete_user, firebase_uid)
        except Exception:
            # Log error but continue with database anonymization
            # Firebase deletion failure shouldn't block database cleanup
            # (e.g., if account was already deleted or emulator is not available)

            logger.exception(
                'Failed to delete Firebase account for %s',
                f'{firebase_uid[:5]}...{firebase_uid[-5:]}',
            )

        # Anonymize user in database (preserves analytics data without PII)
        await self._user_repository.anonymize_user(user_id)

    async def get_users_by_firebase_uids(
        self,
        firebase_uids: list[str],
    ) -> dict[str, dict[str, str | None]]:
        """Get display name and avatar for multiple users.

        Args:
            firebase_uids: List of Firebase UIDs.

        Returns:
            Dict mapping firebase_uid to {display_name, avatar_url}.

        """
        users = await self._user_repository.get_by_firebase_uids(firebase_uids)
        return {
            user.firebase_uid: {
                'display_name': user.display_name,
                'avatar_url': user.picture,
            }
            for user in users
        }

    async def increment_xp_by_score(
        self,
        firebase_uid: str,
        score: float,
    ) -> int:
        """Increment a user's XP based on their score.

        Formula: xp_increment = score // 100

        Args:
            firebase_uid: The user's Firebase UID.
            score: The score earned by the player.

        Returns:
            The XP increment amount.

        """
        xp_increment = int(score // 100)
        if xp_increment > 0:
            user = await self._user_repository.get_by_firebase_uid(firebase_uid)
            if user is None:
                raise ValueError(f'User with firebase_uid {firebase_uid} not found')
            await self._user_repository.increment_xp(firebase_uid, xp_increment)
            await self._user_repository.session.commit()
        return xp_increment

    async def get_xp_level(self, firebase_uid: str) -> dict[str, int]:
        """Get a user's XP and computed level.

        Formula: level = (xp // 100) + 1

        Args:
            firebase_uid: The user's Firebase UID.

        Returns:
            Dict with 'xp' and 'level' keys.

        """
        xp = await self._user_repository.get_xp(firebase_uid)
        level = (xp // 100) + 1
        return {'xp': xp, 'level': level}

    async def increment_points_by_score(
        self,
        firebase_uid: str,
        score: float,
    ) -> int:
        """Increment a user's points based on their score.

        Formula: points_increment = score // 100

        Args:
            firebase_uid: The user's Firebase UID.
            score: The score earned by the player.

        Returns:
            The points increment amount.

        """
        points_increment = int(score // 100)
        if points_increment > 0:
            user = await self._user_repository.get_by_firebase_uid(firebase_uid)
            if user is None:
                raise ValueError(f'User with firebase_uid {firebase_uid} not found')
            await self._user_repository.increment_points(
                firebase_uid,
                points_increment,
            )
            await self._user_repository.session.commit()
        return points_increment

    async def get_points(self, firebase_uid: str) -> int:
        """Get a user's current points balance.

        Args:
            firebase_uid: The user's Firebase UID.

        Returns:
            The user's points balance.

        """
        return await self._user_repository.get_points(firebase_uid)

    async def earn_ad_points(self, firebase_uid: str) -> int:
        """Grant 500 points for watching a rewarded ad.

        Args:
            firebase_uid: The user's Firebase UID.

        Returns:
            The user's new points balance after the reward.

        """
        ad_reward = 500
        user = await self._user_repository.get_by_firebase_uid(firebase_uid)
        if user is None:
            raise ValueError(f'User with firebase_uid {firebase_uid} not found')
        await self._user_repository.increment_points(firebase_uid, ad_reward)
        await self._user_repository.session.commit()
        return await self._user_repository.get_points(firebase_uid)

    async def spend_points(self, firebase_uid: str, amount: int) -> int:
        """Deduct points from a user's balance.

        Args:
            firebase_uid: The user's Firebase UID.
            amount: Amount of points to spend (must be positive).

        Returns:
            The remaining points balance after deduction.

        Raises:
            ValueError: If amount is invalid or balance is insufficient.

        """
        remaining = await self._user_repository.spend_points(firebase_uid, amount)
        await self._user_repository.session.commit()
        return remaining
