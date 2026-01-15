"""Add streak column to survival_runs table.

Revision ID: add_streak_to_survival_runs
Revises: add_xp_column
Create Date: 2026-01-15

Adds:
- streak column to survival_runs table with backfill for existing data
"""

# ruff: noqa
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'add_streak_to_survival_runs'
down_revision: str | Sequence[str] | None = 'add_xp_column'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add streak column and backfill existing data."""
    # Add streak column with default 0
    op.add_column(
        'survival_runs',
        sa.Column('streak', sa.Integer(), nullable=False, server_default='0'),
    )

    # Create index for efficient leaderboard sorting
    op.create_index(
        'ix_survival_runs_streak',
        'survival_runs',
        ['streak'],
    )

    # Backfill existing data:
    # - Completed runs: streak = questions_answered - 1 (lost on last question)
    # - Active runs: streak = questions_answered
    op.execute("""
        UPDATE survival_runs
        SET streak = CASE
            WHEN is_completed THEN GREATEST(questions_answered - 1, 0)
            ELSE questions_answered
        END
    """)


def downgrade() -> None:
    """Remove streak column."""
    op.drop_index('ix_survival_runs_streak', table_name='survival_runs')
    op.drop_column('survival_runs', 'streak')
