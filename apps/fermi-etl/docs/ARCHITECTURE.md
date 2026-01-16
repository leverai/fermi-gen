# Fermi ETL Pipeline Architecture

This document describes the architecture, design decisions, and implementation details of the Fermi ETL pipeline.

## Table of Contents

- [Overview](#overview)
- [High-Level Architecture](#high-level-architecture)
- [Pipeline Components](#pipeline-components)
  - [Seed Management](#seed-management)
  - [Question Generation](#question-generation)
  - [Answer Generation](#answer-generation)
  - [Enrichment](#enrichment)
- [Key Features](#key-features)
  - [Thompson Sampling](#thompson-sampling)
  - [Semantic Deduplication](#semantic-deduplication)
  - [Performance Optimization](#performance-optimization)
- [Database Schema](#database-schema)
- [Folder Structure](#folder-structure)
- [Design Principles](#design-principles)
- [Workflows](#workflows)
- [Troubleshooting](#troubleshooting)

---

## Overview

The Fermi ETL Pipeline is a unified FastAPI application that provides a complete workflow for generating high-quality, unique Fermi questions. The system is designed for modularity, cost efficiency, and semantic uniqueness.

The pipeline consolidates:
- **Seed Management**: Creates and manages unique category seeds
- **Question Generation**: Generates questions from seeds using Thompson Sampling or literal insertion
- **Answer Generation**: Produces ground-truth answers via SerpAPI
- **Enrichment**: Classifies questions by category and difficulty using LLM
- **Composite Workflows**: Complete end-to-end pipelines in a single request

---

## High-Level Architecture

The pipeline provides three operational modes:

1. **Seed Management**: Insert and deduplicate topic seeds
2. **Question Generation**: Generate questions from seeds using Thompson Sampling or literal insertion
3. **Answer Generation**: Produce ground-truth answers via SerpAPI
4. **Enrichment**: Classify by category and difficulty

The application exposes RESTful endpoints for each stage, plus composite endpoints that combine multiple stages in a single request.

**Architecture Diagram:**

```
┌─────────────┐
│   Seeds     │ ──────┐
│ (Topics)    │       │
└─────────────┘       │
                      ▼
              ┌───────────────┐
              │ Thompson      │
              │ Sampling or   │ ──────┐
              │ Literal       │       │
              └───────────────┘       │
                                      ▼
                              ┌──────────────┐
                              │  Question    │
                              │  Generation  │ ──────┐
                              │  (LLM)       │       │
                              └──────────────┘       │
                                                     ▼
                                             ┌───────────────┐
                                             │ Semantic      │
                                             │ Deduplication │ ──────┐
                                             │ (Embeddings)  │       │
                                             └───────────────┘       │
                                                                     ▼
                                                             ┌──────────────┐
                                                             │   Answer     │
                                                             │  Generation  │ ──────┐
                                                             │  (SerpAPI)   │       │
                                                             └──────────────┘       │
                                                                                    ▼
                                                                            ┌───────────────┐
                                                                            │  Enrichment   │
                                                                            │  (Category &  │
                                                                            │  Difficulty)  │
                                                                            └───────────────┘
                                                                                    │
                                                                                    ▼
                                                                            ┌───────────────┐
                                                                            │ Materialized  │
                                                                            │     View      │
                                                                            │   (fermi)     │
                                                                            └───────────────┘
```

---

## Pipeline Components

### Seed Management

**Purpose**: Create and maintain a pool of unique topic seeds for question generation.

**Key Operations:**
- `POST /seeds/insert_literal`: Insert user-provided seeds
- Validation and preprocessing (normalization, deduplication)
- Embedding generation using `text-embedding-3-small`
- Semantic uniqueness check using cosine similarity
- Bulk database insertion

**Uniqueness Strategy:**
- Text preprocessing: lowercase, whitespace normalization
- Obvious duplicate removal (exact matches)
- Semantic deduplication using embeddings (threshold: 0.1)
- Efficient vector similarity search with pgvector

### Question Generation

**Purpose**: Generate Fermi questions from seeds using LLM.

**Key Operations:**
- `POST /questions/insert_llm`: LLM-based generation
- `POST /questions/insert_literal`: Direct insertion of user questions

**Seed Selection Modes:**

1. **Thompson Sampling** (`mode: "thompson"`):
   - Balances exploration and exploitation
   - Samples from Beta distribution: `Beta(α=yielded+1, β=failures+1)`
   - Optimizes for high-yield seeds over time

2. **LRU Mode** (`mode: "lru"`):
   - Pure exploration strategy
   - Selects least recently used seeds
   - Ensures all seeds get tried

**Question Flow:**
1. Select N seeds using chosen mode
2. Generate M questions per seed using LLM
3. Store in `raw_questions` table (pre-deduplication)
4. Generate embeddings for each question
5. Check semantic similarity against existing questions
6. Insert unique questions into `fermi_questions`
7. Update seed usage statistics

### Answer Generation

**Purpose**: Extract ground-truth answers for questions using web search.

**Key Operations:**
- `POST /answers/insert_serp`: Answer latest unanswered questions

**Answer Pipeline:**
1. Fetch unanswered questions (efficient LEFT JOIN query)
2. Use LLM to select optimal search location
3. Query SerpAPI with constructed search string
4. Extract answer using LLM (confidence scoring)
5. Store in `fermi_answers` with metadata
6. Record failures to avoid retry loops

**Important Behavior:**
- Failed attempts are recorded with `success=False` and `number=0`
- Failed questions are NOT automatically retried to avoid infinite loops
- Only successful answers (`success=True`) appear in materialized view

### Enrichment

**Purpose**: Classify questions by category and difficulty for better game matching.

**Key Operations:**
- `POST /enrich/category`: Batch category classification
- `POST /enrich/difficulty`: Batch difficulty assessment
- `POST /enrich/join_all`: Refresh materialized view

**Enrichment Process:**
1. Fetch unenriched questions (batch size: configurable)
2. Use LLM for classification (parallel processing)
3. Update questions with category/difficulty
4. Refresh `fermi` materialized view

**Materialized View:**
- Joins `fermi_questions` with `fermi_answers`
- Only includes successfully answered questions
- Used by fermi-api for game question selection
- Refreshed after enrichment operations

---

## Key Features

### Thompson Sampling

**Algorithm:**
- Models each seed's yield as a Beta distribution
- Parameters: α (successes + 1), β (failures + 1)
- Samples from Beta distribution for each seed
- Selects top N seeds by sampled value

**Benefits:**
- Automatically balances exploration vs. exploitation
- High-yield seeds get used more often
- Low-yield seeds still explored occasionally
- Converges to optimal seed selection over time

**Implementation:**

```python
def thompson_sampling(stats: list[SeedStats], n: int) -> list[int]:
    samples = []
    for stat in stats:
        alpha = stat.yielded + 1
        beta = (stat.requested - stat.yielded) + 1
        sample_value = np.random.beta(alpha, beta)
        samples.append((stat.seed_id, sample_value))

    # Sort by sample value and take top N
    samples.sort(key=lambda x: x[1], reverse=True)
    return [seed_id for seed_id, _ in samples[:n]]
```

### Semantic Deduplication

**Purpose**: Prevent duplicate questions based on meaning, not just text.

**Process:**
1. Generate embedding for new question using OpenAI
2. Query pgvector for similar questions (cosine distance)
3. If distance < threshold, mark as duplicate
4. Link duplicate to canonical question

**Thresholds:**
- Seeds: 0.1 (very strict)
- Questions: 0.15 (moderate strictness)

**Benefits:**
- Catches paraphrases and similar questions
- Prevents redundant content
- Maintains question pool quality
- Configurable per-request or via environment

**Technical Implementation:**
- Uses pgvector extension with HNSW index
- Embeddings: 1536-dimensional vectors
- Fast vector similarity search (< 10ms for 100k questions)
- Bulk operations for efficiency

### Performance Optimization

**Concurrent Processing:**
- Batch LLM calls using `asyncio.gather()`
- Parallel embedding generation
- Concurrent SerpAPI queries

**Efficient Database Operations:**
- Bulk inserts using SQLAlchemy Core
- LEFT JOIN queries for unanswered questions
- Lightweight queries (IDs only when full objects not needed)
- Connection pooling with asyncpg

**Caching and Memoization:**
- Seed statistics cached during request
- Embeddings stored for reuse
- Materialized view for fast queries

**Cost Optimization:**
- Configurable batch sizes per request
- Failure tracking to avoid wasted API calls
- Model selection (gpt-4o-mini for generation, gpt-4o for extraction)

---

## Database Schema

### Pipeline Tables

**`seeds`**: Unique category seeds with embeddings

```sql
CREATE TABLE seeds (
    id SERIAL PRIMARY KEY,
    seed TEXT NOT NULL UNIQUE,
    embedding vector(1536) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX ON seeds USING hnsw (embedding vector_cosine_ops);
```

**`raw_questions`**: All generated questions before deduplication

```sql
CREATE TABLE raw_questions (
    id SERIAL PRIMARY KEY,
    seed_id INTEGER REFERENCES seeds(id),
    text TEXT NOT NULL,
    embedding vector(1536) NOT NULL,
    source JSONB,
    dedup_status TEXT CHECK (dedup_status IN ('pending', 'unique', 'duplicate')),
    canonical_question_id INTEGER REFERENCES fermi_questions(id),
    created_at TIMESTAMP DEFAULT NOW()
);
```

**`fermi_questions`**: Semantically unique questions

```sql
CREATE TABLE fermi_questions (
    id SERIAL PRIMARY KEY,
    seed_id INTEGER REFERENCES seeds(id),
    text TEXT NOT NULL,
    embedding vector(1536) NOT NULL,
    category TEXT,
    difficulty TEXT,
    provider TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX ON fermi_questions USING hnsw (embedding vector_cosine_ops);
```

**`fermi_answers`**: Ground truth answers from SerpAPI

```sql
CREATE TABLE fermi_answers (
    id SERIAL PRIMARY KEY,
    question_id INTEGER UNIQUE REFERENCES fermi_questions(id),
    number FLOAT NOT NULL,
    unit TEXT,
    snippet TEXT,
    paragraph TEXT,
    used_ai_overview BOOLEAN,
    serp_metadata JSONB,
    success BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);
```

**`seeds_usage`**: Usage statistics for Thompson Sampling

```sql
CREATE TABLE seeds_usage (
    id SERIAL PRIMARY KEY,
    seed_id INTEGER REFERENCES seeds(id),
    requested INTEGER NOT NULL,
    generated INTEGER NOT NULL,
    yielded INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
```

### Materialized View

**`fermi`**: Unified view joining answered questions with their answers

```sql
CREATE MATERIALIZED VIEW fermi AS
SELECT
    q.id,
    q.uid,
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

CREATE UNIQUE INDEX ON fermi (uid);
```

**Usage:**
- Only includes questions with successful answers
- Excludes failed answer attempts
- Refreshed after enrichment operations
- Used by fermi-api for game question selection

---

## Folder Structure

```
apps/fermi-etl/
├── app/
│   ├── api/              # FastAPI routers (thin layer)
│   │   ├── seeds.py
│   │   ├── questions.py
│   │   ├── answers.py
│   │   ├── enrichment.py
│   │   ├── llm_answers.py
│   │   └── composite.py
│   ├── services/         # Business logic
│   │   ├── seed_service.py
│   │   ├── question_service.py
│   │   ├── answer_service.py
│   │   ├── enrichment_service.py
│   │   ├── llm_answer_service.py
│   │   └── composite_service.py
│   ├── core/             # Shared utilities
│   │   ├── validation.py
│   │   ├── seed_selection.py
│   │   └── deduplication.py
│   ├── schemas/          # Pydantic models
│   │   ├── requests.py
│   │   └── responses.py
│   ├── config.py         # Configuration
│   └── version.py        # Version string
├── tests/
│   ├── unit/             # 45 unit tests
│   └── integration/      # 4 integration tests
├── main.py               # FastAPI app
└── pyproject.toml
```

---

## Design Principles

**Modular Design:**
- Clean separation: API layer → Service layer → Core utilities
- No code duplication across seed/question/answer operations
- Reusable components for common operations

**Async Best Practices:**
- Full async/await with proper session management
- Connection pooling for database access
- Non-blocking I/O for all external calls

**Type Safety:**
- Comprehensive type hints throughout
- Pydantic models for validation
- SQLModel for ORM with type checking
- Service functions take explicit arguments (not config objects) for clarity and testability
- Validation functions raise exceptions instead of returning tuples

**Error Handling:**
- Graceful degradation for API failures
- Detailed logging for debugging
- Failure tracking to prevent retry loops

**Testability:**
- Dependency injection for services
- Mocked external dependencies in tests
- Integration tests with real database

---

## Workflows

### Complete ETL Workflow

1. **Insert Seeds**:
   ```bash
   POST /seeds/insert_literal
   {"seeds": ["Topic A", "Topic B"]}
   ```

2. **Generate, Answer, and Enrich** (all in one):
   ```bash
   POST /insert_llm
   {"num_seeds": 10, "questions_per_seed": 20, "mode": "thompson"}
   ```

3. **Additional Enrichment** (if needed):
   ```bash
   POST /enrich/category {"num_questions": 50}
   POST /enrich/difficulty {"num_questions": 50}
   POST /enrich/join_all
   ```

### Manual Question Insertion

For user-submitted questions:
```bash
POST /insert_literal
{
  "questions": ["Question 1", "Question 2"],
  "provider": "human"
}
```

---

## Troubleshooting

### Low Yield Rate

**Symptom**: Most questions marked as duplicates

**Solutions**:
- Try different seeds with more diversity
- Adjust `QUESTION_SIMILARITY_THRESHOLD` (lower = stricter)
- Check seed quality and specificity
- Review raw questions for patterns

### Answer Generation Failures

**Symptom**: High failure rate for answers

**Causes**:
- SerpAPI limits or quota exceeded
- Invalid or too vague questions
- Low confidence in extracted answers

**Behavior**:
- Failed attempts are recorded in `fermi_answers` with `success=False` and `number=0`
- Failed questions are NOT automatically retried to avoid infinite loops
- Failed questions do NOT appear in the `fermi` materialized view

**Solutions**:
- Check SerpAPI status and quota
- Review failed question logs in the database
- Adjust `CONFIDENCE_THRESHOLD` (lower = more permissive)
- Re-run `POST /answers/insert_serp` to retry failed questions (updates existing records)

### Embedding Generation Slow

**Symptom**: Slow question generation or deduplication

**Solutions**:
- Reduce batch sizes (`questions_per_seed`, `num_questions`)
- Check OpenAI API rate limits
- Verify database connection pooling
- Monitor network latency

### Duplicate Detection Issues

**Symptom**: Duplicates not caught or false positives

**Solutions**:
- Adjust similarity thresholds
- Review embedding quality
- Check pgvector index health
- Verify question preprocessing

---

## Related Documentation

- [Fermi ETL README](../README.md): Quick start and API reference
- [Deployment Guide](DEPLOYMENT.md): Production deployment details
- [Fermi DB Schema](../../packages/fermi-db/docs/SCHEMA.md): Database table definitions
- [Main README](../../README.md): Project overview
