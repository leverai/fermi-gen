# `fermi-db` Package

Data Access Layer (DAL) for The Fermi Game project, providing a clean, asynchronous, and type-safe interface to PostgreSQL.

## Documentation

- **README** (this file): Usage examples and quick start
- **[Database Schema](docs/SCHEMA.md)**: Complete table and view definitions
- **[Migrations Guide](docs/MIGRATIONS.md)**: Alembic setup and troubleshooting
- **[Main Project README](../../README.md)**: Project overview

## Overview

The `fermi-db` package serves as the dedicated Data Access Layer (DAL) for interacting with the project's PostgreSQL database. It provides a clean, asynchronous, and type-safe interface for all database operations, built on top of `SQLModel`.

This package handles all database interactions for:
- Questions, users, user history, answer analytics
- Question generation pipeline (seeds, raw questions, usage tracking)
- Materialized views for performance

## Design and Architecture

The design of this package is centered around the **Repository Pattern** to ensure a clear separation of concerns and high maintainability.

### Core Components

1.  **`DatabaseClient` (Facade)**
    -   **File**: `fermi_db/dal.py`
    -   **Responsibility**: This is the main entry point to the package. It acts as a facade that accepts an `AsyncSession` and provides access to the specialized repositories. Consumers of this package are responsible for creating and managing the session lifecycle.

2.  **Repositories**
    -   **Location**: `fermi_db/repositories/`
    -   **Responsibility**: Each repository encapsulates the data access logic for a specific domain entity, using `SQLModel` for all queries.
        -   `QuestionRepository` (Legacy): Manages operations on the legacy `fermi_questions_legacy` table.
        -   `QuestionRepositoryV2`: Manages the new `fermi_questions` table with semantic uniqueness checks and batch fetching.
        -   `SeedRepository`: Manages unique category seeds with similarity search and lightweight fetching.
        -   `RawQuestionRepository`: Handles raw (pre-deduplication) question storage and bulk operations.
        -   `SeedsUsageRepository`: Tracks seed usage statistics for Thompson Sampling optimization.
        -   `FermiAnswerRepository`: Manages ground truth answers with UPSERT support for re-answering.
        -   `UserHistoryRepository`: Manages fetching questions based on user history.
        -   `AnswerRepository`: Manages inserting new answer events and computing score quantiles live from `answer_events`.

3.  **SQLModel and Pydantic Models**
    -   **Location**: `fermi_db/models/`
    -   **Responsibility**: Defines the `SQLModel` classes that represent database tables. These models are used for both schema definition (`table=True`) and data transfer. Pydantic models for data shapes that are not tables are defined in `fermi_db/models.py`.

### Important Design Choices

-   **Asynchronous Interface**: The entire DAL is built with `async`/`await` syntax, using `SQLModel`'s async support for non-blocking database operations.
-   **Session Management**: The package does not manage database connections or sessions. It expects an `AsyncSession` to be injected, giving the consumer full control over the transaction lifecycle.
-   **`pgvector` Integration**: Vector similarity search is supported via the `pgvector-sqlalchemy` library, which integrates seamlessly with `SQLModel`.
-   **Bulk Operations**: For performance-critical operations, the package uses `SQLAlchemy` Core constructs like `insert()` for efficient bulk queries.

## Database Schema

**Legacy Tables:**
- `fermi_questions_legacy` - Original UUID-based questions
- `user_question_history` - User question tracking
- `answer_events` - User submissions and scores
- `questions_votes` - User votes on questions

**Pipeline Tables:**
- `seeds` - Category seeds with embeddings (HNSW index)
- `raw_questions` - Generated questions (pre-deduplication)
- `fermi_questions` - Semantically unique questions
- `fermi_answers` - Ground truth answers (UPSERT support)
- `seeds_usage` - Thompson Sampling statistics

**Materialized Views:**
- `fermi` - Unified view of answered questions

For complete schema details, see **[Database Schema Documentation](docs/SCHEMA.md)**.

## Usage

To use the package, obtain an `AsyncSession` from `fermi_db.session` and instantiate the `DatabaseClient` with it.

```python
import asyncio
from fermi_db import DatabaseClient
from fermi_db.session import get_session

async def main():
    # get_session is an async generator that yields a session
    async for session in get_session():
        # Instantiate the client with the session
        db_client = DatabaseClient(session)

        # Access repositories through the client instance
        # Example: Get questions with a specific status
        pending_questions = await db_client.questions.get_questions_by_status(
            status='approved'
        )
        print(f"Found {len(pending_questions)} pending questions.")

        # The session is automatically handled by the generator context

if __name__ == "__main__":
    asyncio.run(main())
```

### Pipeline Repository Examples

```python
from fermi_db import DatabaseClient, SeedLight
from fermi_db.models import Seed, RawQuestion
from fermi_db.session import get_session

async def pipeline_example():
    async for session in get_session():
        db_client = DatabaseClient(session)

        # Insert a unique seed
        seed = Seed(
            seed="renewable energy statistics",
            embedding=[0.1, 0.2, ...],  # 1536-dimensional vector
        )
        seed_id = await db_client.seeds.insert_unique_seed(seed, threshold=0.9)

        # Get Thompson Sampling statistics (includes all seeds for exploration)
        stats = await db_client.seeds_usage.get_aggregated_stats()
        for stat in stats:
            print(f"Seed {stat.seed_id}: α={stat.alpha}, β={stat.beta}")

        # Lightweight seed fetching (no embeddings for performance)
        seed_ids = [1, 2, 3, 4, 5]
        seeds_light = await db_client.seeds.get_seeds_light_by_ids(seed_ids)
        for seed in seeds_light:
            print(f"Seed {seed.id}: {seed.seed}")

        # Insert raw questions (bulk)
        raw_questions = [
            RawQuestion(
                seed_id=seed_id,
                text="How many solar panels are installed in California?",
                embedding=[...],
                source={"model": "gpt-4", "seed": "renewable energy"},
                dedup_status="pending",
            ),
            # ... more questions
        ]
        await db_client.raw_questions.bulk_insert_raw_questions(raw_questions)

        # Record usage for Thompson Sampling
        usage_id = await db_client.seeds_usage.record_usage(
            seed_id=seed_id,
            requested=10,
            generated=8,
        )

        # Update with actual yielded count after deduplication
        await db_client.seeds_usage.update_yielded(usage_id, yielded=6)

        # Check for similar questions
        similar = await db_client.questions_v2.find_similar_questions(
            embedding=[...],
            threshold=0.85,
        )
        if similar:
            question, distance = similar[0]
            print(f"Found similar question (distance={distance})")

        # Fetch questions by IDs
        question_ids = [1, 2, 3]
        questions = await db_client.questions_v2.get_questions_by_ids(question_ids)

        # Insert or update answers (UPSERT)
        from fermi_db.models import FermiAnswer
        answers = [
            FermiAnswer(
                question_id=1,
                number=1.5e6,
                unit="meter ** 2",
                snippet="The area is approximately...",
                used_ai_overview=True,
                serp_metadata={"source": "google_ai_overview"},
            ),
        ]
        answer_ids = await db_client.fermi_answers.bulk_insert_answers(answers)
        print(f"Saved {len(answer_ids)} answers (inserted or updated)")
```

## Migrations (Alembic)

This package owns the database schema and migrations using Alembic with async PostgreSQL.

**Quick Start:**

```bash
# Apply migrations
uv run --package fermi-db alembic -c alembic.ini upgrade head

# Create new migration
uv run --package fermi-db alembic -c alembic.ini revision --autogenerate -m "your change"
```

**Common Issues:**
- pgvector extension not found
- Autogenerate misses tables/columns
- Enum types already exist
- Foreign keys to materialized views

For complete setup, commands, troubleshooting, and recent bug fixes, see **[Migrations Guide](docs/MIGRATIONS.md)**.
