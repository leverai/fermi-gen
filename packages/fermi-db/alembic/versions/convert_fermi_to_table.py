"""Convert fermi from materialized view to table with status column.

Revision ID: convert_fermi_to_table
Revises: add_llm_answers
Create Date: 2025-12-12 18:45:00.000000

This migration:
1. Drops the fermi materialized view
2. Creates the fermi table with a status column for human review
3. Migrates existing data with status = 'PENDING_REVIEW'
4. Creates necessary indexes
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'convert_fermi_to_table'
down_revision: str | Sequence[str] | None = 'add_llm_answers'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    # Drop the materialized view
    op.execute('DROP MATERIALIZED VIEW IF EXISTS fermi CASCADE')

    # Create the fermi table with status column
    op.create_table(
        'fermi',
        sa.Column('uid', sa.Uuid(), nullable=False),
        sa.Column('question_id', sa.Integer(), nullable=False),
        sa.Column('text', sa.String(), nullable=False),
        sa.Column('question_source', sa.JSON(), nullable=True),
        sa.Column('answer_id', sa.Integer(), nullable=False),
        sa.Column('number', sa.Float(), nullable=False),
        sa.Column('unit', sa.String(), nullable=True),
        sa.Column('snippet', sa.String(), nullable=False),
        sa.Column('used_ai_overview', sa.Boolean(), nullable=False),
        sa.Column(
            'difficulty',
            sa.Enum('EASY', 'MEDIUM', 'HARD', name='questiondifficulty'),
            nullable=True,
        ),
        sa.Column(
            'category',
            sa.Enum(
                'PLANET_EARTH',
                'HUMANITY_BY_NUMBERS',
                'POP_CULTURE',
                'SHOWER_THOUGHTS',
                'COSMIC_PERSPECTIVE',
                'OTHER',
                name='questioncategory',
            ),
            nullable=True,
        ),
        sa.Column('random_sort_key', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.TIMESTAMP(), nullable=True),
        sa.Column('updated_at', sa.TIMESTAMP(), nullable=True),
        # LLM answer columns
        sa.Column('gpt_5_1_number', sa.Float(), nullable=False),
        sa.Column('gpt_5_1_unit', sa.String(), nullable=True),
        sa.Column('gpt_5_mini_number', sa.Float(), nullable=False),
        sa.Column('gpt_5_mini_unit', sa.String(), nullable=True),
        sa.Column('gpt_5_nano_number', sa.Float(), nullable=False),
        sa.Column('gpt_5_nano_unit', sa.String(), nullable=True),
        # New status column for human review
        sa.Column(
            'status',
            sa.Enum(
                'PENDING_REVIEW',
                'APPROVED',
                'REJECTED',
                name='questionstatus',
            ),
            nullable=False,
            server_default='PENDING_REVIEW',
        ),
        sa.PrimaryKeyConstraint('uid'),
    )

    # Create indexes
    op.create_index('ix_fermi_uid', 'fermi', ['uid'], unique=True)
    op.create_index('ix_fermi_random_sort_key', 'fermi', ['random_sort_key'])
    op.create_index('ix_fermi_status', 'fermi', ['status'])
    op.create_index('ix_fermi_question_id', 'fermi', ['question_id'], unique=True)

    # Migrate existing data from source tables
    op.execute(
        """
        INSERT INTO fermi (
            uid,
            question_id,
            text,
            question_source,
            answer_id,
            number,
            unit,
            snippet,
            used_ai_overview,
            difficulty,
            category,
            random_sort_key,
            created_at,
            updated_at,
            gpt_5_1_number,
            gpt_5_1_unit,
            gpt_5_mini_number,
            gpt_5_mini_unit,
            gpt_5_nano_number,
            gpt_5_nano_unit,
            status
        )
        SELECT
            uuid_generate_v5(
                '6ba7b810-9dad-11d1-80b4-00c04fd430c8'::uuid,
                fq.id::text
            ) AS uid,
            fq.id AS question_id,
            fq.text,
            fq.source AS question_source,
            fa.id AS answer_id,
            fa.number,
            fa.unit,
            fa.snippet,
            fa.used_ai_overview,
            fq.difficulty,
            fq.category,
            floor(random() * 2147483647)::int AS random_sort_key,
            fq.created_at,
            GREATEST(
                fa.created_at,
                la_51.created_at,
                la_mini.created_at,
                la_nano.created_at
            ) AS updated_at,
            la_51.number AS gpt_5_1_number,
            la_51.unit AS gpt_5_1_unit,
            la_mini.number AS gpt_5_mini_number,
            la_mini.unit AS gpt_5_mini_unit,
            la_nano.number AS gpt_5_nano_number,
            la_nano.unit AS gpt_5_nano_unit,
            'PENDING_REVIEW' AS status
        FROM fermi_answers fa
        INNER JOIN fermi_questions fq ON fa.question_id = fq.id
        INNER JOIN llm_answers la_51 ON fq.id = la_51.question_id
            AND la_51.model = 'gpt-5.1'
        INNER JOIN llm_answers la_mini ON fq.id = la_mini.question_id
            AND la_mini.model = 'gpt-5-mini'
        INNER JOIN llm_answers la_nano ON fq.id = la_nano.question_id
            AND la_nano.model = 'gpt-5-nano'
        WHERE fa.success = true
        """,
    )


def downgrade() -> None:
    """Downgrade schema."""
    # Drop the table
    op.drop_index('ix_fermi_question_id', table_name='fermi')
    op.drop_index('ix_fermi_status', table_name='fermi')
    op.drop_index('ix_fermi_random_sort_key', table_name='fermi')
    op.drop_index('ix_fermi_uid', table_name='fermi')
    op.drop_table('fermi')

    # Drop the questionstatus enum
    op.execute('DROP TYPE IF EXISTS questionstatus')

    # Recreate the materialized view (from add_llm_answers migration)
    op.execute(
        """
        CREATE MATERIALIZED VIEW fermi AS
        SELECT
            uuid_generate_v5(
                '6ba7b810-9dad-11d1-80b4-00c04fd430c8'::uuid,
                fq.id::text
            ) AS uid,
            fq.id AS question_id,
            fq.text,
            fq.source AS question_source,
            fa.id AS answer_id,
            fa.number,
            fa.unit,
            fa.snippet,
            fa.used_ai_overview,
            fq.difficulty,
            fq.category,
            -- LLM answers
            la_51.number AS gpt_5_1_number,
            la_51.unit AS gpt_5_1_unit,
            la_mini.number AS gpt_5_mini_number,
            la_mini.unit AS gpt_5_mini_unit,
            la_nano.number AS gpt_5_nano_number,
            la_nano.unit AS gpt_5_nano_unit,
            floor(random() * 2147483647)::int AS random_sort_key,
            fq.created_at,
            GREATEST(
                fa.created_at,
                la_51.created_at,
                la_mini.created_at,
                la_nano.created_at
            ) AS updated_at
        FROM fermi_answers fa
        INNER JOIN fermi_questions fq ON fa.question_id = fq.id
        INNER JOIN llm_answers la_51 ON fq.id = la_51.question_id
            AND la_51.model = 'gpt-5.1'
        INNER JOIN llm_answers la_mini ON fq.id = la_mini.question_id
            AND la_mini.model = 'gpt-5-mini'
        INNER JOIN llm_answers la_nano ON fq.id = la_nano.question_id
            AND la_nano.model = 'gpt-5-nano'
        WHERE fa.success = true
        """,
    )

    # Recreate indexes on materialized view
    op.execute('CREATE UNIQUE INDEX ix_fermi_uid ON fermi (uid)')
    op.execute('CREATE INDEX ix_fermi_random_sort_key ON fermi (random_sort_key)')
