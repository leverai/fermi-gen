"""Add ad_saves_used column to survival_runs.

Revision ID: add_ad_saves_to_survival_runs
Revises: add_user_active_column
Create Date: 2026-01-23

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'add_ad_saves_to_survival_runs'
down_revision: str | Sequence[str] | None = 'add_user_active_column'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add ad_saves_used column to track ad-based streak saves."""
    op.add_column(
        'survival_runs',
        sa.Column('ad_saves_used', sa.Integer(), nullable=False, server_default='0'),
    )


def downgrade() -> None:
    """Remove ad_saves_used column."""
    op.drop_column('survival_runs', 'ad_saves_used')
