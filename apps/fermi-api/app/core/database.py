"""Database module."""

# Import all models to register them with SQLModel
from fermi_db.models import *  # noqa
from fermi_db.session import async_engine
from sqlmodel import SQLModel


async def create_db_and_tables() -> None:
    """Create database and tables."""
    async with async_engine.begin() as conn:
        await conn.run_sync(SQLModel.metadata.create_all)
