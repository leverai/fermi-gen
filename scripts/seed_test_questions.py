#!/usr/bin/env python3
"""Seed test questions into Postgres for integration tests.

This script loads test data from the new schema format and seeds:
- seeds table
- fermi_questions table
- fermi_answers table
- refreshes the fermi materialized view
"""

import asyncio
import json
import sys
from pathlib import Path

import sqlalchemy as sa
from fermi_db.models import FermiAnswer, FermiQuestion, Seed
from fermi_db.session import get_session


async def seed_test_data(test_data_path: Path) -> None:
    """Seed test data into the database."""
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

        # 4. Refresh the materialized view
        print('🔄 Refreshing fermi materialized view...')
        await session.execute(sa.text('REFRESH MATERIALIZED VIEW fermi'))
        await session.commit()

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

    args = parser.parse_args()

    asyncio.run(seed_test_data(args.file))


if __name__ == '__main__':
    main()
