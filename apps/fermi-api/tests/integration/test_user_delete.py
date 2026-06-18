"""Integration test for POST /user/delete."""

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
    """Get user by Firebase UID."""
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


async def _get_user_by_id(user_id: int) -> User | None:
    """Get user by database ID."""
    dsn = os.environ['DATABASE_URL']
    engine = create_async_engine(dsn, echo=False)
    sess_maker = async_sessionmaker(
        engine,
        class_=SQLModelAsyncSession,
        expire_on_commit=False,
    )
    async with sess_maker() as session:
        user = await session.get(User, user_id)
    await engine.dispose()
    return user


def test_delete_user_returns_200(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """Deleting a user should return literal 200."""
    headers = get_api_auth_headers(
        'dev.user+delete@example.com',
        'password123',
        'DeleteUser',
    )
    r = api_client.post(
        '/api/v1/user/delete',
        headers=headers,
    )
    assert r.status_code == 200
    assert r.json() == 200


def test_delete_user_anonymizes_user_data(
    api_client: TestClient,
    create_emulator_user_and_get_token: Callable[[str, str, str], dict],
) -> None:
    """Deleting a user soft-anonymizes the record (kept for analytics), not delete."""
    # 1. Create user and get token
    email = 'delete.all.data@example.com'
    creds = create_emulator_user_and_get_token(email, 'password123', 'DeleteAllData')
    firebase_token = creds['idToken']
    firebase_uid = creds['localId']

    # 2. Exchange Firebase token for access token (creates user in DB)
    token_resp = api_client.post(
        '/api/v1/auth/token',
        headers={'Authorization': f'Bearer {firebase_token}'},
    )
    assert token_resp.status_code == 200
    access_token = token_resp.json()['access_token']

    # 3. Verify user exists in database
    user = asyncio.run(_get_user_by_firebase_uid(firebase_uid))
    assert user is not None, 'User should exist before deletion'
    user_id = user.id

    # 4. Delete user (triggers anonymization)
    delete_resp = api_client.post(
        '/api/v1/user/delete',
        headers={'Authorization': f'Bearer {access_token}'},
    )
    assert delete_resp.status_code == 200

    # 5. Verify original firebase_uid no longer exists (was anonymized)
    user_by_uid = asyncio.run(_get_user_by_firebase_uid(firebase_uid))
    assert user_by_uid is None, 'Original firebase_uid should not be found'

    # 6. The record must still exist (soft anonymize), with an anon_ uid. A hard
    #    delete would also satisfy step 5, so this is what distinguishes the
    #    GDPR-preserving anonymize path from an outright delete.
    user_by_id = asyncio.run(_get_user_by_id(user_id))
    assert user_by_id is not None, 'User record should persist for analytics'
    assert user_by_id.firebase_uid.startswith('anon_'), (
        'firebase_uid should be anonymized, not deleted'
    )


def test_delete_user_requires_authentication(
    api_client: TestClient,
) -> None:
    """Deleting a user without authentication should return 401."""
    r = api_client.post(
        '/api/v1/user/delete',
    )
    assert r.status_code == 401
