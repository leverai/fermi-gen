# Fermi-ETL Test Suite

Comprehensive test suite for the fermi-etl application, focusing on unit testing of business logic with minimal integration tests.

## Test Philosophy

- **Unit tests** focus on business logic (Thompson sampling, deduplication, validation)
- **Mock all external dependencies** (DB, APIs, embeddings) in unit tests
- **Integration test** covers full E2E workflow with real API calls
- **Keep integration tests minimal** to reduce API costs and runtime

## Directory Structure

```
tests/
├── __init__.py
├── conftest.py                      # Empty (intentionally, following fermi-api pattern)
├── README.md                        # This file
├── unit/
│   ├── __init__.py
│   ├── conftest.py                  # Unit test fixtures (mocks, sample data)
│   ├── test_seed_selection.py      # Thompson sampling and LRU tests
│   ├── test_deduplication.py       # Semantic deduplication tests
│   └── test_validation.py          # Seed and question validation tests
└── integration/
    ├── __init__.py
    ├── conftest.py                  # Integration fixtures (DB, API client)
    └── test_e2e_workflow.py         # End-to-end workflow test
```

### File Descriptions

#### Root Level

- **`conftest.py`**: Intentionally empty. Follows fermi-api pattern where fixtures are scoped to unit or integration directories.
- **`README.md`**: This documentation file.

#### Unit Tests (`unit/`)

- **`conftest.py`**: Provides fixtures for unit tests (mocks, sample data)
- **`test_seed_selection.py`**: Tests Thompson sampling and LRU seed selection algorithms
  - Verifies probabilistic selection behavior
  - Tests edge cases (no seeds, fewer seeds than requested)
  - Validates deterministic behavior with fixed random seeds
- **`test_deduplication.py`**: Tests semantic deduplication logic
  - Verifies unique questions are inserted
  - Ensures duplicates are rejected
  - Tests mixed batches and edge cases
- **`test_validation.py`**: Tests validation utilities for seeds and questions
  - Validates length requirements (raises AssertionError for invalid input)
  - Checks content requirements (must contain letters)
  - Verifies that valid inputs return the validated text

#### Integration Tests (`integration/`)

- **`conftest.py`**: Provides fixtures for integration tests
- **`test_e2e_workflow.py`**: Single comprehensive E2E test with real API calls
  - Tests complete pipeline: seed → generate → answer → enrich
  - Verifies database state at each step
  - Tests composite workflow endpoints
  - **Note**: Requires valid API keys and makes real API calls

## Fixtures

### Unit Test Fixtures (`unit/conftest.py`)

#### `mock_db_client`
Fully mocked `DatabaseClient` with all repository methods.

**Usage:**
```python
def test_something(mock_db_client):
    mock_db_client.seeds.insert_unique_seed.return_value = 1
    # Test code here
```

**Mocked repositories:**
- `seeds`: Seed insertion and retrieval
- `seeds_usage`: Thompson sampling statistics and LRU tracking
- `questions`: Question similarity search and bulk insertion
- `raw_questions`: Pending questions and deduplication status

#### `mock_embeddings`
Patches embedding function to return deterministic vectors instead of calling OpenAI API.

**Usage:**
```python
def test_with_embeddings(mock_embeddings):
    # Embedding calls are now mocked
    # Returns deterministic vectors based on text hash
```

**Patches:**
- `app.core.deduplication.aget_embeddings_clean_3small`
- `app.services.seed_service.aget_embeddings_clean_3small`
- `app.services.question_service.aget_embeddings_clean_3small`

#### `sample_seed_stats`
Sample seed statistics for Thompson/LRU selection tests.

**Returns:** List of `SeedStat` objects with various alpha/beta values:
- High success seed (alpha=10, beta=2)
- Medium success seed (alpha=5, beta=5)
- Low success seed (alpha=2, beta=10)
- New seed with uniform prior (alpha=1, beta=1)

#### `sample_raw_questions`
Sample `RawQuestion` objects for deduplication tests.

**Returns:** List of 3 `RawQuestion` objects with embeddings and metadata.

#### `sample_fermi_questions`
Sample `FermiQuestion` objects for similarity checks.

**Returns:** List of 2 `FermiQuestion` objects representing existing questions.

### Integration Test Fixtures (`integration/conftest.py`)

#### `_load_env` (autouse, session-scoped)
Loads `.env` configuration from fermi-etl directory.

**Environment variables:**
- `DATABASE_URL`: PostgreSQL connection URL
- `OPENAI_API_KEY`: OpenAI API key for question generation
- `SERP_API_KEY`: SerpAPI key for answer extraction
- Model configurations and thresholds

#### `_verify_database_reachable` (autouse, session-scoped)
Ensures PostgreSQL database is available before tests run.

**Fails fast with clear error message if:**
- `DATABASE_URL` is not set
- Database is not using asyncpg driver
- Database is not reachable

#### `_reset_db_before_each_test` (autouse, function-scoped)
Truncates pipeline tables between tests for isolation.

**Truncated tables:**
- `seeds`
- `seeds_usage`
- `raw_questions`
- `fermi_questions`
- `fermi_answers`

**Preserved tables:**
- `alembic_version` (schema version)

#### `api_client` (session-scoped)
`TestClient` instance for making API requests to fermi-etl app.

**Usage:**
```python
def test_endpoint(api_client):
    response = api_client.post("/seeds/insert_literal", json={"seeds": ["AI"]})
    assert response.status_code == 200
```

**Features:**
- Automatically sets working directory to fermi-etl
- Enables lifespan events (startup/shutdown)
- Synchronous interface (no async needed)

#### `_dispose_engine_at_end` (autouse, session-scoped)
Disposes database engine at end of test session to avoid hanging connections.

## Running Tests

### Unit Tests Only (Fast, No Docker)

```bash
make test-etl-unit
```

**Details:**
- Runs all tests in `tests/unit/`
- No external dependencies required
- Typically completes in seconds
- Safe to run frequently during development

**Direct pytest:**
```bash
uv run --package fermi-etl pytest apps/fermi-etl/tests/unit/ -v
```

### Integration Tests Only (Requires Docker & API Keys)

```bash
make test-etl-integration
```

**Details:**
- Starts PostgreSQL database via Docker Compose
- Runs database migrations
- Executes tests in `tests/integration/`
- **Makes real API calls** (OpenAI, SerpAPI)
- Cleans up Docker containers after tests

**Requirements:**
- Docker and Docker Compose installed
- Valid API keys in `.env`
- Internet connection for API calls

**Direct pytest:**
```bash
# Start database first
docker compose up -d db
export DATABASE_URL=postgresql+asyncpg://postgres:postgres@127.0.0.1:5433/fermi-db
uv run --package fermi-db alembic -c alembic.ini upgrade head
uv run --package fermi-etl pytest apps/fermi-etl/tests/integration/ -v
```

### All Tests

```bash
make test-etl
```

Runs unit tests first, then integration tests. Stops on first failure.

### Test-Specific Options

Run a single test file:
```bash
uv run --package fermi-etl pytest apps/fermi-etl/tests/unit/test_validation.py -v
```

Run a specific test:
```bash
uv run --package fermi-etl pytest apps/fermi-etl/tests/unit/test_validation.py::test_validate_seed_valid -v
```

Show print statements:
```bash
uv run --package fermi-etl pytest apps/fermi-etl/tests/unit/ -v -s
```

## Contributing Guidelines

### Adding New Tests

1. **Choose the right directory:**
   - Unit tests → `tests/unit/`
   - Integration tests → `tests/integration/`

2. **Follow naming conventions:**
   - Test files: `test_*.py`
   - Test functions: `test_*`
   - Test classes: `Test*`

3. **Write descriptive names:**
   - Good: `test_thompson_sampling_selects_high_success_seeds_more_often`
   - Bad: `test_thompson_1`

4. **Add docstrings:**
   ```python
   def test_something():
       """Test that something does what it should.

       Verifies specific behavior and edge cases.
       """
   ```

5. **Update this README:**
   - Add new test files to Directory Structure
   - Document any new fixtures in Fixtures section
   - Update running instructions if needed

### Adding New Fixtures

1. **Add to appropriate conftest.py:**
   - Unit fixtures → `tests/unit/conftest.py`
   - Integration fixtures → `tests/integration/conftest.py`

2. **Document in this README:**
   ```markdown
   #### `new_fixture_name`
   Brief description of what the fixture provides.

   **Usage:**
   ```python
   def test_something(new_fixture_name):
       # Example usage
   ```

   **Returns:** Description of return value
   ```

3. **Follow fixture best practices:**
   - Use `@pytest.fixture` for sync fixtures
   - Use `@pytest_asyncio.fixture` for async fixtures
   - Set appropriate scope (`function`, `module`, `session`)
   - Use `autouse=True` only when necessary

### Before Submitting

Run the test checklist:

- [ ] All tests have docstrings
- [ ] Async functions use `@pytest.mark.asyncio`
- [ ] Async fixtures use `@pytest_asyncio.fixture`
- [ ] All mocks are properly configured
- [ ] Thompson sampling tests account for randomness
- [ ] Database fixtures clean up properly
- [ ] Integration tests use real APIs (not mocked)
- [ ] Unit tests mock all external dependencies
- [ ] Test names are descriptive
- [ ] README.md is updated with new fixtures/tests
- [ ] All tests pass locally: `make test-etl`

## Common Issues and Solutions

### Issue: `RuntimeError: Task attached to different loop`
**Cause:** Reusing DB engine/connection across tests

**Solution:** Create fresh engine per test or use proper async fixtures

### Issue: `TypeError: object is not awaitable`
**Cause:** Forgot `await` or mocked async function with sync mock

**Solution:** Add `await` or use `AsyncMock`

### Issue: `RuntimeError: No running event loop`
**Cause:** Calling async function without event loop

**Solution:** Use `@pytest.mark.asyncio` or `asyncio.run()`

### Issue: `ImportError: cannot import name 'app'`
**Cause:** Wrong working directory or PYTHONPATH

**Solution:** Set working directory to fermi-etl root in fixture

### Issue: Tests pass locally but fail in CI
**Cause:** Missing environment variables or database

**Solution:** Ensure CI has DATABASE_URL set and database service running

## Test Coverage Goals

- **Unit tests:** >80% coverage of business logic
- **Integration tests:** Cover critical E2E paths
- **Focus areas:**
  - Seed selection algorithms (Thompson, LRU)
  - Deduplication logic
  - Validation rules
  - API endpoint behavior

## Bugs Discovered and Fixed During Testing

### 1. Config Loading Redundancy
**Issue**: `config.py` called `load_dotenv()` in `get_config()`, making it impossible to use different env files for tests.

**Fix**: Removed explicit `load_dotenv()` call. Pydantic-settings automatically loads from `env_file` in Config class. Test fixtures now load `.env` explicitly before app import.

**Lesson**: Let pydantic-settings handle env file loading. Only override in fixtures when needed.

### 2. Import Error: FermiQuestionLegacy
**Issue**: `question_votes_repository.py` referenced `FermiQuestionLegacy` which didn't exist.

**Fix**: Changed to `Fermi` model.

**Lesson**: Ensure model refactoring updates all imports across the codebase.

### 3. Migration Foreign Key Order
**Issue**: `raw_questions` table created before `fermi_questions`, but had FK constraint to it.

**Fix**: Reordered table creation - `fermi_questions` before `raw_questions`.

**Lesson**: Tables must be created before other tables that reference them via FK.

### 4. Repository Row Object Bug
**Issue**: `get_latest_unanswered_questions()` returned `Row` objects instead of extracting integer IDs, causing `'Row' object cannot be interpreted as an integer` errors.

**Fix**: Changed from `result.all()` list comprehension to `[row[0] for row in rows]` to extract values.

**Lesson**: When selecting single columns, `result.all()` returns Row objects, not raw values. Always extract with indexing.

### 5. Test Schema Mismatch
**Issue**: Test queried for `confidence` column that doesn't exist in `fermi_answers` table.

**Fix**: Updated test to query actual schema fields (no confidence, added snippet).

**Lesson**: Always verify schema against actual models before writing DB queries in tests.

### 6. Materialized View FK Constraints
**Issue**: Cannot create FK constraints to materialized views in PostgreSQL.

**Fix**: Removed FK constraints, changed to deterministic UUIDs using `uuid_generate_v5()`.

**Lesson**: Materialized views can't have FKs pointing to them. Use deterministic keys or application-level validation.

## Future Contributors

When adding functionality to fermi-etl:

1. **Write unit tests first** for business logic
2. **Add integration tests sparingly** (they're expensive)
3. **Mock external dependencies** in unit tests
4. **Keep this README up to date** with new fixtures and tests
5. **Run full test suite** before submitting: `make test-etl`

Thank you for contributing to fermi-etl! 🚀
