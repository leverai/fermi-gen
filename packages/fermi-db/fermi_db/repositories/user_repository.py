"""Repository for user-related database operations."""

from typing import Any

from fermi_core import utcnow_naive
from sqlmodel import select

from fermi_db.models.user import User
from fermi_db.schemas import Locale

from . import BaseRepository


class UserRepository(BaseRepository):
    """Handles database operations related to users."""

    async def get_by_id(self, user_id: int) -> User | None:
        """Fetch a user by their ID."""
        return await self.session.get(User, user_id)

    async def get_by_firebase_uid(self, firebase_uid: str) -> User | None:
        """Fetch a user by their Firebase UID."""
        result = await self.session.exec(
            select(User).where(User.firebase_uid == firebase_uid),
        )
        return result.one_or_none()

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
        user = await self._update_login_streak(user)
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

    async def _update_login_streak(self, user: User) -> User:
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
