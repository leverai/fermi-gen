"""FastAPI dependencies."""

from functools import lru_cache

from fastapi import Depends
from fermi_db.dal import DatabaseClient
from fermi_db.repositories.user_repository import UserRepository
from fermi_db.session import get_session
from google.cloud.firestore_v1.async_client import AsyncClient
from sqlmodel.ext.asyncio.session import AsyncSession

from app.services.auth import AuthService
from app.services.daily_question.service import DailyQuestionService
from app.services.game.service import GameService
from app.services.scoring import ScoringService
from app.services.user import UserService


@lru_cache
def get_auth_service() -> AuthService:
    """Get an instance of the AuthService."""
    return AuthService()


def get_db_client(session: AsyncSession = Depends(get_session)) -> DatabaseClient:  # noqa: B008
    """Get an instance of the DatabaseClient."""
    return DatabaseClient(session)


def get_user_repository(session: AsyncSession = Depends(get_session)) -> UserRepository:  # noqa: B008
    """Get an instance of the UserRepository."""
    return UserRepository(session)


def get_game_service(db_client: DatabaseClient = Depends(get_db_client)) -> GameService:  # noqa: B008
    """Get an instance of the GameService."""
    return GameService(db_client=db_client)


def get_daily_question_service(
    db_client: DatabaseClient = Depends(get_db_client),  # noqa: B008
) -> DailyQuestionService:
    """Get an instance of the DailyQuestionService."""
    return DailyQuestionService(db_client=db_client)


@lru_cache
def get_scoring_service() -> ScoringService:
    """Get an instance of the ScoringService."""
    return ScoringService()


@lru_cache
def get_firestore_client() -> AsyncClient:
    """Return a singleton instance of the Firestore AsyncClient.

    Using lru_cache ensures the client is initialized only once.
    """
    return AsyncClient()


def get_user_service(
    user_repository: UserRepository = Depends(get_user_repository),  # noqa: B008
) -> UserService:
    """Get an instance of the UserService."""
    return UserService(user_repository=user_repository)
