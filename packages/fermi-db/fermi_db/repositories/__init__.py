"""Repositories for interacting with the database."""

from sqlmodel.ext.asyncio.session import AsyncSession


class BaseRepository:
    """Base class for all repositories."""

    def __init__(self, session: AsyncSession) -> None:
        """Initialize the repository with an async session."""
        self.session = session
