"""Integration tests for login streak updates on authentication.

These tests exercise the /auth/token endpoint end-to-end using the
Firebase Auth emulator and Postgres, asserting changes in the user row.
"""

from __future__ import annotations

import asyncio
import os
from collections.abc import Callable

from fastapi.testclient import TestClient
from fermi_db.models.user import User
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession as SQLModelAsyncSession


async def _get_user_by_firebase_uid(uid: str) -> User | None:
    dsn = os.environ['DATABASE_URL']
    engine = create_async_engine(dsn, echo=False)
    sess_maker = async_sessionmaker(
        engine,
        class_=SQLModelAsyncSession,
        expire_on_commit=False,
    )
    async with sess_maker() as session:
        result = await session.exec(select(User).where(User.firebase_uid == uid))
        user = result.one_or_none()
    await engine.dispose()
    return user


def test_first_login_starts_streak_at_one(
    api_client: TestClient,
    create_emulator_user_and_get_token: Callable[[str, str, str], dict],
) -> None:
    """First authentication of a fresh user starts the login streak at 1."""
    token_info = create_emulator_user_and_get_token(
        'dev.user+streak@example.com',
        'password123',
        'Streaky',
    )
    firebase_token = token_info['idToken']
    firebase_uid = token_info['localId']

    # First auth/token call registers user with streak=1
    r1 = api_client.post(
        '/api/v1/auth/token',
        headers={'Authorization': f'Bearer {firebase_token}'},
    )
    assert r1.status_code == 200

    # Verify streak == 1
    user = asyncio.run(_get_user_by_firebase_uid(firebase_uid))
    assert user is not None
    assert user.login_streak == 1
