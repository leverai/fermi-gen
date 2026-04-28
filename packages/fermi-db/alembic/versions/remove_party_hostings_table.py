"""Remove party_hostings table.

Revision ID: remove_party_hostings_table
Revises: add_points_column
Create Date: 2026-04-28

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'remove_party_hostings_table'
down_revision: str | None = 'add_points_column'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Remove party_hostings table."""
    op.drop_index('ix_party_hostings_created_at', table_name='party_hostings')
    op.drop_index('ix_party_hostings_user_id', table_name='party_hostings')
    op.drop_table('party_hostings')


def downgrade() -> None:
    """Restore party_hostings table (empty)."""
    op.create_table(
        'party_hostings',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('game_id', sa.String(length=255), nullable=False),
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
