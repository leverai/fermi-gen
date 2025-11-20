#!/usr/bin/env python3
"""Script to load seeds from JSON file into the database."""

import asyncio
import json
import os
import sys
from pathlib import Path

from fermi_core.utils import utcnow_naive
from fermi_db import DatabaseClient
from fermi_db.models import Seed
from fermi_db.session import get_session

# Input file for seeds with embeddings
SEEDS_JSON_FILE = Path(__file__).parent / 'seeds.json'


def load_seeds_from_json() -> list[dict]:
    """Load seeds with embeddings from JSON file."""
    if not SEEDS_JSON_FILE.exists():
        print(f'❌ Error: Seeds file not found: {SEEDS_JSON_FILE}')
        print('   Run generate_seeds_json.py first to create the seeds file')
        sys.exit(1)

    try:
        with SEEDS_JSON_FILE.open('r') as f:
            seeds_data = json.load(f)
        print(f'📂 Loaded {len(seeds_data)} seeds from: {SEEDS_JSON_FILE}')
        return seeds_data
    except (OSError, json.JSONDecodeError) as e:
        print(f'❌ Error loading seeds file: {e}')
        sys.exit(1)


async def load_seeds_into_db() -> None:
    """Load seeds from JSON into the database."""
    print('🌱 Loading seeds into database...')

    # Load seeds from JSON
    seeds_data = load_seeds_from_json()

    # Create seed objects
    seeds = []
    for seed_data in seeds_data:
        seed = Seed(
            seed=seed_data['seed'],
            embedding=seed_data['embedding'],
            created_at=utcnow_naive(),
        )
        seeds.append(seed)

    print(f'💾 Inserting {len(seeds)} seeds into database...')

    # Insert seeds using database session
    async for session in get_session():
        db_client = DatabaseClient(session)

        inserted_count = 0
        skipped_count = 0

        for seed in seeds:
            try:
                seed_id = await db_client.seeds.insert_unique_seed(
                    seed,
                    threshold=0.1,  # Lower threshold for seed uniqueness
                )
                if seed_id:
                    inserted_count += 1
                    print(f'✅ Inserted: {seed.seed}')
                else:
                    skipped_count += 1
                    print(f'⏭️  Skipped (similar exists): {seed.seed}')
            except Exception as e:
                print(f"❌ Error inserting '{seed.seed}': {e}")
                skipped_count += 1

        print('\n📈 Summary:')
        print(f'   • Inserted: {inserted_count}')
        print(f'   • Skipped: {skipped_count}')
        print(f'   • Total processed: {len(seeds)}')

        # Show current seed count
        all_seeds = await db_client.seeds.get_all_seeds_light()  # Get all seeds
        print(f'   • Total seeds in database: {len(all_seeds)}')


async def main() -> None:
    """Load seeds from JSON into the database."""
    # Check for required environment variables
    if not os.getenv('DATABASE_URL'):
        print('❌ Error: DATABASE_URL environment variable is required')
        sys.exit(1)

    try:
        await load_seeds_into_db()
        print('\n🎉 Seeds loading completed successfully!')
    except Exception as e:
        print(f'\n💥 Error during seeds loading: {e}')
        sys.exit(1)


if __name__ == '__main__':
    asyncio.run(main())
