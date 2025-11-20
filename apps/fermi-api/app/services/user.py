"""User service."""

from typing import TYPE_CHECKING

from fermi_db.schemas import Locale

if TYPE_CHECKING:
    from fermi_db.repositories.user_repository import UserRepository


class UserService:
    """Service for user-related operations."""

    def __init__(self, user_repository: 'UserRepository'):
        """Initialize the user service."""
        self._user_repository = user_repository

    async def set_locale(self, user_id: int, locale: Locale) -> None:
        """Set a user's locale."""
        await self._user_repository.update_locale(user_id, locale)
