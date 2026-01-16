"""Initial schema: all tables with complete fermi table.

Revision ID: initial_schema
Revises:
Create Date: 2025-12-14

This is a consolidated migration that creates the complete schema from scratch.
Previous migration history was reset to start with a clean database.

Tables created:
- seeds: Category seeds with embeddings
- user: User profiles
- fermi_questions: Unique questions (production)
- fermi_answers: Ground truth answers from SerpAPI
- llm_answers: LLM-generated answers for bot players
- raw_questions: All generated questions before deduplication
- seeds_usage: Thompson Sampling statistics
- user_question_history: User question tracking
- answer_events: User answer submissions and scores
- questions_votes: User votes on questions
- fermi: Unified table for game (all columns NOT NULL)
"""

from collections.abc import Sequence

import pgvector.sqlalchemy
import sqlalchemy as sa
import sqlmodel.sql.sqltypes
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'initial_schema'
down_revision: str | Sequence[str] | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    # Create extensions
    op.execute('CREATE EXTENSION IF NOT EXISTS vector')
    op.execute('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"')

    # Create enum types
    op.execute(
        'CREATE TYPE questioncategory AS ENUM ('
        "'PLANET_EARTH', 'HUMANITY_BY_NUMBERS', 'POP_CULTURE', "
        "'SHOWER_THOUGHTS', 'COSMIC_PERSPECTIVE', 'OTHER')",
    )
    op.execute("CREATE TYPE questiondifficulty AS ENUM ('EASY', 'MEDIUM', 'HARD')")
    op.execute(
        "CREATE TYPE questionstatus AS ENUM ('PENDING_REVIEW', 'APPROVED', 'REJECTED')",
    )
    op.execute("CREATE TYPE locale AS ENUM ('US', 'EU')")

    # =========================================================================
    # seeds
    # =========================================================================
    op.create_table(
        'seeds',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('seed', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column(
            'embedding',
            pgvector.sqlalchemy.vector.VECTOR(dim=1536),
            nullable=True,
        ),
        sa.Column('created_at', sa.TIMESTAMP(), nullable=True),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_seeds_seed'), 'seeds', ['seed'], unique=True)

    # =========================================================================
    # user
    # =========================================================================
    op.create_table(
        'user',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('firebase_uid', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column('email', sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column('display_name', sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column('picture', sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.Column(
            'locale',
            postgresql.ENUM('US', 'EU', name='locale', create_type=False),
            nullable=False,
        ),
        sa.Column('login_streak', sa.Integer(), nullable=False),
        sa.Column('last_login_at', sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_user_email'), 'user', ['email'], unique=True)
    op.create_index(op.f('ix_user_firebase_uid'), 'user', ['firebase_uid'], unique=True)

    # =========================================================================
    # fermi_questions
    # =========================================================================
    op.create_table(
        'fermi_questions',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('seed_id', sa.Integer(), nullable=True),
        sa.Column('text', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column(
            'embedding',
            pgvector.sqlalchemy.vector.VECTOR(dim=1536),
            nullable=True,
        ),
        sa.Column('source', sa.JSON(), nullable=True),
        sa.Column(
            'category',
            postgresql.ENUM(
                'PLANET_EARTH',
                'HUMANITY_BY_NUMBERS',
                'POP_CULTURE',
                'SHOWER_THOUGHTS',
                'COSMIC_PERSPECTIVE',
                'OTHER',
                name='questioncategory',
                create_type=False,
            ),
            nullable=True,
        ),
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
        sa.Column('created_at', sa.TIMESTAMP(), nullable=True),
        sa.ForeignKeyConstraint(['seed_id'], ['seeds.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(
        op.f('ix_fermi_questions_seed_id'),
        'fermi_questions',
        ['seed_id'],
        unique=False,
    )
    op.create_index(
        op.f('ix_fermi_questions_category'),
        'fermi_questions',
        ['category'],
        unique=False,
    )

    # =========================================================================
    # fermi_answers
    # =========================================================================
    op.create_table(
        'fermi_answers',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('question_id', sa.Integer(), nullable=False),
        sa.Column('number', sa.Float(), nullable=False),
        sa.Column('unit', sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column('snippet', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column('used_ai_overview', sa.Boolean(), nullable=False),
        sa.Column('success', sa.Boolean(), nullable=False),
        sa.Column('serp_metadata', sa.JSON(), nullable=True),
        sa.Column('created_at', sa.TIMESTAMP(), nullable=True),
        sa.ForeignKeyConstraint(['question_id'], ['fermi_questions.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(
        op.f('ix_fermi_answers_question_id'),
        'fermi_answers',
        ['question_id'],
        unique=True,
    )

    # =========================================================================
    # llm_answers
    # =========================================================================
    op.create_table(
        'llm_answers',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('question_id', sa.Integer(), nullable=False),
        sa.Column('model', sa.String(), nullable=False),
        sa.Column('number', sa.Float(), nullable=False),
        sa.Column('unit', sa.String(), nullable=True),
        sa.Column('created_at', sa.TIMESTAMP(), nullable=True),
        sa.ForeignKeyConstraint(['question_id'], ['fermi_questions.id']),
        sa.PrimaryKeyConstraint('id'),
    )
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
    op.create_unique_constraint(
        'uq_llm_answers_question_model',
        'llm_answers',
        ['question_id', 'model'],
    )

    # =========================================================================
    # raw_questions
    # =========================================================================
    op.create_table(
        'raw_questions',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('seed_id', sa.Integer(), nullable=True),
        sa.Column('text', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column(
            'embedding',
            pgvector.sqlalchemy.vector.VECTOR(dim=1536),
            nullable=True,
        ),
        sa.Column('source', sa.JSON(), nullable=True),
        sa.Column('dedup_status', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column('canonical_question_id', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.TIMESTAMP(), nullable=True),
        sa.ForeignKeyConstraint(['canonical_question_id'], ['fermi_questions.id']),
        sa.ForeignKeyConstraint(['seed_id'], ['seeds.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(
        op.f('ix_raw_questions_seed_id'),
        'raw_questions',
        ['seed_id'],
        unique=False,
    )

    # =========================================================================
    # seeds_usage
    # =========================================================================
    op.create_table(
        'seeds_usage',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('seed_id', sa.Integer(), nullable=False),
        sa.Column('requested', sa.Integer(), nullable=False),
        sa.Column('generated', sa.Integer(), nullable=False),
        sa.Column('yielded', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.TIMESTAMP(), nullable=True),
        sa.ForeignKeyConstraint(['seed_id'], ['seeds.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(
        op.f('ix_seeds_usage_created_at'),
        'seeds_usage',
        ['created_at'],
        unique=False,
    )
    op.create_index(
        op.f('ix_seeds_usage_seed_id'),
        'seeds_usage',
        ['seed_id'],
        unique=False,
    )

    # =========================================================================
    # user_question_history
    # =========================================================================
    op.create_table(
        'user_question_history',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column('question_uid', sa.Uuid(), nullable=False),
        sa.Column('seen_at', sa.TIMESTAMP(), nullable=True),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(
        op.f('ix_user_question_history_question_uid'),
        'user_question_history',
        ['question_uid'],
        unique=False,
    )
    op.create_index(
        op.f('ix_user_question_history_user_id'),
        'user_question_history',
        ['user_id'],
        unique=False,
    )

    # =========================================================================
    # answer_events
    # =========================================================================
    op.create_table(
        'answer_events',
        sa.Column('uid', sa.Uuid(), nullable=False),
        sa.Column('question_uid', sa.Uuid(), nullable=False),
        sa.Column(
            'question_difficulty',
            postgresql.ENUM(
                'EASY',
                'MEDIUM',
                'HARD',
                name='questiondifficulty',
                create_type=False,
            ),
            nullable=False,
        ),
        sa.Column(
            'question_category',
            postgresql.ENUM(
                'PLANET_EARTH',
                'HUMANITY_BY_NUMBERS',
                'POP_CULTURE',
                'SHOWER_THOUGHTS',
                'COSMIC_PERSPECTIVE',
                'OTHER',
                name='questioncategory',
                create_type=False,
            ),
            nullable=False,
        ),
        sa.Column(
            'user_firebase_id',
            sqlmodel.sql.sqltypes.AutoString(),
            nullable=False,
        ),
        sa.Column('game_id', sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column('answer', sa.JSON(), nullable=True),
        sa.Column('correct_answer', sa.JSON(), nullable=True),
        sa.Column('score_number', sa.Float(), nullable=False),
        sa.Column('score_quantile', sa.Float(), nullable=False),
        sa.Column('created_at', sa.TIMESTAMP(), nullable=True),
        sa.PrimaryKeyConstraint('uid'),
    )
    op.create_index(
        op.f('ix_answer_events_user_firebase_id'),
        'answer_events',
        ['user_firebase_id'],
        unique=False,
    )

    # =========================================================================
    # questions_votes
    # =========================================================================
    op.create_table(
        'questions_votes',
        sa.Column('question_uid', sa.Uuid(), nullable=False),
        sa.Column(
            'user_firebase_uid',
            sqlmodel.sql.sqltypes.AutoString(),
            nullable=False,
        ),
        sa.Column('verdict', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.TIMESTAMP(), nullable=True),
        sa.Column('updated_at', sa.TIMESTAMP(), nullable=True),
        sa.PrimaryKeyConstraint('question_uid', 'user_firebase_uid'),
    )

    # =========================================================================
    # fermi (production table - all LLM answer columns NOT NULL)
    # =========================================================================
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
            postgresql.ENUM(
                'EASY',
                'MEDIUM',
                'HARD',
                name='questiondifficulty',
                create_type=False,
            ),
            nullable=True,
        ),
        sa.Column(
            'category',
            postgresql.ENUM(
                'PLANET_EARTH',
                'HUMANITY_BY_NUMBERS',
                'POP_CULTURE',
                'SHOWER_THOUGHTS',
                'COSMIC_PERSPECTIVE',
                'OTHER',
                name='questioncategory',
                create_type=False,
            ),
            nullable=True,
        ),
        sa.Column('random_sort_key', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.TIMESTAMP(), nullable=True),
        sa.Column('updated_at', sa.TIMESTAMP(), nullable=True),
        # GPT LLM answer columns
        sa.Column('gpt_5_1_number', sa.Float(), nullable=False),
        sa.Column('gpt_5_1_unit', sa.String(), nullable=True),
        sa.Column('gpt_5_mini_number', sa.Float(), nullable=False),
        sa.Column('gpt_5_mini_unit', sa.String(), nullable=True),
        sa.Column('gpt_5_nano_number', sa.Float(), nullable=False),
        sa.Column('gpt_5_nano_unit', sa.String(), nullable=True),
        # Gemini Flash answer columns (NOT NULL for fresh schema)
        sa.Column('gemini_flash_1_number', sa.Float(), nullable=False),
        sa.Column('gemini_flash_1_unit', sa.String(), nullable=True),
        sa.Column('gemini_flash_2_number', sa.Float(), nullable=False),
        sa.Column('gemini_flash_2_unit', sa.String(), nullable=True),
        sa.Column('gemini_flash_3_number', sa.Float(), nullable=False),
        sa.Column('gemini_flash_3_unit', sa.String(), nullable=True),
        sa.Column('gemini_flash_4_number', sa.Float(), nullable=False),
        sa.Column('gemini_flash_4_unit', sa.String(), nullable=True),
        sa.Column('gemini_flash_5_number', sa.Float(), nullable=False),
        sa.Column('gemini_flash_5_unit', sa.String(), nullable=True),
        # Status column
        sa.Column(
            'status',
            postgresql.ENUM(
                'PENDING_REVIEW',
                'APPROVED',
                'REJECTED',
                name='questionstatus',
                create_type=False,
            ),
            nullable=False,
            server_default='PENDING_REVIEW',
        ),
        sa.PrimaryKeyConstraint('uid'),
    )
    op.create_index('ix_fermi_uid', 'fermi', ['uid'], unique=True)
    op.create_index('ix_fermi_random_sort_key', 'fermi', ['random_sort_key'])
    op.create_index('ix_fermi_status', 'fermi', ['status'])
    op.create_index('ix_fermi_question_id', 'fermi', ['question_id'], unique=True)


def downgrade() -> None:
    """Downgrade schema."""
    # Drop tables in reverse order of creation
    op.drop_index('ix_fermi_question_id', table_name='fermi')
    op.drop_index('ix_fermi_status', table_name='fermi')
    op.drop_index('ix_fermi_random_sort_key', table_name='fermi')
    op.drop_index('ix_fermi_uid', table_name='fermi')
    op.drop_table('fermi')

    op.drop_table('questions_votes')

    op.drop_index(op.f('ix_answer_events_user_firebase_id'), table_name='answer_events')
    op.drop_table('answer_events')

    op.drop_index(
        op.f('ix_user_question_history_user_id'),
        table_name='user_question_history',
    )
    op.drop_index(
        op.f('ix_user_question_history_question_uid'),
        table_name='user_question_history',
    )
    op.drop_table('user_question_history')

    op.drop_index(op.f('ix_seeds_usage_seed_id'), table_name='seeds_usage')
    op.drop_index(op.f('ix_seeds_usage_created_at'), table_name='seeds_usage')
    op.drop_table('seeds_usage')

    op.drop_index(op.f('ix_raw_questions_seed_id'), table_name='raw_questions')
    op.drop_table('raw_questions')

    op.drop_constraint('uq_llm_answers_question_model', 'llm_answers', type_='unique')
    op.drop_index(op.f('ix_llm_answers_model'), table_name='llm_answers')
    op.drop_index(op.f('ix_llm_answers_question_id'), table_name='llm_answers')
    op.drop_table('llm_answers')

    op.drop_index(op.f('ix_fermi_answers_question_id'), table_name='fermi_answers')
    op.drop_table('fermi_answers')

    op.drop_index(op.f('ix_fermi_questions_category'), table_name='fermi_questions')
    op.drop_index(op.f('ix_fermi_questions_seed_id'), table_name='fermi_questions')
    op.drop_table('fermi_questions')

    op.drop_index(op.f('ix_user_firebase_uid'), table_name='user')
    op.drop_index(op.f('ix_user_email'), table_name='user')
    op.drop_table('user')

    op.drop_index(op.f('ix_seeds_seed'), table_name='seeds')
    op.drop_table('seeds')

    # Drop enum types
    op.execute('DROP TYPE IF EXISTS locale')
    op.execute('DROP TYPE IF EXISTS questionstatus')
    op.execute('DROP TYPE IF EXISTS questiondifficulty')
    op.execute('DROP TYPE IF EXISTS questioncategory')

    # Drop extensions
    op.execute('DROP EXTENSION IF EXISTS "uuid-ossp"')
    op.execute('DROP EXTENSION IF EXISTS vector')
