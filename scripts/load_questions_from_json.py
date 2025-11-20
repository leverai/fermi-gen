#!/usr/bin/env python3
"""Script to load questions from JSON file into the database."""

import asyncio
import json
import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from fermi_core.utils import utcnow_naive
from fermi_db import DatabaseClient
from fermi_db.models import FermiQuestion
from fermi_db.session import get_session

# Load environment variables from .env file
# Try root .env first, then apps/fermi-ask-pipeline/.env
load_dotenv(Path(__file__).parent.parent / 'apps/fermi-ask-pipeline/.env')

# Input file for questions with embeddings
QUESTIONS_JSON_FILE = Path(__file__).parent / 'questions.json'

# Configuration
SIMILARITY_THRESHOLD = 0.15  # Cosine distance threshold for deduplication


def load_questions_from_json() -> list[dict]:
    """Load questions with embeddings from JSON file."""
    if not QUESTIONS_JSON_FILE.exists():
        print(f'❌ Error: Questions file not found: {QUESTIONS_JSON_FILE}')
        print('   Run generate_questions_json.py first to create the questions file')
        sys.exit(1)

    try:
        with QUESTIONS_JSON_FILE.open('r') as f:
            questions_data = json.load(f)
        print(f'📂 Loaded {len(questions_data)} questions from: {QUESTIONS_JSON_FILE}')
        return questions_data
    except (OSError, json.JSONDecodeError) as e:
        print(f'❌ Error loading questions file: {e}')
        sys.exit(1)


async def load_questions_into_db() -> None:
    """Load questions from JSON into the database."""
    print('❓ Loading questions into database...')

    # Load questions from JSON
    questions_data = load_questions_from_json()

    # Get threshold from environment
    threshold = float(
        os.getenv('QUESTION_SIMILARITY_THRESHOLD', str(SIMILARITY_THRESHOLD)),
    )
    print(f'🎯 Using similarity threshold: {threshold} (cosine distance)')

    # Insert questions using database session
    async for session in get_session():
        db_client = DatabaseClient(session)

        # First, build a seed text -> seed_id mapping
        print('\n🌱 Fetching seeds from database...')
        seeds = await db_client.seeds.get_all_seeds_light()
        seed_text_to_id = {seed.seed: seed.id for seed in seeds}
        print(f'   Found {len(seeds)} seeds in database')

        inserted_count = 0
        skipped_count = 0
        error_count = 0

        print(f'\n💾 Processing {len(questions_data)} questions...')

        for idx, question_data in enumerate(questions_data, 1):
            seed_text = question_data['seed']

            # Get seed_id from mapping
            seed_id = seed_text_to_id.get(seed_text)
            if not seed_id:
                print(
                    f'   ⚠️  [{idx}/{len(questions_data)}] Skipped (seed not found): '
                    f'"{seed_text}"',
                )
                skipped_count += 1
                continue

            try:
                # Check for similar questions
                similar = await db_client.questions_v2.find_similar_questions(
                    embedding=question_data['embedding'],
                    threshold=threshold,
                )

                if similar:
                    # Found duplicate
                    canonical_question, distance = similar[0]
                    print(
                        f'   ⏭️  [{idx}/{len(questions_data)}] Skipped (duplicate, '
                        f'distance={distance:.3f}): "{question_data["text"][:60]}..."',
                    )
                    skipped_count += 1
                else:
                    # Insert new unique question
                    new_question = FermiQuestion(
                        seed_id=seed_id,
                        text=question_data['text'],
                        embedding=question_data['embedding'],
                        source=question_data['source'],
                        created_at=utcnow_naive(),
                    )
                    session.add(new_question)
                    await session.flush()  # Get the ID
                    await session.commit()

                    print(
                        f'   ✅ [{idx}/{len(questions_data)}] Inserted: '
                        f'"{question_data["text"][:60]}..."',
                    )
                    inserted_count += 1

            except Exception as e:
                print(
                    f'   ❌ [{idx}/{len(questions_data)}] Error inserting '
                    f'"{question_data["text"][:60]}...": {e}',
                )
                error_count += 1
                await session.rollback()

        print('\n📈 Summary:')
        print(f'   • Inserted: {inserted_count}')
        print(f'   • Skipped (duplicates): {skipped_count}')
        print(f'   • Errors: {error_count}')
        print(f'   • Total processed: {len(questions_data)}')

        # Show current question count
        # Get a fresh count from the database
        from sqlmodel import func, select

        statement = select(func.count(FermiQuestion.id))
        result = await session.exec(statement)
        total_questions = result.one()
        print(f'   • Total questions in database: {total_questions}')


async def main() -> None:
    """Load questions from JSON into the database."""
    # Check for required environment variables
    if not os.getenv('DATABASE_URL'):
        print('❌ Error: DATABASE_URL environment variable is required')
        sys.exit(1)

    try:
        await load_questions_into_db()
        print('\n🎉 Questions loading completed successfully!')
    except Exception as e:
        print(f'\n💥 Error during questions loading: {e}')
        import traceback

        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    asyncio.run(main())
