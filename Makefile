SHELL := /bin/bash

# ============================================================================
# Common Targets
# ============================================================================

.PHONY: migrate
migrate:
	uv run alembic -c alembic.ini upgrade head

.PHONY: setup-db
setup-db:
	@echo "Starting database and running migrations..."
	@docker compose up -d db && \
	until docker compose exec -T db pg_isready -U postgres >/dev/null; do sleep 1; done && \
	docker compose exec -T db psql -U postgres -c 'CREATE DATABASE "fermi-db";' 2>/dev/null || true && \
	export DATABASE_URL=postgresql+asyncpg://postgres:postgres@127.0.0.1:5433/fermi-db && \
	$(MAKE) migrate
	@echo "Seeding test questions..." && \
	uv run --package fermi-db python scripts/seed_test_questions.py --file apps/fermi-api/tests/data/test_questions.json

# ============================================================================
# Testing Targets - ETL
# ============================================================================

.PHONY: test-etl-unit
test-etl-unit:
	uv run --package fermi-etl pytest apps/fermi-etl/tests/unit/ -r fE --maxfail=1 -o log_cli=false -o log_level=WARNING

.PHONY: test-etl-integration-ci
test-etl-integration-ci:
	uv run --package fermi-etl pytest apps/fermi-etl/tests/integration/ -r fE --maxfail=1 -o log_cli=false -o log_level=WARNING

.PHONY: test-etl-integration
test-etl-integration:
	@echo "Starting integration tests with automatic cleanup..."
	@trap 'docker compose down -v' EXIT; \
	docker compose up -d db && \
	until docker compose exec -T db pg_isready -U postgres >/dev/null; do sleep 1; done && \
	docker compose exec -T db psql -U postgres -c 'CREATE DATABASE "fermi-db";' 2>/dev/null || true && \
	export DATABASE_URL=postgresql+asyncpg://postgres:postgres@127.0.0.1:5433/fermi-db && \
	$(MAKE) migrate && \
	$(MAKE) test-etl-integration-ci

.PHONY: test-etl
test-etl:
	$(MAKE) test-etl-unit && $(MAKE) test-etl-integration

# ============================================================================
# Testing Targets - Frontend
# ============================================================================

# NOTE: When adding new --dart-define flags, also update:
# - apps/fermi-frontend/docs/TESTS.md (Test Execution section)
.PHONY: test-frontend-unit
test-frontend-unit:
	@cd apps/fermi-frontend && \
	flutter test test/unit/ \
	  --dart-define=API_BASE_URL=http://localhost:8000 \
	  --dart-define=SUPPRESS_TEST_LOGS=true

.PHONY: test-frontend-widget
test-frontend-widget:
	@cd apps/fermi-frontend && \
	flutter test test/widget/ \
	  --dart-define=SUPPRESS_TEST_LOGS=true

# ============================================================================
# Testing Targets - API
# ============================================================================

.PHONY: test-api-unit
test-api-unit:
	uv run --package fermi-api pytest apps/fermi-api/tests/unit/ -r fE --maxfail=1 -o log_cli=false -o log_level=WARNING

.PHONY: test-api-integration-ci
test-api-integration-ci:
	uv run --package fermi-api pytest apps/fermi-api/tests/integration/ -r fE --maxfail=1 -o log_cli=false -o log_level=WARNING

.PHONY: test-api-integration
test-api-integration:
	@echo "Starting backend integration tests with automatic cleanup..."
	@trap 'docker compose down -v' EXIT; \
	docker compose up -d db emulators && \
	docker compose exec -T emulators bash -lc 'until (</dev/tcp/127.0.0.1/8080) 2>/dev/null; do sleep 1; done; until (</dev/tcp/127.0.0.1/9099) 2>/dev/null; do sleep 1; done' && \
	until docker compose exec -T db pg_isready -U postgres >/dev/null; do sleep 1; done && \
	docker compose exec -T db psql -U postgres -c 'CREATE DATABASE "fermi-db";' 2>/dev/null || true && \
	export DATABASE_URL=postgresql+asyncpg://postgres:postgres@127.0.0.1:5433/fermi-db && \
	export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 && \
	export FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 && \
	export GOOGLE_CLOUD_PROJECT=fermi-local && \
	$(MAKE) migrate && \
	$(MAKE) test-api-integration-ci

.PHONY: test-api-endpoints
test-api-endpoints:
	uv run --package fermi-api pytest apps/fermi-api/tests/api/ -r fE --maxfail=1 -o log_cli=false -o log_level=WARNING

# ============================================================================
# Docker Targets
# ============================================================================

.PHONY: build-etl-docker
build-etl-docker:
	docker build -f apps/fermi-etl/Dockerfile -t fermi-etl:latest .

.PHONY: test-etl-docker
test-etl-docker:
	docker build -f apps/fermi-etl/Dockerfile -t fermi-etl:test .
	docker run -p 8081:8081 --env-file apps/fermi-etl/.env fermi-etl:test

# ============================================================================
# Development Targets
# ============================================================================

.PHONY: up
up:
	docker compose up -d db emulators

.PHONY: up-api
up-api:
	docker compose up -d db emulators api

.PHONY: down
down:
	docker compose down -v

.PHONY: run-frontend
run-frontend:
	@echo "Bring up db and emulators..." && \
	docker compose up -d db emulators && \
	echo "Waiting for emulators (8080, 9099) and db..." && \
	until (</dev/tcp/127.0.0.1/8080) 2>/dev/null; do sleep 1; done; \
	until (</dev/tcp/127.0.0.1/9099) 2>/dev/null; do sleep 1; done; \
	until docker compose exec -T db pg_isready -U postgres >/dev/null; do sleep 1; done; \
	docker compose exec -T db psql -U postgres -c 'CREATE DATABASE "fermi-db";' 2>/dev/null || true && \
	echo "Running migrations..." && \
	export DATABASE_URL=postgresql+asyncpg://postgres:postgres@127.0.0.1:5433/fermi-db; \
	export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080; \
	export FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099; \
	export GOOGLE_CLOUD_PROJECT=fermi-local; \
	$(MAKE) migrate; \
	echo "Seeding questions..." && \
	uv run --package fermi-db python scripts/seed_test_questions.py --file apps/fermi-api/tests/data/test_questions.json --no-dq-history; \
	echo "Creating initial DQ..." && \
	uv run --package fermi-db python scripts/manage_dq.py create; \
	docker compose up -d api && \
	echo "Launching Flutter app..." && \
	cd apps/fermi-frontend && \
	fvm flutter run -t lib/main.dart \
	  --dart-define=USE_EMULATORS=true \
	  --dart-define=FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
	  --dart-define=FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
	  --dart-define=API_BASE_URL=http://localhost:8000/api/v1 \
	  --dart-define=SUPPRESS_TEST_LOGS=true

.PHONY: build-frontend-android-release
build-frontend-android-release:
	cd apps/fermi-frontend && \
        fvm flutter clean && \
        fvm flutter pub get && \
        cd android && ./gradlew clean && cd ../ &&\
	fvm flutter build appbundle \
	  --release \
	  --dart-define=API_BASE_URL=https://fermi-api-bwuxx6eogq-uc.a.run.app/api/v1 \
	  --dart-define=USE_EMULATORS=false \
	  --dart-define=SUPPRESS_TEST_LOGS=true

.PHONY: update-icons
update-icons:
	@echo "Regenerating app icons from assets/icons/..." && \
	cd apps/fermi-frontend && \
	fvm flutter pub get && \
	fvm flutter pub run flutter_launcher_icons && \
	echo "✓ Icons successfully updated for Android and iOS"
