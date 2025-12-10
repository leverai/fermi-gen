"""Add LLM answers table and update fermi materialized view.

Revision ID: add_llm_answers
Revises: 6795fdb37410
Create Date: 2025-12-09 19:30:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'add_llm_answers'
down_revision: str | Sequence[str] | None = '6795fdb37410'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    # Create llm_answers table
    op.create_table(
        'llm_answers',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('question_id', sa.Integer(), nullable=False),
        sa.Column('model', sa.String(), nullable=False),
        sa.Column('number', sa.Float(), nullable=False),
        sa.Column('unit', sa.String(), nullable=True),
        sa.Column('created_at', sa.TIMESTAMP(), nullable=True),
        sa.ForeignKeyConstraint(
            ['question_id'],
            ['fermi_questions.id'],
        ),
        sa.PrimaryKeyConstraint('id'),
    )
    # Create indexes
    op.create_index(
        op.f('ix_llm_answers_question_id'),
        'llm_answers',
        ['question_id'],
        unique=False,
    )
    op.create_index(
        op.f('ix_llm_answers_model'),
        'llm_answers',
        ['model'],
        unique=False,
    )
    # Create unique constraint for (question_id, model)
    op.create_unique_constraint(
        'uq_llm_answers_question_model',
        'llm_answers',
        ['question_id', 'model'],
    )

    # Drop and recreate the fermi materialized view
    # to include LLM answers (requires all three LLMs)
    op.execute('DROP MATERIALIZED VIEW IF EXISTS fermi CASCADE')

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


def downgrade() -> None:
    """Downgrade schema."""
    # Drop the materialized view
    op.execute('DROP MATERIALIZED VIEW IF EXISTS fermi CASCADE')

    # Recreate original materialized view without LLM answers
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
            floor(random() * 2147483647)::int AS random_sort_key,
            fq.created_at,
            fa.created_at AS updated_at
        FROM fermi_answers fa
        INNER JOIN fermi_questions fq ON fa.question_id = fq.id
        WHERE fa.success = true
        """,
    )

    # Recreate indexes on materialized view
    op.execute('CREATE UNIQUE INDEX ix_fermi_uid ON fermi (uid)')
    op.execute('CREATE INDEX ix_fermi_random_sort_key ON fermi (random_sort_key)')

    # Drop llm_answers table
    op.drop_constraint('uq_llm_answers_question_model', 'llm_answers', type_='unique')
    op.drop_index(op.f('ix_llm_answers_model'), table_name='llm_answers')
    op.drop_index(op.f('ix_llm_answers_question_id'), table_name='llm_answers')
    op.drop_table('llm_answers')
