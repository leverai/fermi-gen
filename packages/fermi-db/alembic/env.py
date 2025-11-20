"""Alembic environment file."""

import asyncio
from logging.config import fileConfig
from typing import Literal

# Ensure SQLModel models are imported so metadata is populated
import fermi_db.models  # noqa: F401
from alembic import context
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy import MetaData, pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine
from sqlalchemy.schema import SchemaItem
from sqlmodel import SQLModel

# Alembic Config
config = context.config

# Logging
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Target metadata for autogenerate
target_metadata: MetaData = SQLModel.metadata


class AlembicSettings(BaseSettings):
    """Settings for Alembic database connection."""

    model_config = SettingsConfigDict(env_file='.env', extra='ignore')
    database_url: str = 'postgresql+asyncpg://postgres:postgres@localhost:5433/fermi'


def _get_database_url() -> str:
    """Return database URL from settings, normalized for asyncpg."""
    url = AlembicSettings().database_url
    if url.startswith('postgresql://'):
        url = url.replace('postgresql://', 'postgresql+asyncpg://', 1)
    if not url:
        raise RuntimeError('DATABASE_URL not set')
    return url


def include_object(
    object_: SchemaItem,
    name: str | None,
    type_: Literal[
        'schema',
        'table',
        'column',
        'index',
        'unique_constraint',
        'foreign_key_constraint',
    ],
    reflected: bool,  # noqa: FBT001
    compare_to: SchemaItem | None,
) -> bool:
    """Decide whether Alembic autogenerate should include an object."""
    # Exclude any materialized views if present in future changes
    if getattr(object_, 'info', {}).get('is_view'):
        return False

    # Exclude the 'fermi' table (it's a materialized view, created manually)
    if type_ == 'table' and name == 'fermi':
        return False

    # Exclude foreign key constraints that reference 'fermi' (materialized view)
    if type_ == 'foreign_key_constraint':
        # Check if FK references fermi table
        if hasattr(object_, 'column') and hasattr(object_.column, 'table'):
            if object_.column.table.name == 'fermi':
                return False

    return True


def run_migrations_offline() -> None:
    """Run migrations in offline mode using a URL."""
    url = _get_database_url()
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={'paramstyle': 'named'},
        include_object=include_object,
        sqlalchemy_module_prefix='sa.',
        compare_type=True,
    )

    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection: Connection) -> None:
    """Configure context with a live connection and run migrations."""
    context.configure(
        connection=connection,
        target_metadata=target_metadata,
        include_object=include_object,
        sqlalchemy_module_prefix='sa.',
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    """Create async engine and run migrations within an async context."""
    connectable: AsyncEngine = create_async_engine(
        _get_database_url(),
        poolclass=pool.NullPool,
    )

    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)


def run_migrations_online() -> None:
    """Run migrations in online mode via asyncio entry point."""
    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
