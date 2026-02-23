"""Add precision_rush_runs table.

Revision ID: add_precision_rush_runs_table
Revises: add_ad_saves_to_survival_runs
Create Date: 2026-02-23

Adds:
- precision_rush_runs table for tracking Precision Rush mode run sessions
"""

# ruff: noqa
from collections.abc import Sequence

import sqlalchemy as sa
import sqlmodel.sql.sqltypes
from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'add_precision_rush_runs_table'
down_revision: str | Sequence[str] | None = 'add_ad_saves_to_survival_runs'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add precision_rush_runs table and extend gamemode enum."""
    # Extend the gamemode enum to include PRECISION_RUSH
    op.execute("ALTER TYPE gamemode ADD VALUE IF NOT EXISTS 'PRECISION_RUSH'")

    op.create_table(
        'precision_rush_runs',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column(
            'user_firebase_uid',
            sqlmodel.sql.sqltypes.AutoString(),
            nullable=False,
        ),
        sa.Column(
            'started_at',
            sa.TIMESTAMP(),
            nullable=False,
            server_default=sa.text('NOW()'),
        ),
        sa.Column('ended_at', sa.TIMESTAMP(), nullable=True),
        sa.Column(
            'questions_answered', sa.Integer(), nullable=False, server_default='0'
        ),
        sa.Column('total_tas', sa.Float(), nullable=False, server_default='0.0'),
        sa.Column(
            'current_question_uid',
            sqlmodel.sql.sqltypes.AutoString(),
            nullable=False,
        ),
        sa.Column('current_deadline', sa.TIMESTAMP(), nullable=True),
        sa.Column('is_completed', sa.Boolean(), nullable=False, server_default='false'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(
        'ix_precision_rush_runs_user_firebase_uid',
        'precision_rush_runs',
        ['user_firebase_uid'],
    )
    op.create_index(
        'ix_precision_rush_runs_current_question_uid',
        'precision_rush_runs',
        ['current_question_uid'],
    )


def downgrade() -> None:
    """Remove precision_rush_runs table and revert gamemode enum."""
    op.drop_index(
        'ix_precision_rush_runs_current_question_uid',
        table_name='precision_rush_runs',
    )
    op.drop_index(
        'ix_precision_rush_runs_user_firebase_uid',
        table_name='precision_rush_runs',
    )
    op.drop_table('precision_rush_runs')

    # Remove PRECISION_RUSH from gamemode enum
    op.execute('ALTER TABLE answer_events ALTER COLUMN game_mode TYPE VARCHAR')
    op.execute('DROP TYPE gamemode')
    op.execute("CREATE TYPE gamemode AS ENUM ('PARTY', 'SURVIVAL', 'DAILY_QUESTION')")
    op.execute(
        'ALTER TABLE answer_events ALTER COLUMN game_mode TYPE gamemode '
        'USING game_mode::gamemode'
    )
