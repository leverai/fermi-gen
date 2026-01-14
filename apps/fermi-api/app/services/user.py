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
        """Delete a user and all associated data, including Firebase account."""
        # Get user to retrieve firebase_uid before deletion
        user = await self._user_repository.get_by_id(user_id)
        if user is None:
            # Idempotent: user doesn't exist, nothing to delete
            return

        firebase_uid = user.firebase_uid
        assert firebase_uid is not None

        # Delete Firebase account
        # This works with both production Firebase and the emulator
        # (if Firebase Admin is configured to use the emulator)
        try:
            # Use thread pool for blocking I/O call
            await run_in_threadpool(auth.delete_user, firebase_uid)
        except Exception:
            # Log error but continue with database deletion
            # Firebase deletion failure shouldn't block database cleanup
            # (e.g., if account was already deleted or emulator is not available)

            logger.exception(
                'Failed to delete Firebase account for %s',
                f'{firebase_uid[:5]}...{firebase_uid[-5:]}',
            )

        # Delete user from database (and all associated data)
        await self._user_repository.delete_user(user_id)

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
