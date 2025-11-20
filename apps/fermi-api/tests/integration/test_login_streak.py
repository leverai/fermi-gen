"""Integration tests for login streak updates on authentication.

These tests exercise the /auth/token endpoint end-to-end using the
Firebase Auth emulator and Postgres, asserting changes in the user row.
"""

from __future__ import annotations

import asyncio
import datetime
import os
from collections.abc import Callable
from datetime import timedelta

from fastapi.testclient import TestClient
from fermi_core import utcnow_naive
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


async def _update_user_last_login(
    uid: str,
    last_login_at: datetime.datetime,
    login_streak: int,
) -> None:
    dsn = os.environ['DATABASE_URL']
    engine = create_async_engine(dsn, echo=False)
    sess_maker = async_sessionmaker(
        engine,
        class_=SQLModelAsyncSession,
        expire_on_commit=False,
    )
    async with sess_maker() as session:
        result = await session.exec(select(User).where(User.firebase_uid == uid))
        user = result.one()
        user.last_login_at = last_login_at
        user.login_streak = login_streak
        session.add(user)
        await session.commit()
        await session.refresh(user)
    await engine.dispose()


def test_login_streak_same_day_and_next_day(
    api_client: TestClient,
    create_emulator_user_and_get_token: Callable[[str, str, str], dict],
) -> None:
    """Test login streak updates on authentication."""
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

    # Second same-day login: streak unchanged
    r2 = api_client.post(
        '/api/v1/auth/token',
        headers={'Authorization': f'Bearer {firebase_token}'},
    )
    assert r2.status_code == 200
    user2 = asyncio.run(_get_user_by_firebase_uid(firebase_uid))
    assert user2 is not None
    assert user2.login_streak == 1

    # Simulate next-day by setting last_login_at to yesterday and streak=3, then login
    yesterday = utcnow_naive() - timedelta(days=1, minutes=5)
    asyncio.run(_update_user_last_login(firebase_uid, yesterday, 3))

    r3 = api_client.post(
        '/api/v1/auth/token',
        headers={'Authorization': f'Bearer {firebase_token}'},
    )
    assert r3.status_code == 200
    user3 = asyncio.run(_get_user_by_firebase_uid(firebase_uid))
    assert user3 is not None
    assert user3.login_streak == 4
