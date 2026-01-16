#!/usr/bin/env python3
"""Seed test questions into Postgres for integration tests.

This script loads test data from the new schema format and seeds:
- seeds table
- fermi_questions table
- fermi_answers table
- llm_answers table
- syncs the fermi table (with status=APPROVED for tests)
"""

import asyncio
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

import sqlalchemy as sa
from fermi_db.models import (
    DailyQuestion,
    DailyQuestionAnswer,
    FermiAnswer,
    FermiQuestion,
    LLMAnswer,
    Seed,
)
from fermi_db.schemas import DailyQuestionStatus
from fermi_db.session import get_session

# Central Time zone for DQ window calculation
CT = ZoneInfo('America/Chicago')


async def seed_test_data(test_data_path: Path, create_dq_history: bool = True) -> None:
    """Seed test data into the database.

    Args:
        test_data_path: Path to the test data JSON file.
        create_dq_history: If True, creates past 7 days of DQ entries with mock answers.
                          If False, skips DQ history creation for clean slate testing.
    """
    if not test_data_path.exists():
        print(f'❌ Test data file not found: {test_data_path}', file=sys.stderr)
        sys.exit(1)

    # Load test data
    with test_data_path.open() as f:
        test_data = json.load(f)

    print(
        f'📂 Loaded test data: {len(test_data["seeds"])} seeds, '
        f'{len(test_data["questions"])} questions, '
        f'{len(test_data["answers"])} answers',
    )

    # Seed the database
    async for session in get_session():
        # 1. Insert seeds
        print('🌱 Inserting seeds...')
        seeds = [
            Seed(
                id=s['id'],
                seed=s['seed'],
                embedding=s['embedding'],
            )
            for s in test_data['seeds']
        ]
        for seed in seeds:
            session.add(seed)
        await session.flush()

        # 2. Insert questions
        print('❓ Inserting questions...')
        questions = [
            FermiQuestion(
                id=q['id'],
                seed_id=q['seed_id'],
                text=q['text'],
                source=q['source'],
                category=q['category'],
                difficulty=q['difficulty'],
                embedding=q['embedding'],
            )
            for q in test_data['questions']
        ]
        for question in questions:
            session.add(question)
        await session.flush()

        # 3. Insert answers
        print('💡 Inserting answers...')
        answers = [
            FermiAnswer(
                question_id=a['question_id'],
                number=a['number'],
                unit=a['unit'],
                snippet=a['snippet'],
                used_ai_overview=a['used_ai_overview'],
                success=a['success'],
                serp_metadata=a['serp_metadata'],
            )
            for a in test_data['answers']
        ]
        for answer in answers:
            session.add(answer)
        await session.commit()

        # 4. Insert LLM answers
        if 'llm_answers' in test_data:
            print('🤖 Inserting LLM answers...')
            llm_answers = [
                LLMAnswer(
                    question_id=la['question_id'],
                    model=la['model'],
                    number=la['number'],
                    unit=la['unit'],
                )
                for la in test_data['llm_answers']
            ]
            for llm_answer in llm_answers:
                session.add(llm_answer)
            await session.commit()
        else:
            print('⚠️  No llm_answers in test data, skipping...')

        # 5. Sync fermi table (new approach - replaces MV refresh)
        print('🔄 Syncing fermi table...')
        await session.execute(
            sa.text("""
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
                gemini_flash_1_number,
                gemini_flash_1_unit,
                gemini_flash_2_number,
                gemini_flash_2_unit,
                gemini_flash_3_number,
                gemini_flash_3_unit,
                gemini_flash_4_number,
                gemini_flash_4_unit,
                gemini_flash_5_number,
                gemini_flash_5_unit,
                status,
                is_daily_question
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
                    la_nano.created_at,
                    la_gemini1.created_at,
                    la_gemini2.created_at,
                    la_gemini3.created_at,
                    la_gemini4.created_at,
                    la_gemini5.created_at
                ) AS updated_at,
                la_51.number AS gpt_5_1_number,
                la_51.unit AS gpt_5_1_unit,
                la_mini.number AS gpt_5_mini_number,
                la_mini.unit AS gpt_5_mini_unit,
                la_nano.number AS gpt_5_nano_number,
                la_nano.unit AS gpt_5_nano_unit,
                la_gemini1.number AS gemini_flash_1_number,
                la_gemini1.unit AS gemini_flash_1_unit,
                la_gemini2.number AS gemini_flash_2_number,
                la_gemini2.unit AS gemini_flash_2_unit,
                la_gemini3.number AS gemini_flash_3_number,
                la_gemini3.unit AS gemini_flash_3_unit,
                la_gemini4.number AS gemini_flash_4_number,
                la_gemini4.unit AS gemini_flash_4_unit,
                la_gemini5.number AS gemini_flash_5_number,
                la_gemini5.unit AS gemini_flash_5_unit,
                'APPROVED' AS status,  -- Test data is pre-approved
                false AS is_daily_question  -- Default: not a daily question
            FROM fermi_answers fa
            INNER JOIN fermi_questions fq ON fa.question_id = fq.id
            INNER JOIN llm_answers la_51 ON fq.id = la_51.question_id
                AND la_51.model = 'gpt-5.1'
            INNER JOIN llm_answers la_mini ON fq.id = la_mini.question_id
                AND la_mini.model = 'gpt-5-mini'
            INNER JOIN llm_answers la_nano ON fq.id = la_nano.question_id
                AND la_nano.model = 'gpt-5-nano'
            INNER JOIN llm_answers la_gemini1 ON fq.id = la_gemini1.question_id
                AND la_gemini1.model = 'gemini-1.5-flash-001'
            INNER JOIN llm_answers la_gemini2 ON fq.id = la_gemini2.question_id
                AND la_gemini2.model = 'gemini-1.5-flash-002'
            INNER JOIN llm_answers la_gemini3 ON fq.id = la_gemini3.question_id
                AND la_gemini3.model = 'gemini-1.5-flash-003'
            INNER JOIN llm_answers la_gemini4 ON fq.id = la_gemini4.question_id
                AND la_gemini4.model = 'gemini-1.5-flash-004'
            INNER JOIN llm_answers la_gemini5 ON fq.id = la_gemini5.question_id
                AND la_gemini5.model = 'gemini-1.5-flash-005'
            WHERE fa.success = true
            ON CONFLICT (question_id) DO NOTHING
            """),
        )
        await session.commit()

        # 6. Mark first 10 questions as daily questions (gives us pool for today + 7 past days)
        print('📅 Marking questions 1-10 as daily question candidates...')
        await session.execute(
            sa.text("""
            UPDATE fermi
            SET is_daily_question = true
            WHERE question_id IN (1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
            """),
        )
        await session.commit()

        # 7. Get the fermi UIDs for the DQ-flagged questions
        print('🔍 Fetching DQ-flagged fermi UIDs...')
        dq_fermi_result = await session.execute(
            sa.text("""
            SELECT uid, question_id FROM fermi
            WHERE is_daily_question = true
            ORDER BY question_id ASC
            """),
        )
        dq_fermi_rows = dq_fermi_result.fetchall()

        if create_dq_history:
            if len(dq_fermi_rows) < 8:
                print(
                    f'⚠️  Only {len(dq_fermi_rows)} DQ questions found, need at least 8'
                )
                print('✅ Test data seeded successfully (without full DQ history)')
                break

            # 8. Create daily_questions entries: today (ACTIVE) + past 7 days (CLOSED)
            print('📅 Creating daily_questions entries...')
            today_ct = datetime.now(CT).replace(
                hour=0, minute=0, second=0, microsecond=0
            )

            dq_entries = []
            for day_offset in range(8):  # 0=today, 1-7=past days
                day_date = today_ct - timedelta(days=day_offset)
                question_uid = dq_fermi_rows[day_offset][0]  # uid column

                # Window: midnight CT to 8 PM CT
                window_start_ct = day_date.replace(
                    hour=0, minute=0, second=0, microsecond=0
                )
                window_end_ct = day_date.replace(
                    hour=20, minute=0, second=0, microsecond=0
                )

                # Convert to UTC naive
                window_start_utc = window_start_ct.astimezone(timezone.utc).replace(
                    tzinfo=None
                )
                window_end_utc = window_end_ct.astimezone(timezone.utc).replace(
                    tzinfo=None
                )

                # Today is ACTIVE, past days are CLOSED
                status = (
                    DailyQuestionStatus.ACTIVE
                    if day_offset == 0
                    else DailyQuestionStatus.CLOSED
                )

                dq = DailyQuestion(
                    question_date=day_date.date(),
                    question_uid=question_uid,
                    status=status,
                    window_start=window_start_utc,
                    window_end=window_end_utc,
                )
                dq_entries.append(dq)
                session.add(dq)

            await session.commit()

            # Refresh to get IDs
            for dq in dq_entries:
                await session.refresh(dq)

            print(f'  Created {len(dq_entries)} daily_questions entries')
            print(
                f'    - Today ({dq_entries[0].question_date}): {dq_entries[0].status}'
            )
            print(
                f'    - Yesterday ({dq_entries[1].question_date}): {dq_entries[1].status}'
            )

            # 9. Create mock daily_question_answers for past DQs (simulate test user history)
            print('📝 Creating mock daily_question_answers for past DQs...')
            mock_user_uid = 'test-user-local-dev'

            for i, dq in enumerate(
                dq_entries[1:], start=1
            ):  # Skip today, start from yesterday
                # Random-ish score and rank for variety
                score = 85.0 + (i * 2) % 15  # Scores between 85-100
                rank = i  # Rank 1-7

                # Submitted around noon CT
                submitted_ct = (today_ct - timedelta(days=i)).replace(
                    hour=12, minute=30
                )
                submitted_utc = submitted_ct.astimezone(timezone.utc).replace(
                    tzinfo=None
                )
                started_utc = submitted_utc - timedelta(
                    seconds=15
                )  # Started 15s before

                answer = DailyQuestionAnswer(
                    daily_question_id=dq.id,
                    user_firebase_uid=mock_user_uid,
                    answer_number=42.0,  # Mock answer
                    answer_unit=None,
                    score=score,
                    started_at=started_utc,
                    submitted_at=submitted_utc,
                    time_taken_s=15.0,
                    rank=rank,
                )
                session.add(answer)

            await session.commit()
            print(f'  Created {len(dq_entries) - 1} mock answers for history testing')
        else:
            print('⏭️  Skipping DQ history creation (--no-dq-history)')

        print('✅ Test data seeded successfully')

        break  # Exit after first session


def main() -> None:
    """Seed test questions for integration tests."""
    import argparse

    parser = argparse.ArgumentParser(
        description='Seed test questions for integration tests',
    )
    parser.add_argument(
        '--file',
        type=Path,
        required=True,
        help='Path to test data JSON file',
    )
    parser.add_argument(
        '--no-dq-history',
        action='store_true',
        help='Skip creating past DQ history entries (for clean slate testing)',
    )

    args = parser.parse_args()

    asyncio.run(seed_test_data(args.file, create_dq_history=not args.no_dq_history))


if __name__ == '__main__':
    main()
