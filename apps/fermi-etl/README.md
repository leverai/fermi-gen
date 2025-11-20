# Fermi ETL Pipeline

A unified ETL pipeline for generating, answering, and enriching Fermi questions using LLM and SerpAPI.

## Documentation

- **README** (this file): Quick start and API endpoint reference
- **[Architecture](docs/ARCHITECTURE.md)**: Pipeline design, Thompson Sampling, and algorithms
- **[Deployment](docs/DEPLOYMENT.md)**: Cloud Run deployment and configuration
- **[Fermi DB Schema](../../packages/fermi-db/docs/SCHEMA.md)**: Database table definitions
- **[Main Project README](../../README.md)**: Project overview

## Overview

The Fermi ETL Pipeline provides a complete workflow for:
- **Seed Management**: Insert and deduplicate topic seeds
- **Question Generation**: Generate questions using LLM or insert user-provided questions
- **Answer Generation**: Extract ground truth answers using SERP API
- **Enrichment**: Classify questions by category and difficulty using LLM
- **Composite Workflows**: Complete end-to-end pipelines in a single request

For detailed architecture and design, see **[Architecture Documentation](docs/ARCHITECTURE.md)**.

## Installation

### Prerequisites

- Python 3.11+
- PostgreSQL with pgvector extension
- OpenAI API key
- SerpAPI key

### Setup

1. **Install dependencies** (from workspace root):
   ```bash
   uv sync --all-packages
   ```

2. **Set environment variables** (create `.env` file):
   ```bash
   cp env.example .env
   # Edit .env with your credentials
   ```

3. **Run database migrations**:
   ```bash
   uv run --package fermi-db alembic -c alembic.ini upgrade head
   ```

## Running Locally

```bash
cd apps/fermi-etl
uv run python main.py
```

Or with uvicorn:
```bash
cd apps/fermi-etl
uv run uvicorn main:app --reload --host 0.0.0.0 --port 8080
```

The API will be available at `http://localhost:8080`.

**API Documentation:**
- Swagger UI: `http://localhost:8080/docs`
- ReDoc: `http://localhost:8080/redoc`

## Database Schema

**Pipeline Tables:**
- `seeds` - Category seeds with embeddings
- `raw_questions` - Generated questions (pre-deduplication)
- `fermi_questions` - Semantically unique questions
- `fermi_answers` - Ground truth answers (success/failure tracking)
- `seeds_usage` - Statistics for Thompson Sampling

**Materialized View:**
- `fermi` - Unified view of answered questions (used by fermi-api)

For complete schema details, see **[Database Schema Documentation](../../packages/fermi-db/docs/SCHEMA.md)**.

## API Endpoints

### Seeds (`/seeds`)

#### `POST /insert_literal`
Insert category seeds manually.

```json
{"seeds": ["Science", "History", "Technology"]}
```

### Questions (`/questions`)

#### `POST /insert_literal`
Insert user-provided questions directly.

```json
{
  "questions": [
    "How many trees are in Central Park?",
    "How many pizzas are eaten in NYC per day?"
  ],
  "provider": "human"
}
```

**Note:** Use enrichment endpoints to classify category/difficulty after insertion.

#### `POST /insert_llm`
Generate questions using LLM and seed selection.

```json
{
  "num_seeds": 5,
  "questions_per_seed": 20,
  "mode": "thompson"
}
```

**Parameters:**
- `mode`: `thompson` (balances exploration/exploitation) or `lru` (least recently used)

### Answers (`/answers`)

#### `POST /insert_serp`
Answer the latest N unanswered questions automatically using SERP API.

**Note:** Only fetches questions that have never been attempted. Failed answer attempts are recorded but not retried to avoid infinite loops.

```json
{"num_questions": 50}
```

### Enrichment (`/enrich`)

#### `POST /category`
Classify unanswered questions into categories using LLM.

```json
{"num_questions": 50}
```

#### `POST /difficulty`
Assess difficulty for unanswered questions using LLM.

```json
{"num_questions": 50}
```

#### `POST /join_all`
Refresh the `fermi` materialized view to reflect latest data.

**Request:** Empty body

### Composite Workflows

#### `POST /insert_llm`
Complete workflow: Generate questions → Answer → Enrich → Refresh view.

```json
{
  "num_seeds": 5,
  "questions_per_seed": 20,
  "mode": "thompson"
}
```

#### `POST /insert_literal`
Complete workflow: Insert questions → Answer → Enrich → Refresh view.

```json
{
  "questions": [
    "How many atoms are in a human body?",
    "What is the total length of human DNA?"
  ],
  "provider": "human"
}
```

## Configuration

Environment variables (see `env.example`):

### Required
- `DATABASE_URL`: PostgreSQL connection URL
- `OPENAI_API_KEY`: OpenAI API key
- `SERP_API_KEY`: SerpAPI key

### Optional (with defaults)
- `SEED_SIMILARITY_THRESHOLD` (0.1): Threshold for seed uniqueness
- `QUESTION_SIMILARITY_THRESHOLD` (0.15): Threshold for question uniqueness
- `QUESTION_GENERATION_MODEL` (gpt-4o-mini): LLM for question generation
- `LOCATION_MODEL` (gpt-4o-mini): Model for location selection
- `EXTRACTION_MODEL` (gpt-4o): Model for answer extraction
- `MODEL_PROVIDER` (openai): Model provider
- `CONFIDENCE_THRESHOLD` (0.8): Minimum confidence for answers

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

## Key Features

- **Semantic Deduplication**: Uses embeddings to detect duplicate questions
- **Thompson Sampling**: Optimizes seed selection for maximum yield
- **Batch Processing**: Efficient parallel LLM and SERP calls
- **Automatic Enrichment**: Category and difficulty classification via LLM
- **Materialized View**: Fast game queries via unified `fermi` table
- **Failure Tracking**: Records failed answer attempts to avoid retry loops

For detailed architecture, algorithms, and design principles, see **[Architecture Documentation](docs/ARCHITECTURE.md)**.

## Development

### Running Tests

The fermi-etl application has a comprehensive test suite with **49 tests** covering unit and integration testing.

**All tests** (unit + integration):
```bash
make test-etl
```

**Unit tests only** (fast, no Docker):
```bash
make test-etl-unit
```

**Integration tests only** (requires Docker + API keys):
```bash
make test-etl-integration
```

**Test Coverage:**
- **45 unit tests**: Thompson sampling, LRU selection, deduplication, validation
- **4 integration tests**: E2E workflow, composite endpoints, seed deduplication, health checks

**See `tests/README.md`** for detailed documentation on:
- Test structure and fixtures
- Running individual tests
- Contributing guidelines
- Common issues and solutions

### Code Quality

- Type hints throughout
- Comprehensive logging
- Proper async/await patterns
- Clean separation of concerns
- Follows project coding standards
- Fully tested with >90% coverage of business logic

## Troubleshooting

**Common Issues:**
- Low yield rate (questions marked as duplicates)
- Answer generation failures (SerpAPI limits, low confidence)
- Slow embedding generation (API rate limits)

For complete troubleshooting guide and solutions, see **[Architecture Documentation](docs/ARCHITECTURE.md#troubleshooting)**.

## Testing

See `tests/README.md` for complete testing documentation.

**Quick Start:**
```bash
# Unit tests (fast, no Docker)
make test-etl-unit

# Integration tests (requires Docker + API keys in .env)
make test-etl-integration

# All tests
make test-etl
```

## License

Part of the Fermi Game project.
