"""Serialization regression tests for FermiRepository.insert_smart_search_event.

These exercise the REAL persistence path: a real ``AsyncSession`` over in-memory
SQLite, using the engine's DEFAULT JSON serializer (``json.dumps``) -- exactly
like ``fermi_db.session`` (which sets no custom ``json_serializer``). No
pgvector/Postgres is needed: ``smart_search_events`` has no Vector column, so it
creates and round-trips on SQLite.

Why this exists (BUG C1): the gateway unit tests stub ``insert_smart_search_event``,
so they never hit serialization. ``SmartSearchEvent.returned_uids`` is a JSON
column; if it holds ``uuid.UUID`` objects the default ``json.dumps`` raises
``TypeError: Object of type UUID is not JSON serializable`` on commit, which then
poisons the shared session (the next query raises ``PendingRollbackError``) and
turns a *successful* smart search into an HTTP 500. The fix stores str uids.

These tests use ``asyncio.run`` in plain sync test bodies so collection does not
depend on the project's pytest-asyncio mode.
"""

import asyncio
import uuid
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

import pytest
from fermi_db.models import SmartSearchEvent
from fermi_db.repositories.fermi_repository import FermiRepository
from fermi_db.schemas import QuestionDifficulty
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlmodel import select
from sqlmodel.ext.asyncio.session import AsyncSession


@asynccontextmanager
async def _sqlite_session() -> AsyncGenerator[AsyncSession, None]:
    """Yield a real AsyncSession on in-memory SQLite with the DEFAULT serializer.

    Mirrors ``fermi_db.session``: no ``json_serializer`` is passed, so the JSON
    columns go through the stdlib ``json.dumps`` default -- the exact serializer
    that fails on ``uuid.UUID`` in production.
    """
    engine = create_async_engine('sqlite+aiosqlite:///:memory:', echo=False)
    try:
        async with engine.begin() as conn:
            # Create only the telemetry table (no Vector column -> SQLite-safe).
            await conn.run_sync(
                lambda c: SmartSearchEvent.__table__.create(c, checkfirst=True),
            )
        maker = async_sessionmaker(
            engine,
            class_=AsyncSession,
            expire_on_commit=False,
        )
        async with maker() as session:
            yield session
    finally:
        await engine.dispose()


def test_insert_smart_search_event_with_str_uids_commits_and_round_trips() -> None:
    """A SmartSearchEvent built from uuid-derived str uids commits + round-trips.

    This is the regression guard for C1: it drives the real repository insert
    (session.add + commit) over the default serializer and asserts the JSON uid
    array survives a re-read. Had returned_uids stayed ``list[uuid.UUID]``, the
    commit would raise here.
    """

    async def _run() -> None:
        uids = [uuid.uuid4(), uuid.uuid4(), uuid.uuid4()]
        async with _sqlite_session() as session:
            repo = FermiRepository(session)
            event = SmartSearchEvent(
                user_id='host-1',
                game_id='g-1',
                query='space scale',
                difficulty=QuestionDifficulty.EASY,
                returned_uids=[str(u) for u in uids],
                n=len(uids),
                returned_similarities=[0.95, 0.80, 0.71],
                outcome='ok',
                floor_used=0.30,
                pool_size_used=25,
            )
            # Must NOT raise (the bug raised TypeError on commit here).
            await repo.insert_smart_search_event(event)

            # Re-read from the DB and confirm the JSON arrays round-tripped.
            stored = (await session.exec(select(SmartSearchEvent))).one()
            assert stored.returned_uids == [str(u) for u in uids]
            assert all(isinstance(u, str) for u in stored.returned_uids)
            assert stored.returned_similarities == pytest.approx([0.95, 0.80, 0.71])
            assert stored.n == 3
            assert stored.outcome == 'ok'
            assert stored.game_id == 'g-1'

    asyncio.run(_run())


def test_insert_smart_search_event_empty_uids_for_embed_error() -> None:
    """The embed_error / too-few shapes (empty uid + similarity lists) persist too."""

    async def _run() -> None:
        async with _sqlite_session() as session:
            repo = FermiRepository(session)
            event = SmartSearchEvent(
                user_id='host-1',
                game_id=None,  # no game produced
                query='asdfqwer',
                difficulty=None,
                returned_uids=[],
                n=0,
                returned_similarities=[],
                outcome='embed_error',
                floor_used=0.30,
                pool_size_used=25,
            )
            await repo.insert_smart_search_event(event)

            stored = (await session.exec(select(SmartSearchEvent))).one()
            assert stored.returned_uids == []
            assert stored.game_id is None
            assert stored.outcome == 'embed_error'

    asyncio.run(_run())


def test_uuid_objects_in_json_column_break_default_serializer() -> None:
    """Pin the root cause: raw ``uuid.UUID`` in the JSON column kills the commit.

    Documents *why* ``returned_uids`` must be ``list[str]``: feeding ``uuid.UUID``
    objects (what the buggy code did) raises on commit under the default
    serializer, and leaves the session needing a rollback. If a future change
    makes ``uuid.UUID`` serialize transparently, revisit the str conversion.
    """

    async def _run() -> None:
        async with _sqlite_session() as session:
            repo = FermiRepository(session)
            bad_event = SmartSearchEvent(
                user_id='host-1',
                game_id='g-1',
                query='space scale',
                difficulty=None,
                # The pre-fix mistake: uuid.UUID objects, not strings.
                returned_uids=[uuid.uuid4(), uuid.uuid4()],  # type: ignore[list-item]
                n=2,
                returned_similarities=[0.9, 0.8],
                outcome='ok',
                floor_used=0.30,
                pool_size_used=25,
            )
            with pytest.raises(Exception, match='UUID is not JSON serializable'):
                await repo.insert_smart_search_event(bad_event)
            # And the session is now poisoned until rolled back -- the mechanism
            # the gateway's except-block rollback exists to recover from.
            await session.rollback()

    asyncio.run(_run())


if __name__ == '__main__':
    test_insert_smart_search_event_with_str_uids_commits_and_round_trips()
    test_insert_smart_search_event_empty_uids_for_embed_error()
    test_uuid_objects_in_json_column_break_default_serializer()
    print('all fermi-db smart-search insert regression tests passed')
