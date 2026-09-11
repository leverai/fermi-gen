"""Existing-data upgrade/downgrade regression for smart-search schema changes."""

import asyncio
import os
import uuid
from pathlib import Path

import sqlalchemy as sa
from alembic import command
from alembic.config import Config
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.pool import NullPool

_REPO_ROOT = Path(__file__).resolve().parents[4]
_PRE_SMART_SEARCH_REVISION = 'add_points_column'
_QUESTION_ID = 2_000_000_001


def _run_migration(command_name: str, revision: str) -> None:
    """Run an Alembic command against the integration-test database."""
    previous_cwd = Path.cwd()
    try:
        os.chdir(_REPO_ROOT)
        config = Config('alembic.ini')
        config.set_main_option('script_location', 'packages/fermi-db/alembic')
        getattr(command, command_name)(config, revision)
    finally:
        os.chdir(previous_cwd)


async def _seed_pre_migration_rows(database_url: str) -> None:
    """Insert matching source/serving rows before embedding exists on fermi."""
    engine = create_async_engine(database_url, poolclass=NullPool)
    embedding = f'[{",".join(["1"] + ["0"] * 1535)}]'
    try:
        async with engine.begin() as connection:
            await connection.execute(
                sa.text(
                    """
                    INSERT INTO fermi_questions (id, text, embedding)
                    VALUES (
                        :question_id,
                        'migration source',
                        CAST(:embedding AS vector)
                    )
                    """,
                ),
                {'question_id': _QUESTION_ID, 'embedding': embedding},
            )
            await connection.execute(
                sa.text(
                    """
                    INSERT INTO fermi (
                        uid, question_id, text, answer_id, number, snippet,
                        used_ai_overview, random_sort_key,
                        gpt_5_1_number, gpt_5_mini_number, gpt_5_nano_number,
                        gemini_flash_1_number, gemini_flash_2_number,
                        gemini_flash_3_number, gemini_flash_4_number,
                        gemini_flash_5_number, status
                    ) VALUES (
                        :uid, :question_id, 'migration serving', 1, 1.0,
                        'snippet', false, 0,
                        1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
                        'APPROVED'
                    )
                    """,
                ),
                {'uid': uuid.uuid4(), 'question_id': _QUESTION_ID},
            )
    finally:
        await engine.dispose()


async def _assert_upgrade(database_url: str) -> None:
    """Verify backfill, telemetry table, enum, and indexes after upgrade."""
    engine = create_async_engine(database_url, poolclass=NullPool)
    try:
        async with engine.connect() as connection:
            embedding_present = await connection.scalar(
                sa.text(
                    'SELECT embedding IS NOT NULL FROM fermi '
                    'WHERE question_id = :question_id',
                ),
                {'question_id': _QUESTION_ID},
            )
            table_present = await connection.scalar(
                sa.text("SELECT to_regclass('public.smart_search_events') IS NOT NULL"),
            )
            outcomes = (
                (
                    await connection.execute(
                        sa.text(
                            """
                        SELECT enumlabel
                        FROM pg_enum
                        JOIN pg_type ON pg_type.oid = pg_enum.enumtypid
                        WHERE pg_type.typname = 'smartsearchoutcome'
                        ORDER BY enumsortorder
                        """,
                        ),
                    )
                )
                .scalars()
                .all()
            )
            indexes = (
                (
                    await connection.execute(
                        sa.text(
                            """
                        SELECT indexname
                        FROM pg_indexes
                        WHERE tablename = 'smart_search_events'
                        """,
                        ),
                    )
                )
                .scalars()
                .all()
            )

        assert embedding_present is True
        assert table_present is True
        assert outcomes == ['ok', 'too_few', 'embed_error']
        assert {
            'ix_smart_search_events_user_id',
            'ix_smart_search_events_game_id',
        }.issubset(indexes)
    finally:
        await engine.dispose()


async def _assert_downgrade(database_url: str) -> None:
    """Verify smart-search schema objects are removed on downgrade."""
    engine = create_async_engine(database_url, poolclass=NullPool)
    try:
        async with engine.connect() as connection:
            embedding_present = await connection.scalar(
                sa.text(
                    """
                    SELECT EXISTS (
                        SELECT 1 FROM information_schema.columns
                        WHERE table_name = 'fermi' AND column_name = 'embedding'
                    )
                    """,
                ),
            )
            table_present = await connection.scalar(
                sa.text("SELECT to_regclass('public.smart_search_events') IS NOT NULL"),
            )
            enum_present = await connection.scalar(
                sa.text(
                    'SELECT EXISTS (SELECT 1 FROM pg_type '
                    "WHERE typname = 'smartsearchoutcome')",
                ),
            )

        assert embedding_present is False
        assert table_present is False
        assert enum_present is False
    finally:
        await engine.dispose()


def test_smart_search_migration_backfills_existing_rows_and_downgrades(
    database_url: str,
) -> None:
    """Upgrade a populated pre-feature schema, validate it, then downgrade."""
    _run_migration('downgrade', _PRE_SMART_SEARCH_REVISION)
    try:
        asyncio.run(_seed_pre_migration_rows(database_url))
        _run_migration('upgrade', 'head')
        asyncio.run(_assert_upgrade(database_url))

        _run_migration('downgrade', _PRE_SMART_SEARCH_REVISION)
        asyncio.run(_assert_downgrade(database_url))
    finally:
        # Leave the shared integration database at the revision expected by all
        # other tests, even when an assertion above fails.
        _run_migration('upgrade', 'head')
