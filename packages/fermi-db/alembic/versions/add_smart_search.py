"""Add smart search support: fermi.embedding column + smart_search_events table.

Revision ID: add_smart_search
Revises: add_points_column
Create Date: 2026-06-14

Adds:
- fermi.embedding VECTOR(1536) column (nullable), backfilled from fermi_questions
- smart_search_events table for smart-search telemetry (floor/pool tuning)

No ANN index is created: an exact cosine scan is fine at current corpus scale.
"""

# ruff: noqa
from collections.abc import Sequence

import pgvector.sqlalchemy
import sqlalchemy as sa
import sqlmodel.sql.sqltypes
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'add_smart_search'
down_revision: str | Sequence[str] | None = 'add_points_column'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add embedding column to fermi (+ backfill) and smart_search_events table."""
    # 1. Add the nullable embedding column to the serving `fermi` table.
    op.add_column(
        'fermi',
        sa.Column(
            'embedding',
            pgvector.sqlalchemy.vector.VECTOR(dim=1536),
            nullable=True,
        ),
    )

    # 2. Backfill embeddings from the ETL source table. fermi.uid is a v5 hash of
    #    fermi_questions.id, but fermi also carries the plain question_id, so we
    #    join on that.
    op.execute(
        """
        UPDATE fermi
        SET embedding = fq.embedding
        FROM fermi_questions fq
        WHERE fermi.question_id = fq.id
        """,
    )

    # 3. Telemetry table for smart-search attempts (game_id nullable: a too-few /
    #    embed-error search produces no game but is still recorded for tuning).
    op.create_table(
        'smart_search_events',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column('game_id', sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column('query', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column(
            'difficulty',
            postgresql.ENUM(
                'EASY',
                'MEDIUM',
                'HARD',
                name='questiondifficulty',
                create_type=False,
            ),
            nullable=True,
        ),
        sa.Column('returned_uids', sa.JSON(), nullable=False),
        sa.Column('n', sa.Integer(), nullable=False),
        sa.Column('returned_similarities', sa.JSON(), nullable=False),
        sa.Column('candidate_pool_size', sa.Integer(), nullable=False),
        sa.Column('outcome', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column('floor_used', sa.Float(), nullable=False),
        sa.Column('pool_size_used', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.TIMESTAMP(), nullable=True),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(
        op.f('ix_smart_search_events_user_id'),
        'smart_search_events',
        ['user_id'],
    )
    op.create_index(
        op.f('ix_smart_search_events_game_id'),
        'smart_search_events',
        ['game_id'],
    )


def downgrade() -> None:
    """Drop smart_search_events table and the fermi.embedding column."""
    op.drop_index(
        op.f('ix_smart_search_events_game_id'),
        table_name='smart_search_events',
    )
    op.drop_index(
        op.f('ix_smart_search_events_user_id'),
        table_name='smart_search_events',
    )
    op.drop_table('smart_search_events')
    op.drop_column('fermi', 'embedding')
