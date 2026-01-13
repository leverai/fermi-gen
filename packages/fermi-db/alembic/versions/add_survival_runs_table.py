"""Add survival_runs table.

Revision ID: add_survival_runs_table
Revises: add_party_hostings_table
Create Date: 2026-01-12

Adds:
- survival_runs table for tracking survival mode run sessions
"""

# ruff: noqa
from collections.abc import Sequence

import sqlalchemy as sa
import sqlmodel.sql.sqltypes
from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'add_survival_runs_table'
down_revision: str | Sequence[str] | None = 'add_party_hostings_table'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add survival_runs table."""
    op.create_table(
        'survival_runs',
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
        sa.Column('questions_answered', sa.Integer(), nullable=False, default=0),
        sa.Column('total_score', sa.Float(), nullable=False, default=0.0),
        sa.Column(
            'current_question_uid',
            sqlmodel.sql.sqltypes.AutoString(),
            nullable=False,
        ),
        sa.Column('current_deadline', sa.TIMESTAMP(), nullable=True),
        sa.Column('is_completed', sa.Boolean(), nullable=False, default=False),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(
        'ix_survival_runs_user_firebase_uid',
        'survival_runs',
        ['user_firebase_uid'],
    )
    op.create_index(
        'ix_survival_runs_current_question_uid',
        'survival_runs',
        ['current_question_uid'],
    )


def downgrade() -> None:
    """Remove survival_runs table."""
    op.drop_index('ix_survival_runs_current_question_uid', table_name='survival_runs')
    op.drop_index('ix_survival_runs_user_firebase_uid', table_name='survival_runs')
    op.drop_table('survival_runs')
