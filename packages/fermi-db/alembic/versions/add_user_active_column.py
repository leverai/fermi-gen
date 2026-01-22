"""Add active column to user table.

Revision ID: add_user_active_column
Revises: add_streak_to_survival_runs
Create Date: 2026-01-22

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'add_user_active_column'
down_revision: str | Sequence[str] | None = 'add_streak_to_survival_runs'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add active column to user table for soft-delete support."""
    op.add_column(
        'user',
        sa.Column('active', sa.Boolean(), nullable=False, server_default='true'),
    )


def downgrade() -> None:
    """Remove active column from user table."""
    op.drop_column('user', 'active')
