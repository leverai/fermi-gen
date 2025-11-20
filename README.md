# **The Fermi Game**

This project contains the ETL pipeline, back-end infrastructure, and front-end for The Fermi Game—a trivia experience built around fascinating Fermi questions.

**What is a Fermi Question?**

A Fermi question is a wildly fun brain teaser that asks you to estimate something seemingly unanswerable—like *"How many piano tuners are there in New York City?" or "How many jellybeans would fill a football stadium?"*

The name comes from the Nobel Prize–winning physicist **Enrico Fermi**, renowned for his ability to make remarkably accurate estimates with minimal information.

## Table of Contents
- [Documentation Map](#documentation-map)
- [Project Structure](#project-structure)
- [Project Philosophy](#project-philosophy)
- [Project Components Overview](#project-components-overview)
- [CI/CD](#cicd)
- [Makefile Targets](#makefile-targets)
- [Testing](#testing)
- [Linting](#linting)

## Documentation Map

- **[CI/CD Guide](docs/CICD.md)**: Infrastructure setup and deployment processes
- **[Fermi Frontend](apps/fermi-frontend/)**: Flutter frontend documentation
  - [README](apps/fermi-frontend/README.md): Quick start and running locally
  - [Architecture](apps/fermi-frontend/docs/ARCHITECTURE.md): Component design and implementation
  - [Deployment](apps/fermi-frontend/docs/DEPLOYMENT.md): Build and deployment processes
- **[Fermi API](apps/fermi-api/)**: Backend API documentation
  - [README](apps/fermi-api/README.md): Quick start and API reference
  - [Architecture](apps/fermi-api/docs/ARCHITECTURE.md): Game flow and state management
  - [Deployment](apps/fermi-api/docs/DEPLOYMENT.md): Cloud Run deployment details
- **[Fermi ETL](apps/fermi-etl/)**: ETL pipeline documentation
  - [README](apps/fermi-etl/README.md): Quick start and endpoint reference
  - [Architecture](apps/fermi-etl/docs/ARCHITECTURE.md): Pipeline design and algorithms
  - [Deployment](apps/fermi-etl/docs/DEPLOYMENT.md): Cloud Run deployment details
- **[Fermi DB](packages/fermi-db/)**: Database package documentation
  - [README](packages/fermi-db/README.md): Usage examples and quick start
  - [Schema](packages/fermi-db/docs/SCHEMA.md): Complete table definitions
  - [Migrations](packages/fermi-db/docs/MIGRATIONS.md): Alembic guide

## **Project Structure**

The project is a **workspace** organized into the following directories:
```bash
.
├── apps
│   ├── fermi-api                   # FastAPI back-end services (`auth` and `game`)
│   ├── fermi-etl                   # Unified ETL pipeline (seeds, questions, answers)
│   ├── fermi-frontend              # Game's Flutter app
│   └── sandbox                     # Experimental scripts and prototypes
├── packages
│   ├── fermi-core                  # Shared utilities and models
│   └── fermi-db                    # Data Access Layer to db
├── pyproject.toml
├── README.md
└── uv.lock
```

## **Project Philosophy**

The frontend's primary responsibility is to mirror backend state from Firestore with minimal client-side business logic.

- **Source of truth**: The Firestore game document and its revealed subcollections (`questions`, `answers`, `players_results`). Clients listen to the game doc and to subcollection queries where `revealed == true`.
- **Initiate via API, propagate via Firestore**: Client actions call REST endpoints (e.g., `/game/start`, `/game/answer`, `/game/next_question`, `/game/end`). The backend updates Firestore; the UI reflects those updates in real time. The app does not write Firestore directly for gameplay state.
- **Minimal local state**: Controllers orchestrate view state (loading, timers, navigation) and derive all gameplay state from streams. Avoid duplicating or synthesizing server state on the client.

For complete frontend architecture and design decisions, see **[Frontend Documentation](apps/fermi-frontend/docs/ARCHITECTURE.md)**.

## **Project Components Overview**

The project contains three main components:

*   **[The Fermi ETL Pipeline](apps/fermi-etl/)**: Unified pipeline system for generating seeds, questions, and answers using LLM and SerpAPI. Features Thompson Sampling for seed selection and semantic deduplication using embeddings. See [ETL Architecture](apps/fermi-etl/docs/ARCHITECTURE.md) for details.

*   **[The Fermi Game Backend](apps/fermi-api/)**: FastAPI application providing authentication, game management, and user endpoints. Uses PostgreSQL for persistent data and Firestore for real-time game state. See [API Architecture](apps/fermi-api/docs/ARCHITECTURE.md) for game flow and state management.

*   **[The Fermi Game Frontend](apps/fermi-frontend/)**: Flutter application with real-time, event-driven UI. Features controller-driven architecture, category-based theming, deadline timers, and animated answer reveals. See [Frontend Documentation](apps/fermi-frontend/docs/ARCHITECTURE.md) for complete details.



## **CI/CD**

Both the Fermi ETL and Fermi API applications have complete CI/CD pipelines using GitHub Actions and Google Cloud Run.

**Key Features:**
- **Automated Testing**: Unit and integration tests run on every push to `develop` or `main` branches
- **Automated Deployment**: Auto-deploy to dev on `develop`, auto-deploy to prod on `main`
- **Infrastructure**: Uses Google Cloud Run, Cloud SQL (PostgreSQL 17), Artifact Registry, and Secret Manager
- **Workload Identity Federation**: Secure, keyless authentication from GitHub Actions

**Quick Start:**

```bash
# Local testing
make test-etl-unit              # ETL unit tests
make test-etl-integration       # ETL integration tests
make test-api-unit              # API unit tests
make test-api-integration   # API integration tests

# Deploy to development
git checkout develop
git push origin develop         # Auto-deploys on successful tests

# Deploy to production
git checkout main
git push origin main            # Auto-deploys on successful tests
```

**For complete documentation**, see:
- **[CI/CD Documentation](docs/CICD.md)**: Complete infrastructure setup and troubleshooting
- **[ETL Deployment](apps/fermi-etl/docs/DEPLOYMENT.md)**: ETL-specific deployment details
- **[API Deployment](apps/fermi-api/docs/DEPLOYMENT.md)**: API-specific deployment details

## **Makefile Targets**

The project uses a Makefile to simplify common development tasks. All targets use automatic Docker cleanup via `trap` to ensure containers are removed even on interruption.

### Testing

#### Backend API Tests
```bash
make test-api-integration  # Run API integration tests (requires Docker + emulators)
make test-api-unit         # Run API unit tests (fast, no Docker)
make test-api-endpoints    # Run API endpoint tests
```

#### ETL Pipeline Tests
```bash
make test-etl                  # Run all ETL tests (unit + integration)
make test-etl-unit             # Run ETL unit tests (fast, no Docker)
make test-etl-integration      # Run ETL integration tests (requires Docker + API keys)
```

#### Frotend Tests
```bash
make test-frontend-unit  # Run frontend unit tests
make test-frontend-widget  # Run frontend unit tests
```

### Development & Deployment

```bash
make up                        # Start database and Firebase emulators
make up-api                    # Start db, emulators, and API service
make down                      # Stop and remove all containers + volumes
make migrate                   # Run database migrations
make setup-db                  # Full database setup: migrations + seeding
make run-frontend              # Full stack: start db+emulators+api, run Flutter app
```

### Docker Build Targets

```bash
make build-etl-docker          # Build fermi-etl Docker image
make test-etl-docker           # Build and run fermi-etl Docker image locally with .env
```

### Target Details

#### `test-api-integration`
- Starts PostgreSQL database and Firebase emulators
- Waits for services to be ready
- Runs database migrations
- Executes integration tests against real services
- **Automatic cleanup**: Containers removed on completion or interruption

#### `test-etl-integration`
- Starts PostgreSQL database only (no emulators needed)
- Runs database migrations
- Executes integration tests with **real API calls** (OpenAI, SerpAPI)
- Requires valid API keys in `apps/fermi-etl/.env`
- **Automatic cleanup**: Database container removed on completion or interruption

#### `test-etl-unit`
- Runs unit tests with mocked dependencies
- No Docker required
- Fast execution (~0.1s)
- Tests business logic: Thompson sampling, LRU, deduplication, validation

#### `setup-db`
- Starts database container
- Applies all Alembic migrations
- Loads seed data from `scripts/seeds.json` (if exists)
- Loads questions from `scripts/questions.json` (if exists)

#### `run-frontend`
- Complete development environment setup
- Starts all required services (db, emulators, API)
- Runs database migrations and seeding
- Launches Flutter app with emulator configuration
- Connects to local API at `http://localhost:8000/api/v1`

## **Testing**

### Backend API Tests
- **Location**: `apps/fermi-api/tests/`
- **Documentation**: `apps/fermi-api/tests/README.md`
- **Quick run**: `make test-api-integration`, `make test-api-unit`, `make test-api-endpoints`
- **Coverage**: Integration tests with Firebase emulators, unit tests, API endpoint tests

### ETL Pipeline Tests
- **Location**: `apps/fermi-etl/tests/`
- **Documentation**: `apps/fermi-etl/tests/README.md`
- **Test count**: **49 tests** (45 unit + 4 integration)
- **Quick run**: `make test-etl`, `make test-etl-unit`, `make test-etl-integration`
- **Coverage**: Thompson sampling, LRU selection, semantic deduplication, validation, E2E workflows

### Running API Container

To manually bring up the API service for development:

```bash
# Create apps/fermi-api/.env.compose with container-network values:
# DATABASE_URL=postgresql+asyncpg://postgres:postgres@db:5432/fermi
# FIRESTORE_EMULATOR_HOST=emulators:8080
# FIREBASE_AUTH_EMULATOR_HOST=emulators:9099
# GOOGLE_CLOUD_PROJECT=fermi-local

make up-api
# API available at http://127.0.0.1:8000
curl -i http://127.0.0.1:8000/api/v1/health/health
```

**Notes**:
- The emulators bind to `0.0.0.0` via `apps/fermi-api/firebase.json` so they are reachable from the host and other containers.
- Keep `.env.local` for host runs; use `.env.compose` only for the API container.

### Running Flutter App

To run the game's Flutter app with the full development stack:

```bash
make run-frontend
```

Or manually:
```bash
fvm flutter run -t lib/main.dart \
  --dart-define=USE_EMULATORS=true \
  --dart-define=FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
  --dart-define=FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
  --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

## **Linting**

Run linters for backend code:

```bash
make lint
```
