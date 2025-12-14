"""Add Gemini Flash answer columns to fermi table.

Revision ID: add_gemini_flash
Revises: convert_fermi_to_table
Create Date: 2025-12-13

This migration adds 10 columns for 5 Gemini Flash bot answers:
- gemini_flash_1_number, gemini_flash_1_unit
- gemini_flash_2_number, gemini_flash_2_unit
- gemini_flash_3_number, gemini_flash_3_unit
- gemini_flash_4_number, gemini_flash_4_unit
- gemini_flash_5_number, gemini_flash_5_unit

Note: Existing rows will have NULL values for these columns.
The sync_fermi_table query will require all 5 Gemini answers
before inserting new rows (enforced via INNER JOINs).
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'add_gemini_flash'
down_revision: str | Sequence[str] | None = 'convert_fermi_to_table'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add Gemini Flash answer columns to fermi table."""
    # Add columns for 5 Gemini Flash bots
    # Using nullable=True since existing rows don't have these answers yet
    for i in range(1, 6):
        op.add_column(
            'fermi',
            sa.Column(f'gemini_flash_{i}_number', sa.Float(), nullable=True),
        )
        op.add_column(
            'fermi',
            sa.Column(f'gemini_flash_{i}_unit', sa.String(), nullable=True),
        )


def downgrade() -> None:
    """Remove Gemini Flash answer columns from fermi table."""
    # Drop columns in reverse order
    for i in range(5, 0, -1):
        op.drop_column('fermi', f'gemini_flash_{i}_unit')
        op.drop_column('fermi', f'gemini_flash_{i}_number')
