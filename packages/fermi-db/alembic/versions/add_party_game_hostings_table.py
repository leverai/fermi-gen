"""Add party_hostings table.

Revision ID: add_party_hostings_table
Revises: add_subscriptions_table
Create Date: 2025-01-09

Adds:
- party_hostings table for tracking party game hosting events
"""

# ruff: noqa
from collections.abc import Sequence

import sqlalchemy as sa
import sqlmodel.sql.sqltypes
from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'add_party_hostings_table'
down_revision: str | Sequence[str] | None = 'add_is_post_take_column'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add party_hostings table."""
    op.create_table(
        'party_hostings',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column(
            'game_id', sqlmodel.sql.sqltypes.AutoString(length=255), nullable=False
        ),
        sa.Column(
            'created_at',
            sa.TIMESTAMP(),
            nullable=False,
            server_default=sa.text('NOW()'),
        ),
        sa.ForeignKeyConstraint(['user_id'], ['user.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(
        'ix_party_hostings_user_id',
        'party_hostings',
        ['user_id'],
    )
    op.create_index(
        'ix_party_hostings_created_at',
        'party_hostings',
        ['created_at'],
    )


def downgrade() -> None:
    """Remove party_hostings table."""
    op.drop_index('ix_party_hostings_created_at', table_name='party_hostings')
    op.drop_index('ix_party_hostings_user_id', table_name='party_hostings')
    op.drop_table('party_hostings')
