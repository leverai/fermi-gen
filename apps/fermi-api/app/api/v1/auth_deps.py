"""Authentication Dependencies for injection in endpoints."""

from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from fermi_db.models.user import User
from fermi_db.repositories.user_repository import UserRepository
from fermi_db.session import get_session
from jose import jwt
from jose.exceptions import ExpiredSignatureError, JWTClaimsError, JWTError
from pydantic import ValidationError
from sqlmodel.ext.asyncio.session import AsyncSession
from starlette.concurrency import run_in_threadpool

from app.core.config import settings
from app.schemas.auth import TokenPayload

oauth2_scheme = OAuth2PasswordBearer(tokenUrl=f'{settings.api_v1_str}/auth/token')


def get_user_repository(
    session: Annotated[AsyncSession, Depends(get_session)],
) -> UserRepository:
    """Get a user repository."""
    return UserRepository(session)


async def get_current_user(
    user_repo: Annotated[UserRepository, Depends(get_user_repository)],
    token: Annotated[str, Depends(oauth2_scheme)],
) -> User:
    """Get the current user from a token."""
    try:
        payload = await run_in_threadpool(
            jwt.decode,  # type: ignore[arg-type]
            token,
            key=settings.jwt_secret_key,
            algorithms=[settings.jwt_algorithm],
        )
        token_data = TokenPayload(**payload)
    except ExpiredSignatureError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Token has expired',
            headers={'WWW-Authenticate': 'Bearer'},
        ) from exc
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Could not validate signature',
            headers={'WWW-Authenticate': 'Bearer'},
        ) from exc
    except (JWTClaimsError, ValidationError) as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Invalid claims',
            headers={'WWW-Authenticate': 'Bearer'},
        ) from exc

    if not token_data.user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Missing claims in token',
            headers={'WWW-Authenticate': 'Bearer'},
        )

    user = await user_repo.get_by_id(token_data.user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='User not found',
            headers={'WWW-Authenticate': 'Bearer'},
        )
    return user
