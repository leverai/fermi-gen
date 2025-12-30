"""Add subscriptions table.

Revision ID: add_subscriptions_table
Revises: add_xp_column
Create Date: 2025-01-02

Adds:
- subscriptiontier enum type
- subscriptionplatform enum type
- subscriptions table
"""

# ruff: noqa
from collections.abc import Sequence

import sqlalchemy as sa
import sqlmodel.sql.sqltypes
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'add_subscriptions_table'
down_revision: str | Sequence[str] | None = 'add_xp_column'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add subscriptions table and enum types."""
    # Create enum types
    op.execute(
        "CREATE TYPE subscriptiontier AS ENUM ('FREE', 'PRO')",
    )
    op.execute(
        "CREATE TYPE subscriptionplatform AS ENUM ('APP_STORE', 'PLAY_STORE', 'STRIPE', 'PROMOTIONAL')",
    )

    # Create subscriptions table
    op.create_table(
        'subscriptions',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column(
            'revenuecat_user_id',
            sqlmodel.sql.sqltypes.AutoString(),
            nullable=False,
        ),
        sa.Column(
            'tier',
            postgresql.ENUM(
                'FREE',
                'PRO',
                name='subscriptiontier',
                create_type=False,
            ),
            nullable=False,
            server_default='FREE',
        ),
        sa.Column('product_id', sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column(
            'platform',
            postgresql.ENUM(
                'APP_STORE',
                'PLAY_STORE',
                'STRIPE',
                'PROMOTIONAL',
                name='subscriptionplatform',
                create_type=False,
            ),
            nullable=True,
        ),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('expires_at', sa.TIMESTAMP(), nullable=True),
        sa.Column('original_purchase_date', sa.TIMESTAMP(), nullable=True),
        sa.Column(
            'created_at',
            sa.TIMESTAMP(),
            nullable=False,
            server_default=sa.text('NOW()'),
        ),
        sa.Column(
            'updated_at',
            sa.TIMESTAMP(),
            nullable=False,
            server_default=sa.text('NOW()'),
        ),
        sa.ForeignKeyConstraint(['user_id'], ['user.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id'),
    )
    op.create_index(
        'ix_subscriptions_user_id',
        'subscriptions',
        ['user_id'],
    )
    op.create_index(
        'ix_subscriptions_revenuecat_user_id',
        'subscriptions',
        ['revenuecat_user_id'],
    )


def downgrade() -> None:
    """Remove subscriptions table and enum types."""
    # Drop subscriptions table
    op.drop_index('ix_subscriptions_revenuecat_user_id', table_name='subscriptions')
    op.drop_index('ix_subscriptions_user_id', table_name='subscriptions')
    op.drop_table('subscriptions')

    # Drop enum types
    op.execute('DROP TYPE IF EXISTS subscriptionplatform')
    op.execute('DROP TYPE IF EXISTS subscriptiontier')
