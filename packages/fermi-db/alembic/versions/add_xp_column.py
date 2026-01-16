"""Add xp column to user table.

Revision ID: add_xp_column
Revises: add_daily_question_tables
Create Date: 2025-12-28

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'add_xp_column'
down_revision: str | None = 'add_daily_question_tables'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add xp column to user table."""
    op.add_column(
        'user',
        sa.Column('xp', sa.BigInteger(), nullable=False, server_default='0'),
    )


def downgrade() -> None:
    """Remove xp column from user table."""
    op.drop_column('user', 'xp')
