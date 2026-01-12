"""FastAPI dependencies."""

import logging
from functools import lru_cache
from typing import Annotated

from fastapi import Depends, Header, HTTPException, status
from fermi_db.dal import DatabaseClient
from fermi_db.repositories.party_hosting_repository import PartyHostingRepository
from fermi_db.repositories.subscription_repository import SubscriptionRepository
from fermi_db.repositories.user_repository import UserRepository
from fermi_db.session import get_session
from google.cloud.firestore_v1.async_client import AsyncClient
from sqlmodel.ext.asyncio.session import AsyncSession

from app.core.config import settings
from app.services.auth import AuthService
from app.services.daily_question.service import DailyQuestionService
from app.services.game.service import GameService
from app.services.scoring import ScoringService
from app.services.subscription import SubscriptionService
from app.services.user import UserService

logger = logging.getLogger(__name__)


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


def get_subscription_repository(
    session: AsyncSession = Depends(get_session),  # noqa: B008
) -> SubscriptionRepository:
    """Get an instance of the SubscriptionRepository."""
    return SubscriptionRepository(session)


def get_party_hosting_repository(
    session: AsyncSession = Depends(get_session),  # noqa: B008
) -> PartyHostingRepository:
    """Get an instance of the PartyHostingRepository."""
    return PartyHostingRepository(session)


def get_subscription_service(
    subscription_repository: SubscriptionRepository = Depends(  # noqa: B008
        get_subscription_repository,
    ),
    user_repository: UserRepository = Depends(get_user_repository),  # noqa: B008
) -> SubscriptionService:
    """Get an instance of the SubscriptionService."""
    return SubscriptionService(
        subscription_repository=subscription_repository,
        user_repository=user_repository,
    )


async def verify_scheduler_secret(
    x_scheduler_secret: Annotated[str | None, Header()] = None,
) -> None:
    """Verify Cloud Scheduler shared secret header.

    This provides defense-in-depth for scheduler endpoints, in addition to
    OIDC authentication configured at Cloud Run/IAM level.

    Set SCHEDULER_SECRET environment variable and configure Cloud Scheduler
    to send it in the X-Scheduler-Secret header.
    """
    if not settings.scheduler_secret:
        # If secret is not configured, log warning but allow request
        # (assumes OIDC is handling auth at Cloud Run level)
        logger.warning(
            'SCHEDULER_SECRET not configured - relying solely on Cloud Run IAM/OIDC',
        )
        return

    if not x_scheduler_secret:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Missing X-Scheduler-Secret header',
        )

    if x_scheduler_secret != settings.scheduler_secret:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Invalid scheduler secret',
        )
