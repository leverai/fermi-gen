# Fermi Database Schema

This document describes the complete database schema for the Fermi Game project, including legacy tables, pipeline tables, and production tables.

## Table of Contents

- [Overview](#overview)
- [Table Reference](#table-reference)
  - [Legacy Tables](#legacy-tables)
  - [Pipeline Tables](#pipeline-tables)
  - [Game Tables](#game-tables)
  - [Production Table (fermi)](#tables)
- [Indexes and Constraints](#indexes-and-constraints)
- [Relationships and Foreign Keys](#relationships-and-foreign-keys)
- [Vector Embeddings (pgvector)](#vector-embeddings-pgvector)
- [Design Decisions](#design-decisions)

---

## Overview

The Fermi Game database uses PostgreSQL 17 with the `pgvector` extension for semantic similarity search. The schema is divided into three main categories:

1. **Legacy Tables**: Original question and game management tables (UUID-based)
2. **Pipeline Tables**: ETL pipeline for question generation and deduplication (integer IDs)
3. **Game Tables**: User history, answer events, and voting

**Database Naming Convention:**
- UUID fields: named `uid`
- Integer ID fields: named `id`

---

## Table Reference

### Legacy Tables

#### `fermi_questions_legacy`

Original question table with UUID primary keys. Includes answer, category, and difficulty.

```sql
CREATE TABLE fermi_questions_legacy (
    uid UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    text TEXT NOT NULL,
    number FLOAT NOT NULL,
    unit TEXT,
    category TEXT,
    difficulty TEXT,
    year INTEGER,
    snippet TEXT,
    paragraph TEXT,
    references JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);
```

**Fields:**
- `uid`: Unique identifier (UUID)
- `text`: Question text
- `number`: Correct answer numeric value
- `unit`: Unit of measurement (optional)
- `category`: Question category (e.g., "PLANET_EARTH", "SCIENCE")
- `difficulty`: Question difficulty (e.g., "EASY", "MEDIUM", "HARD")
- `year`: Relevant year for the question
- `snippet`: Short answer explanation
- `paragraph`: Detailed answer explanation
- `references`: JSON array of reference links

#### `user_question_history`

Tracks which users have seen which questions.

```sql
CREATE TABLE user_question_history (
    id SERIAL PRIMARY KEY,
    user_firebase_uid TEXT NOT NULL,
    question_uid UUID NOT NULL,
    seen_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_firebase_uid, question_uid)
);

CREATE INDEX idx_user_history_user ON user_question_history(user_firebase_uid);
CREATE INDEX idx_user_history_question ON user_question_history(question_uid);
```

**Note:** `question_uid` references the `fermi` table (now a regular table, not a materialized view).

#### `answer_events`

User answer submissions and scores.

```sql
CREATE TABLE answer_events (
    id SERIAL PRIMARY KEY,
    user_firebase_uid TEXT NOT NULL,
    question_uid UUID NOT NULL,
    answer_number FLOAT NOT NULL,
    answer_unit TEXT,
    score FLOAT NOT NULL,
    percentile FLOAT,
    game_id TEXT,
    answered_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_answer_events_user ON answer_events(user_firebase_uid);
CREATE INDEX idx_answer_events_question ON answer_events(question_uid);
CREATE INDEX idx_answer_events_game ON answer_events(game_id);
```

**Fields:**
- `user_firebase_uid`: Firebase user ID
- `question_uid`: Question UUID (references `fermi` materialized view)
- `answer_number`: Player's numeric answer
- `answer_unit`: Player's selected unit
- `score`: Score for this answer (0-100)
- `percentile`: Player's percentile rank for this question
- `game_id`: Associated game ID (optional)
- `answered_at`: Timestamp of submission

#### `questions_votes`

User votes (upvotes/downvotes) on questions.

```sql
CREATE TABLE questions_votes (
    id SERIAL PRIMARY KEY,
    user_firebase_uid TEXT NOT NULL,
    question_uid UUID NOT NULL,
    vote INTEGER NOT NULL CHECK (vote IN (-1, 1)),
    voted_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_firebase_uid, question_uid)
);

CREATE INDEX idx_questions_votes_user ON questions_votes(user_firebase_uid);
CREATE INDEX idx_questions_votes_question ON questions_votes(question_uid);
```

**Fields:**
- `vote`: 1 for upvote, -1 for downvote
- Unique constraint ensures one vote per user per question

### Pipeline Tables

These tables support the ETL pipeline for generating, deduplicating, and enriching questions.

#### `seeds`

Unique category seeds for question generation.

```sql
CREATE TABLE seeds (
    id SERIAL PRIMARY KEY,
    seed TEXT NOT NULL UNIQUE,
    embedding vector(1536) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_seeds_embedding ON seeds USING hnsw (embedding vector_cosine_ops);
```

**Fields:**
- `seed`: Topic or category seed (e.g., "renewable energy statistics")
- `embedding`: 1536-dimensional vector from `text-embedding-3-small`
- HNSW index for fast cosine similarity search

#### `raw_questions`

All generated questions before deduplication.

```sql
CREATE TABLE raw_questions (
    id SERIAL PRIMARY KEY,
    seed_id INTEGER NOT NULL REFERENCES seeds(id),
    text TEXT NOT NULL,
    embedding vector(1536) NOT NULL,
    source JSONB,
    dedup_status TEXT NOT NULL CHECK (dedup_status IN ('pending', 'unique', 'duplicate')),
    canonical_question_id INTEGER REFERENCES fermi_questions(id),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_raw_questions_seed ON raw_questions(seed_id);
CREATE INDEX idx_raw_questions_status ON raw_questions(dedup_status);
CREATE INDEX idx_raw_questions_embedding ON raw_questions USING hnsw (embedding vector_cosine_ops);
```

**Fields:**
- `seed_id`: Source seed for this question
- `text`: Question text
- `embedding`: 1536-dimensional vector for similarity search
- `source`: JSONB with generation metadata (model, prompt, etc.)
- `dedup_status`: 'pending', 'unique', or 'duplicate'
- `canonical_question_id`: If duplicate, points to the unique question

#### `fermi_questions`

Semantically unique questions (production table).

```sql
CREATE TABLE fermi_questions (
    id SERIAL PRIMARY KEY,
    seed_id INTEGER REFERENCES seeds(id),
    text TEXT NOT NULL,
    embedding vector(1536) NOT NULL,
    category TEXT,
    difficulty TEXT,
    year INTEGER,
    provider TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_fermi_questions_seed ON fermi_questions(seed_id);
CREATE INDEX idx_fermi_questions_category ON fermi_questions(category);
CREATE INDEX idx_fermi_questions_difficulty ON fermi_questions(difficulty);
CREATE INDEX idx_fermi_questions_embedding ON fermi_questions USING hnsw (embedding vector_cosine_ops);
```

**Fields:**
- `provider`: Source of question ('llm', 'human', 'other')
- `category` and `difficulty`: Enriched by LLM after generation
- New schema with integer primary keys (vs. legacy UUID)

#### `fermi_answers`

Ground truth answers from SerpAPI for questions.

```sql
CREATE TABLE fermi_answers (
    id SERIAL PRIMARY KEY,
    question_id INTEGER UNIQUE NOT NULL REFERENCES fermi_questions(id),
    number FLOAT NOT NULL,
    unit TEXT,
    snippet TEXT,
    paragraph TEXT,
    references JSONB,
    used_ai_overview BOOLEAN DEFAULT FALSE,
    serp_metadata JSONB,
    success BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_fermi_answers_question ON fermi_answers(question_id);
CREATE INDEX idx_fermi_answers_success ON fermi_answers(success);
```

**Fields:**
- `question_id`: Unique reference to question (one answer per question)
- `number`: Correct answer numeric value
- `unit`: Unit of measurement (can be NULL for dimensionless)
- `snippet`: Short answer explanation
- `paragraph`: Detailed explanation
- `references`: JSON array of sources
- `used_ai_overview`: Whether Google AI Overview was used
- `serp_metadata`: Full SerpAPI response metadata
- `success`: TRUE if answer extracted successfully, FALSE for failures

**Important:** Failed attempts are recorded with `success=FALSE` and `number=0` to avoid retry loops.

#### `seeds_usage`

Usage statistics per seed for Thompson Sampling optimization.

```sql
CREATE TABLE seeds_usage (
    id SERIAL PRIMARY KEY,
    seed_id INTEGER NOT NULL REFERENCES seeds(id),
    requested INTEGER NOT NULL,
    generated INTEGER NOT NULL,
    yielded INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_seeds_usage_seed ON seeds_usage(seed_id);
```

**Fields:**
- `requested`: Number of questions requested from this seed
- `generated`: Number of questions generated (before deduplication)
- `yielded`: Number of unique questions after deduplication

**Usage:** Thompson Sampling uses `yielded` (successes) and `requested - yielded` (failures) to compute Beta distribution parameters.

---

### Daily Question Tables

These tables support the Daily Question game mode, where a single question is served to all users daily with synchronized timing and leaderboard functionality.

#### `daily_questions`

Tracks the daily question for each date with window times and status.

```sql
CREATE TYPE dailyquestionstatus AS ENUM ('SCHEDULED', 'ACTIVE', 'CLOSED');

CREATE TABLE daily_questions (
    id SERIAL PRIMARY KEY,
    question_date DATE NOT NULL UNIQUE,
    question_uid UUID NOT NULL REFERENCES fermi(uid),
    status dailyquestionstatus NOT NULL DEFAULT 'SCHEDULED',
    window_start TIMESTAMP NOT NULL,
    window_end TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_daily_questions_question_date ON daily_questions(question_date);
CREATE INDEX idx_daily_questions_status ON daily_questions(status);
```

**Fields:**
- `question_date`: The date for this daily question (unique)
- `question_uid`: Reference to the fermi question
- `status`: Current status (SCHEDULED, ACTIVE, CLOSED)
- `window_start`: When the DQ window opens (UTC)
- `window_end`: When the DQ window closes (UTC, typically 8 PM Central)

**Timing:**
- Window: 8 AM - 8 PM US Central Time
- All timestamps stored in UTC, converted at API layer
- Status transitions: SCHEDULED → ACTIVE (at window_start) → CLOSED (after window_end + grace period)

#### `daily_question_answers`

Stores user answers for daily questions with scores and ranks.

```sql
CREATE TABLE daily_question_answers (
    id SERIAL PRIMARY KEY,
    daily_question_id INTEGER NOT NULL REFERENCES daily_questions(id),
    user_firebase_uid TEXT NOT NULL,
    answer_number FLOAT NOT NULL,
    answer_unit TEXT,
    score FLOAT NOT NULL,
    started_at TIMESTAMP NOT NULL,
    submitted_at TIMESTAMP NOT NULL,
    time_taken_s FLOAT NOT NULL,
    rank INTEGER,
    UNIQUE(daily_question_id, user_firebase_uid)
);

CREATE INDEX idx_daily_question_answers_daily_question_id ON daily_question_answers(daily_question_id);
CREATE INDEX idx_daily_question_answers_user_firebase_uid ON daily_question_answers(user_firebase_uid);
CREATE INDEX idx_daily_question_answers_score ON daily_question_answers(score);
```

**Fields:**
- `daily_question_id`: Reference to the daily question
- `user_firebase_uid`: Firebase user ID
- `answer_number`: User's numeric answer
- `answer_unit`: User's selected unit (optional)
- `score`: Computed score (0-100)
- `started_at`: When user started the question (UTC)
- `submitted_at`: When answer was submitted (UTC)
- `time_taken_s`: Time taken to answer in seconds
- `rank`: User's rank (populated after window closes)

**Constraints:**
- Unique constraint ensures one answer per user per daily question
- `rank` is NULL until the window closes and ranks are computed

**Deadlines:**
- Answer Deadline (AD): `min(started_at + 30s, window_end)`
- AD Grace Period: 5 seconds after AD
- Question Deadline (QD) Grace Period: 20 seconds after window_end

**Key Differences from Party Mode:**
- Answers stored in `daily_question_answers`, NOT `answer_events`
- Does NOT update `user_question_history`
- Questions marked with `is_daily_question=true` in `fermi` table

---

### Game Tables

See Legacy Tables section for `user_question_history`, `answer_events`, and `questions_votes`.

---

## Tables

### `fermi`

Unified table joining successfully answered questions with their answers. This replaces the previous materialized view and is used directly by the API. Includes LLM answers for bot players.

```sql
CREATE TABLE fermi (
    uid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id INTEGER NOT NULL REFERENCES fermi_questions(id),
    text TEXT NOT NULL,
    category TEXT,
    difficulty TEXT,
    year INTEGER,
    number FLOAT NOT NULL,
    unit TEXT,
    snippet TEXT,
    paragraph TEXT,
    references JSONB,
    -- GPT bot answers (smart, competitive)
    gpt_5_1_number FLOAT NOT NULL,
    gpt_5_1_unit TEXT,
    gpt_5_mini_number FLOAT NOT NULL,
    gpt_5_mini_unit TEXT,
    gpt_5_nano_number FLOAT NOT NULL,
    gpt_5_nano_unit TEXT,
    -- Gemini Flash bot answers (casual, high temperature)
    gemini_flash_1_number FLOAT NOT NULL,
    gemini_flash_1_unit TEXT,
    gemini_flash_2_number FLOAT NOT NULL,
    gemini_flash_2_unit TEXT,
    gemini_flash_3_number FLOAT NOT NULL,
    gemini_flash_3_unit TEXT,
    gemini_flash_4_number FLOAT NOT NULL,
    gemini_flash_4_unit TEXT,
    gemini_flash_5_number FLOAT NOT NULL,
    gemini_flash_5_unit TEXT,
    status questionstatus NOT NULL DEFAULT 'PENDING_REVIEW',
    CONSTRAINT fermi_success_chk CHECK (TRUE) -- placeholder for success condition
);

CREATE UNIQUE INDEX idx_fermi_uid ON fermi (uid);
CREATE INDEX idx_fermi_id ON fermi (id);
CREATE INDEX idx_fermi_category ON fermi (category);
CREATE INDEX idx_fermi_difficulty ON fermi (difficulty);
CREATE INDEX idx_fermi_status ON fermi (status);
```

**Key Properties:**
- Regular table (no longer a materialized view)
- Only includes questions with successful answers AND all 8 LLM answers
- Populated by `sync_fermi_table()` after enrichment and LLM answering complete
- UUID generated using `uuid_generate_v5()` based on question ID for stability
- Supports foreign key constraints from other tables

**LLM Answer Columns:**
- **GPT models** (`gpt_5_1_*`, `gpt_5_mini_*`, `gpt_5_nano_*`): Smart competitive bots
- **Gemini Flash** (`gemini_flash_{1-5}_*`): Casual bots with high temperature (1.5) for varied/less accurate answers

**Why a table instead of materialized view?**
- Allows proper foreign key constraints from `user_question_history`, `answer_events`, and `questions_votes`
- Simpler data management - no need for `REFRESH MATERIALIZED VIEW`
- Better referential integrity
- Rows are inserted directly by the ETL pipeline after successful enrichment

---

## Indexes and Constraints

### Primary Keys

All tables use either:
- `SERIAL PRIMARY KEY` (auto-incrementing integers)
- `UUID PRIMARY KEY` (for legacy tables)

### Vector Indexes (HNSW)

Vector similarity search uses HNSW (Hierarchical Navigable Small World) indexes for fast approximate nearest neighbor search:

```sql
CREATE INDEX ON seeds USING hnsw (embedding vector_cosine_ops);
CREATE INDEX ON raw_questions USING hnsw (embedding vector_cosine_ops);
CREATE INDEX ON fermi_questions USING hnsw (embedding vector_cosine_ops);
```

**Performance:**
- Sub-10ms queries for 100k+ vectors
- Cosine distance operator: `<->`
- Trade-off: Approximate (not exact) results

### Unique Constraints

- `seeds.seed`: Ensures no duplicate seeds
- `fermi_answers.question_id`: One answer per question (UPSERT supported)
- `user_question_history(user_firebase_uid, question_uid)`: One entry per user per question
- `questions_votes(user_firebase_uid, question_uid)`: One vote per user per question

### Check Constraints

- `raw_questions.dedup_status`: Must be 'pending', 'unique', or 'duplicate'
- `questions_votes.vote`: Must be -1 or 1

---

## Relationships and Foreign Keys

### Pipeline Relationships

```
seeds (1) ─────< (N) raw_questions
seeds (1) ─────< (N) fermi_questions
seeds (1) ─────< (N) seeds_usage

fermi_questions (1) ─────< (N) fermi_answers
fermi_questions (1) ─────< (N) raw_questions (canonical_question_id)
```

### Game Relationships

```
fermi (table) ─────< (N) user_question_history (FK: question_uid)
fermi (table) ─────< (N) answer_events (FK: question_uid)
fermi (table) ─────< (N) questions_votes (FK: question_uid)
```

**Note:** With `fermi` now a regular table, foreign key constraints can be properly defined to ensure referential integrity.

---

## Vector Embeddings (pgvector)

The database uses the `pgvector` extension for storing and querying vector embeddings.

### Installation

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

### Vector Type

All embeddings use `vector(1536)` type (OpenAI `text-embedding-3-small` dimension).

### Similarity Search

**Cosine Distance:**

```sql
SELECT id, text, embedding <-> $1 AS distance
FROM fermi_questions
ORDER BY distance
LIMIT 10;
```

**Operators:**
- `<->`: Cosine distance (most common)
- `<#>`: Inner product
- `<+>`: L1 distance
- `<=>`: L2 distance

### HNSW Index Parameters

```sql
CREATE INDEX ON fermi_questions
USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);
```

**Parameters:**
- `m`: Maximum connections per layer (default: 16)
- `ef_construction`: Size of candidate list during index build (default: 64)

**Trade-offs:**
- Higher values = better accuracy, slower index build, more memory
- Lower values = faster build, less memory, slightly less accurate

---

## Design Decisions

### Why Two Question Tables?

1. **`fermi_questions_legacy`**: Original UUID-based schema with answers embedded
2. **`fermi_questions`**: New integer ID schema for ETL pipeline

**Rationale:**
- Legacy preserved for backward compatibility
- New schema optimized for pipeline performance
- `fermi` table bridges the gap

### Why Table Instead of Materialized View?

**Benefits:**
- Supports foreign key constraints for referential integrity
- Simpler data management (no manual refresh needed)
- Direct INSERT operations from ETL pipeline
- Better integration with application logic

**Trade-offs:**
- Requires explicit INSERT operations (handled by `sync_fermi_table()`)
- Storage overhead (data duplicated from `fermi_questions` + `fermi_answers`)
- Must manage data consistency at application level

**Migration from Materialized View:**
The `fermi` table replaced the previous materialized view in December 2025. The ETL pipeline now uses `sync_fermi_table()` to insert rows after successful enrichment, eliminating the need for `REFRESH MATERIALIZED VIEW` commands.

### Why Record Failed Answer Attempts?

**Problem:** Without tracking, system would retry failed questions infinitely.

**Solution:**
- Record failures with `success=FALSE` and `number=0`
- Query for unanswered uses LEFT JOIN checking for NULL
- Explicit re-answer requires UPDATE (UPSERT pattern)

**Benefits:**
- Prevents infinite loops
- Tracks failure rate for monitoring
- Explicit retry control

---

## Related Documentation

- [Fermi DB README](../README.md): Usage examples and quick start
- [Migrations Guide](MIGRATIONS.md): Alembic setup and troubleshooting
- [Fermi ETL Architecture](../../apps/fermi-etl/docs/ARCHITECTURE.md): Pipeline details
- [Main README](../../README.md): Project overview
