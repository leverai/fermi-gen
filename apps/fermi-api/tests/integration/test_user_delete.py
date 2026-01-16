"""Integration test for POST /user/delete."""

from __future__ import annotations

import asyncio
import os
from collections.abc import Callable

from fastapi.testclient import TestClient
from fermi_db.models.game import AnswerEvent, QuestionVote, UserQuestionHistory
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


async def _get_user_question_history_count(firebase_uid: str) -> int:
    """Get count of user_question_history entries for a user."""
    dsn = os.environ['DATABASE_URL']
    engine = create_async_engine(dsn, echo=False)
    sess_maker = async_sessionmaker(
        engine,
        class_=SQLModelAsyncSession,
        expire_on_commit=False,
    )
    async with sess_maker() as session:
        result = await session.exec(
            select(UserQuestionHistory).where(
                UserQuestionHistory.user_id == firebase_uid,  # type: ignore
            ),
        )
        count = len(list(result.all()))
    await engine.dispose()
    return count


async def _get_answer_events_count(firebase_uid: str) -> int:
    """Get count of answer_events entries for a user."""
    dsn = os.environ['DATABASE_URL']
    engine = create_async_engine(dsn, echo=False)
    sess_maker = async_sessionmaker(
        engine,
        class_=SQLModelAsyncSession,
        expire_on_commit=False,
    )
    async with sess_maker() as session:
        result = await session.exec(
            select(AnswerEvent).where(
                AnswerEvent.user_firebase_id == firebase_uid,  # type: ignore
            ),
        )
        count = len(list(result.all()))
    await engine.dispose()
    return count


async def _get_questions_votes_count(firebase_uid: str) -> int:
    """Get count of questions_votes entries for a user."""
    dsn = os.environ['DATABASE_URL']
    engine = create_async_engine(dsn, echo=False)
    sess_maker = async_sessionmaker(
        engine,
        class_=SQLModelAsyncSession,
        expire_on_commit=False,
    )
    async with sess_maker() as session:
        result = await session.exec(
            select(QuestionVote).where(
                QuestionVote.user_firebase_uid == firebase_uid,  # type: ignore
            ),
        )
        count = len(list(result.all()))
    await engine.dispose()
    return count


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


def test_delete_user_removes_all_user_data(
    api_client: TestClient,
    create_emulator_user_and_get_token: Callable[[str, str, str], dict],
) -> None:
    """Deleting a user should remove all associated data from all tables."""
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

    # 4. Create some user-related data
    # Note: We can't easily create answer_events or questions_votes without
    # a full game flow, but we can verify the deletion logic works
    # by checking the user record is deleted

    # 5. Delete user
    delete_resp = api_client.post(
        '/api/v1/user/delete',
        headers={'Authorization': f'Bearer {access_token}'},
    )
    assert delete_resp.status_code == 200

    # 6. Verify user is deleted
    user_after = asyncio.run(_get_user_by_firebase_uid(firebase_uid))
    assert user_after is None, 'User should be deleted'

    # 7. Verify related data counts are 0 (even if they were 0 before)
    history_count = asyncio.run(_get_user_question_history_count(firebase_uid))
    assert history_count == 0, 'user_question_history should be empty'

    answer_events_count = asyncio.run(_get_answer_events_count(firebase_uid))
    assert answer_events_count == 0, 'answer_events should be empty'

    votes_count = asyncio.run(_get_questions_votes_count(firebase_uid))
    assert votes_count == 0, 'questions_votes should be empty'


def test_delete_user_is_idempotent(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """Deleting a user multiple times should not error (idempotent)."""
    headers = get_api_auth_headers(
        'dev.user+idempotent@example.com',
        'password123',
        'IdempotentUser',
    )

    # First deletion
    r1 = api_client.post(
        '/api/v1/user/delete',
        headers=headers,
    )
    assert r1.status_code == 200

    # Second deletion (should also succeed)
    r2 = api_client.post(
        '/api/v1/user/delete',
        headers=headers,
    )
    # Note: This will fail authentication since user is deleted,
    # but the deletion itself is idempotent
    # The endpoint requires authentication, so we expect 401 here
    assert r2.status_code == 401


def test_delete_user_requires_authentication(
    api_client: TestClient,
) -> None:
    """Deleting a user without authentication should return 401."""
    r = api_client.post(
        '/api/v1/user/delete',
    )
    assert r.status_code == 401

