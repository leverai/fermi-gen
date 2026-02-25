"""Add points column to user table.

Revision ID: add_points_column
Revises: add_precision_rush_runs_table
Create Date: 2026-02-25

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'add_points_column'
down_revision: str | None = 'add_precision_rush_runs_table'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add points column to user table."""
    op.add_column(
        'user',
        sa.Column('points', sa.BigInteger(), nullable=False, server_default='0'),
    )


def downgrade() -> None:
    """Remove points column from user table."""
    op.drop_column('user', 'points')
