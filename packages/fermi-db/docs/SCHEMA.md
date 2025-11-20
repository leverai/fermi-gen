# Fermi Database Schema

This document describes the complete database schema for the Fermi Game project, including legacy tables, pipeline tables, game tables, and materialized views.

## Table of Contents

- [Overview](#overview)
- [Table Reference](#table-reference)
  - [Legacy Tables](#legacy-tables)
  - [Pipeline Tables](#pipeline-tables)
  - [Game Tables](#game-tables)
- [Materialized Views](#materialized-views)
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

**Note:** `question_uid` references the `fermi` materialized view (not a foreign key due to materialized view limitations).

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

### Game Tables

See Legacy Tables section for `user_question_history`, `answer_events`, and `questions_votes`.

---

## Materialized Views

### `fermi`

Unified view joining successfully answered questions with their answers. This is the primary view used by the API for game question selection.

```sql
CREATE MATERIALIZED VIEW fermi AS
SELECT
    gen_random_uuid() AS uid,  -- Generate deterministic UUID
    q.id,
    q.text,
    q.category,
    q.difficulty,
    q.year,
    a.number,
    a.unit,
    a.snippet,
    a.paragraph,
    a.references
FROM fermi_questions q
INNER JOIN fermi_answers a ON q.id = a.question_id
WHERE a.success = TRUE;

CREATE UNIQUE INDEX idx_fermi_uid ON fermi (uid);
CREATE INDEX idx_fermi_id ON fermi (id);
CREATE INDEX idx_fermi_category ON fermi (category);
CREATE INDEX idx_fermi_difficulty ON fermi (difficulty);
```

**Key Properties:**
- Only includes questions with successful answers (`success=TRUE`)
- Excludes failed answer attempts
- Must be refreshed after enrichment: `REFRESH MATERIALIZED VIEW fermi;`
- UUID generated deterministically using `gen_random_uuid()`

**Why not a regular view?**
- Materialized for performance (no join overhead on each query)
- Unique index on `uid` for foreign key references (not possible with regular views)
- Manually refreshed after bulk operations

**Important:** PostgreSQL doesn't support foreign keys TO materialized views. Tables like `user_question_history`, `answer_events`, and `questions_votes` reference `fermi.uid` but without FK constraints.

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
fermi (materialized view) ─────< (N) user_question_history (no FK)
fermi (materialized view) ─────< (N) answer_events (no FK)
fermi (materialized view) ─────< (N) questions_votes (no FK)
```

**Note:** Foreign keys to materialized views are not supported in PostgreSQL. References to `fermi.uid` are enforced at the application level.

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
- Materialized view bridges the gap

### Why Materialized View Instead of Regular View?

**Benefits:**
- Performance: No join overhead on each query
- Indexing: Unique index on `uid` for efficient lookups
- Consistency: Snapshot of data at refresh time

**Trade-offs:**
- Manual refresh required after changes
- Storage overhead (data duplicated)
- Not real-time (must refresh to see updates)

### Why No Foreign Keys to Materialized View?

**Limitation:** PostgreSQL doesn't support foreign keys TO materialized views.

**Workaround:**
- Application-level enforcement
- Deterministic UUID generation for consistency
- Regular data validation

**Alternative Considered:** Convert to regular table with triggers, but materialized view refresh is simpler and more explicit.

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
