"""Add Daily Question tables.

Revision ID: add_daily_question_tables
Revises: initial_schema
Create Date: 2025-12-15

Adds:
- is_daily_question column to fermi table
- dailyquestionstatus enum type
- daily_questions table
- daily_question_answers table
"""

from collections.abc import Sequence

import sqlalchemy as sa
import sqlmodel.sql.sqltypes
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'add_daily_question_tables'
down_revision: str | Sequence[str] | None = 'initial_schema'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add Daily Question mode tables and columns."""
    # Create enum type for daily question status
    op.execute(
        "CREATE TYPE dailyquestionstatus AS ENUM ('SCHEDULED', 'ACTIVE', 'CLOSED')",
    )

    # Add is_daily_question column to fermi table
    op.add_column(
        'fermi',
        sa.Column(
            'is_daily_question',
            sa.Boolean(),
            nullable=False,
            server_default='false',
        ),
    )
    op.create_index(
        'ix_fermi_is_daily_question',
        'fermi',
        ['is_daily_question'],
    )

    # Create daily_questions table
    op.create_table(
        'daily_questions',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('question_date', sa.Date(), nullable=False),
        sa.Column('question_uid', sa.Uuid(), nullable=False),
        sa.Column(
            'status',
            postgresql.ENUM(
                'SCHEDULED',
                'ACTIVE',
                'CLOSED',
                name='dailyquestionstatus',
                create_type=False,
            ),
            nullable=False,
            server_default='SCHEDULED',
        ),
        sa.Column('window_start', sa.TIMESTAMP(), nullable=False),
        sa.Column('window_end', sa.TIMESTAMP(), nullable=False),
        sa.Column(
            'created_at',
            sa.TIMESTAMP(),
            nullable=False,
            server_default=sa.text('NOW()'),
        ),
        sa.ForeignKeyConstraint(['question_uid'], ['fermi.uid']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(
        'ix_daily_questions_question_date',
        'daily_questions',
        ['question_date'],
        unique=True,
    )
    op.create_index(
        'ix_daily_questions_status',
        'daily_questions',
        ['status'],
    )

    # Create daily_question_answers table
    op.create_table(
        'daily_question_answers',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('daily_question_id', sa.Integer(), nullable=False),
        sa.Column(
            'user_firebase_uid',
            sqlmodel.sql.sqltypes.AutoString(),
            nullable=False,
        ),
        sa.Column('answer_number', sa.Float(), nullable=False),
        sa.Column('answer_unit', sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column('score', sa.Float(), nullable=False),
        sa.Column('started_at', sa.TIMESTAMP(), nullable=False),
        sa.Column('submitted_at', sa.TIMESTAMP(), nullable=False),
        sa.Column('time_taken_s', sa.Float(), nullable=False),
        sa.Column('rank', sa.Integer(), nullable=True),  # Populated after window closes
        sa.ForeignKeyConstraint(['daily_question_id'], ['daily_questions.id']),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint(
            'daily_question_id',
            'user_firebase_uid',
            name='uq_dq_answers_dq_user',
        ),
    )
    op.create_index(
        'ix_daily_question_answers_daily_question_id',
        'daily_question_answers',
        ['daily_question_id'],
    )
    op.create_index(
        'ix_daily_question_answers_user_firebase_uid',
        'daily_question_answers',
        ['user_firebase_uid'],
    )
    op.create_index(
        'ix_daily_question_answers_score',
        'daily_question_answers',
        ['score'],
    )


def downgrade() -> None:
    """Remove Daily Question mode tables and columns."""
    # Drop daily_question_answers table
    op.drop_index(
        'ix_daily_question_answers_score',
        table_name='daily_question_answers',
    )
    op.drop_index(
        'ix_daily_question_answers_user_firebase_uid',
        table_name='daily_question_answers',
    )
    op.drop_index(
        'ix_daily_question_answers_daily_question_id',
        table_name='daily_question_answers',
    )
    op.drop_table('daily_question_answers')

    # Drop daily_questions table
    op.drop_index('ix_daily_questions_status', table_name='daily_questions')
    op.drop_index('ix_daily_questions_question_date', table_name='daily_questions')
    op.drop_table('daily_questions')

    # Remove is_daily_question column from fermi
    op.drop_index('ix_fermi_is_daily_question', table_name='fermi')
    op.drop_column('fermi', 'is_daily_question')

    # Drop enum type
    op.execute('DROP TYPE IF EXISTS dailyquestionstatus')
