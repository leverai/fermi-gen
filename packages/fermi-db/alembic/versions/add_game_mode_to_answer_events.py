"""Add game_mode column to answer_events table.

Revision ID: add_game_mode_to_answer_events
Revises: add_survival_runs_table
Create Date: 2026-01-15

Adds:
- gamemode enum type (PARTY, SURVIVAL, DAILY_QUESTION)
- game_mode column to answer_events table (nullable for backward compatibility)
- Index on game_mode for efficient filtering
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'add_game_mode_to_answer_events'
down_revision: str | Sequence[str] | None = 'add_survival_runs_table'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add game_mode column to answer_events."""
    op.execute("CREATE TYPE gamemode AS ENUM ('PARTY', 'SURVIVAL', 'DAILY_QUESTION')")
    op.add_column(
        'answer_events',
        sa.Column(
            'game_mode',
            sa.Enum('PARTY', 'SURVIVAL', 'DAILY_QUESTION', name='gamemode'),
            nullable=True,
        ),
    )
    op.create_index('ix_answer_events_game_mode', 'answer_events', ['game_mode'])


def downgrade() -> None:
    """Remove game_mode column from answer_events."""
    op.drop_index('ix_answer_events_game_mode', table_name='answer_events')
    op.drop_column('answer_events', 'game_mode')
    op.execute('DROP TYPE gamemode')
