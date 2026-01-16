"""Add is_post_take column to daily_question_answers table.

Revision ID: add_is_post_take_column
Revises: add_subscriptions_table
Create Date: 2026-01-05

Adds:
- is_post_take boolean column to daily_question_answers table
  (True if answer was submitted after the DQ window closed)
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'add_is_post_take_column'
down_revision: str | Sequence[str] | None = 'add_subscriptions_table'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add is_post_take column to daily_question_answers table."""
    op.add_column(
        'daily_question_answers',
        sa.Column('is_post_take', sa.Boolean(), nullable=False, server_default='false'),
    )


def downgrade() -> None:
    """Remove is_post_take column from daily_question_answers table."""
    op.drop_column('daily_question_answers', 'is_post_take')
