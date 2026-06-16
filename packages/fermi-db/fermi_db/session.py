"""Database session management."""

import json
import os
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager
from functools import partial

from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlmodel.ext.asyncio.session import AsyncSession

DATABASE_URL = os.environ.get('DATABASE_URL', 'sqlite+aiosqlite:///./guesstimate.db')

# `sa.JSON` columns serialize through json.dumps. The stdlib default raises on
# common value types (uuid.UUID, datetime, Decimal), and because every repository
# shares ONE AsyncSession, a single failed flush poisons the whole request (the
# next op raises PendingRollbackError -> a 500). `default=str` coerces such a
# stray value to its string form so it degrades to readable data instead of
# taking the session down. Callers should still store JSON-native types directly;
# this is a safety net, not a license to put arbitrary objects in JSON columns.
# Use a small pool and graceful pre-ping for tests; echo off to reduce noise
async_engine = create_async_engine(
    DATABASE_URL,
    echo=False,
    pool_pre_ping=True,
    json_serializer=partial(json.dumps, default=str),
)

_async_session_maker = async_sessionmaker(
    async_engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


async def get_session() -> AsyncGenerator[AsyncSession, None]:
    """Get an async database session."""
    async with _async_session_maker() as session:
        yield session


@asynccontextmanager
async def session_context() -> AsyncGenerator[AsyncSession, None]:
    """Yield a short-lived ``AsyncSession`` for use outside request DI.

    Intended for background tasks and scripts that must manage their own
    database session lifecycle. Ensures the connection is returned to the pool
    deterministically at context exit.
    """
    async with _async_session_maker() as session:
        yield session
