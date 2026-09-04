# Fermi CI/CD Documentation

Comprehensive CI/CD setup for fermi-etl and fermi-api applications using GitHub Actions and Google Cloud Run.

## Table of Contents

1. [Overview](#overview)
2. [Quick Links](#quick-links)
   - [App-Specific Deployment Docs](#app-specific-deployment-docs)
3. [Architecture](#architecture)
4. [Workflow Comparison](#workflow-comparison)
5. [GitHub Configuration](#github-configuration)
6. [Service Account Setup](#service-account-setup)
7. [Workflow Details](#workflow-details)
   - [Fermi ETL](#fermi-etl-workflow)
   - [Fermi API](#fermi-api-workflow)
8. [Deployment Process](#deployment-process)
9. [Database Migrations](#database-migrations)
10. [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)
11. [Security Considerations](#security-considerations)
12. [Setup Checklist](#setup-checklist)

---

## Quick Links

### App-Specific Deployment Docs

For deployment details specific to each application, see:

- **[Fermi ETL Deployment](../apps/fermi-etl/docs/DEPLOYMENT.md)**: ETL-specific configuration, environment variables, and troubleshooting
- **[Fermi API Deployment](../apps/fermi-api/docs/DEPLOYMENT.md)**: API-specific configuration, Firebase setup, and troubleshooting

This document covers shared infrastructure (GCP, GitHub Actions, service accounts). For application-specific details, refer to the docs above.

---

## Overview

Both applications follow a similar CI/CD pattern with environment-specific deployments:

- **Development**: Auto-deploy to dev environment on `develop` branch
- **Production**: Auto-deploy to prod environment on `main` branch

### Key Differences

| Feature | Fermi ETL | Fermi API |
|---------|-----------|-----------|
| **Port** | 8081 | 8080 |
| **Tests** | Unit + Integration | Unit + API + Integration |
| **Dependencies** | PostgreSQL only | PostgreSQL + Firebase Emulators |
| **Emulators** | None | Firestore + Auth (Node 24, Java 21) |
| **Secrets** | Database, OpenAI, SERP API | Database, JWT, Firebase |
| **Service Account** | `fermi-etl-runner` | `fermi-api-runner` |

---

## Architecture

### GCP Resources (Shared)

- **Project**: Single GCP project (`guesstimate-5483f`)
- **Cloud SQL**: PostgreSQL 17 with pgvector extension
- **Artifact Registry**: Separate repositories for each app
- **Secret Manager**: Environment-specific secrets
- **Workload Identity Federation**: `fermi-gen` pool for GitHub Actions auth

### Secret Manager Secrets

**Shared:**
- `openai-api-key` (ETL only)
- `serp-api-key` (ETL only)
- `database-url-dev`
- `database-url-prod`

**API-specific:**
- `fermi-api-jwt` (shared across dev/prod)

---

## Workflow Comparison

### Triggers

Both workflows trigger on pushes to `develop` or `main` when changes occur in:
- App directory (`apps/fermi-etl/**` or `apps/fermi-api/**`)
- Shared packages (`packages/fermi-core/**`, `packages/fermi-db/**`)
- Dependencies (`uv.lock`, `alembic.ini`)
- Workflow file itself

### Job Structure

**Fermi ETL:**
1. `unit-tests` → Unit tests
2. `integration-tests` → Integration tests with PostgreSQL
3. `build-and-push` → Docker build and push to Artifact Registry
4. `deploy` → Deploy to Cloud Run (dev or prod)

**Fermi API:**
1. `unit-and-api-tests` → Combined unit and API endpoint tests
2. `integration-tests` → Integration tests with PostgreSQL + Firebase emulators
3. `build-and-push` → Docker build and push to Artifact Registry
4. `deploy` → Deploy to Cloud Run (dev or prod)

For cross-stack changes, the orchestrator waits for the API workflow (including
its deployment on pushes) before starting the frontend workflow. Develop
publishes Android to the internal track; main publishes to production.

---

## GitHub Configuration

### Repository Secrets
Location: Settings > Secrets and variables > Actions > Secrets

- `GCP_WORKLOAD_IDENTITY_PROVIDER` - Workload Identity Provider path
- `OPENAI_API_KEY` - For ETL integration tests and API smart-search embeddings
- `SERP_API_KEY` - For ETL integration tests

### Repository Variables
Location: Settings > Secrets and variables > Actions > Variables

- `GCP_PROJECT_ID` - GCP project ID
- `GCP_PROJECT_NUMBER` - GCP project number
- `GCP_REGION` - Deployment region (e.g., `us-central1`)
- `ARTIFACT_REGISTRY_REPO` - Full registry URL
- `CLOUD_SQL_INSTANCE` - Cloud SQL instance name
- `SMART_SEARCH_ENABLED` - Optional per-environment API feature flag (`true` or `false`). If unset, CI enables it in dev and keeps it off in prod.

### Environment Variables
Location: Settings > Environments > [dev/prod]

**Development (dev):**
- `CLOUD_RUN_SERVICE` - Service name (e.g., `fermi-etl-dev`, `fermi-api-dev`)
- `DATABASE_URL_SECRET` - `database-url-dev`

**Production (prod):**
- `CLOUD_RUN_SERVICE` - Service name (e.g., `fermi-etl-prod`, `fermi-api-prod`)
- `DATABASE_URL_SECRET` - `database-url-prod`

---

## Service Account Setup

### Fermi ETL Runner

**Service Account:** `fermi-etl-runner@guesstimate-5483f.iam.gserviceaccount.com`

**Required IAM Roles:**
- `roles/cloudsql.client` - Cloud SQL access
- `roles/secretmanager.secretAccessor` - Read secrets

**Setup Commands:**
```bash
GCP_PROJECT_ID=guesstimate-5483f

# Create service account
gcloud iam service-accounts create fermi-etl-runner \
  --display-name="Fermi ETL Cloud Run Service Account" \
  --project=$GCP_PROJECT_ID

# Grant roles
for ROLE in cloudsql.client secretmanager.secretAccessor; do
  gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
    --member="serviceAccount:fermi-etl-runner@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/$ROLE"
done
```

### Fermi API Runner

**Service Account:** `fermi-api-runner@guesstimate-5483f.iam.gserviceaccount.com`

**Required IAM Roles:**
- `roles/cloudsql.client` - Cloud SQL access
- `roles/secretmanager.secretAccessor` - Read secrets
- `roles/datastore.user` - Firestore access (yes, it's called "datastore" for Firestore!)
- `roles/firebaseauth.admin` - Firebase Authentication access

**Setup Commands:**
```bash
GCP_PROJECT_ID=guesstimate-5483f

# Create service account
gcloud iam service-accounts create fermi-api-runner \
  --display-name="Fermi API Cloud Run Service Account" \
  --project=$GCP_PROJECT_ID

# Grant roles
for ROLE in cloudsql.client secretmanager.secretAccessor datastore.user firebaseauth.admin; do
  gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
    --member="serviceAccount:fermi-api-runner@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/$ROLE"
done
```

**Note:** `roles/datastore.user` is the correct role for Firestore Native Mode access, despite the "datastore" naming.

### GitHub Actions Permissions

Grant GitHub Actions permission to deploy:

```bash
GCP_PROJECT_ID=guesstimate-5483f
GCP_PROJECT_NUMBER=your-project-number

PRINCIPAL="principalSet://iam.googleapis.com/projects/$GCP_PROJECT_NUMBER/locations/global/workloadIdentityPools/fermi-gen/attribute.repository/MhdMartini/fermi-gen"

# Grant deployment permissions
for ROLE in run.admin iam.serviceAccountUser artifactregistry.writer; do
  gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
    --role="roles/$ROLE" \
    --member="$PRINCIPAL"
done
```

### Verify Service Account Roles

```bash
# Check fermi-etl-runner roles
gcloud projects get-iam-policy $GCP_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:fermi-etl-runner@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --format="table(bindings.role)"

# Check fermi-api-runner roles
gcloud projects get-iam-policy $GCP_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:fermi-api-runner@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --format="table(bindings.role)"
```

---

## Workflow Details

### Fermi ETL Workflow

**File:** `.github/workflows/fermi-etl-ci-cd.yml`

**Test Strategy:**
- Unit tests: Pure Python logic (no external dependencies)
- Integration tests: Full stack with PostgreSQL service container

**Environment Variables (CI):**
```yaml
DATABASE_URL: postgresql+asyncpg://postgres:postgres@localhost:5433/fermi-db
OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
SERP_API_KEY: ${{ secrets.SERP_API_KEY }}
```

**Deployment Configuration:**
- Port: 8081
- Min instances: 0 (dev), 1 (prod)
- Max instances: 3 (dev), 10 (prod)
- Memory: 512Mi, CPU: 1, Timeout: 300s

### Fermi API Workflow

**File:** `.github/workflows/fermi-api-ci-cd.yml`

**Test Strategy:**
- Unit + API tests: Combined job (fast, no dependencies)
- Integration tests: Full stack with PostgreSQL + Firebase emulators

**Firebase Emulator Setup:**
- Uses [invertase/firebase-emulator-action](https://github.com/invertase/firebase-emulator-action)
- Requires Node.js 24 (LTS) and Java 21 (LTS, Amazon Corretto)
- Emulators: Firestore (port 8080), Auth (port 9099)

**Environment Variables (CI):**
```yaml
DATABASE_URL: postgresql+asyncpg://postgres:postgres@localhost:5433/fermi-db
FIRESTORE_EMULATOR_HOST: localhost:8080
FIREBASE_AUTH_EMULATOR_HOST: localhost:9099
GOOGLE_CLOUD_PROJECT: fermi-local
USE_EMULATORS: true
```

**Production Environment Variables:**
```yaml
USE_EMULATORS: false
GOOGLE_CLOUD_PROJECT: guesstimate-5483f
SMART_SEARCH_ENABLED: ${{ vars.SMART_SEARCH_ENABLED || (inputs.environment == 'dev' && 'true' || 'false') }}
# DO NOT SET: FIRESTORE_EMULATOR_HOST, FIREBASE_AUTH_EMULATOR_HOST
```

**Why no emulator vars in production?** When `FIRESTORE_EMULATOR_HOST` and `FIREBASE_AUTH_EMULATOR_HOST` are **not set**, the Firebase Admin SDK automatically connects to production Firebase services.

**Deployment Configuration:**
- Port: 8080
- Min instances: 0 (dev), 1 (prod)
- Max instances: 3 (dev), 10 (prod)
- Memory: 512Mi, CPU: 1, Timeout: 300s

---

## Deployment Process

### To Development

1. Create feature branch from `develop`
2. Make changes and push
3. Create PR to `develop`
4. After PR merge, workflow automatically:
   - Runs tests
   - Builds Docker image (tagged with commit SHA and version)
   - Deploys to dev environment

### To Production

1. Create PR from `develop` to `main`
2. Review and merge
3. Workflow automatically:
   - Runs tests
   - Builds Docker image
   - Deploys to prod environment

### Versioning

Both apps use semantic versioning from `app/version.py`:
```python
__version__ = '0.1.0'
```

Docker images are tagged with:
- `{commit-sha}` - Unique identifier
- `{version}` - Semantic version (e.g., `0.1.0`)
- `latest` - Latest build

---

## Database Migrations

Migrations must be run before deploying schema changes.

### Using Cloud SQL Proxy

```bash
# Start proxy
cloud-sql-proxy guesstimate-5483f:us-central1:your-instance

# Run migrations
export DATABASE_URL=postgresql+asyncpg://user:password@127.0.0.1:5432/fermi-db
uv run alembic upgrade head
```

### Direct Connection (if public IP enabled)

```bash
export DATABASE_URL=postgresql+asyncpg://user:password@PUBLIC_IP:5432/fermi-db
uv run alembic upgrade head
```

---

## Monitoring and Troubleshooting

### View Deployment Status

- GitHub Actions: https://github.com/MhdMartini/fermi-gen/actions
- Cloud Run Console: https://console.cloud.google.com/run

### Check Service Logs

```bash
# ETL logs
gcloud run services logs read fermi-etl-dev --region=$GCP_REGION
gcloud run services logs read fermi-etl-prod --region=$GCP_REGION

# API logs
gcloud run services logs read fermi-api-dev --region=$GCP_REGION
gcloud run services logs read fermi-api-prod --region=$GCP_REGION
```

### Test Deployed Services

```bash
# Get service URL and test
SERVICE_URL=$(gcloud run services describe fermi-etl-dev \
  --region=$GCP_REGION \
  --format='value(status.url)')
curl $SERVICE_URL/health

SERVICE_URL=$(gcloud run services describe fermi-api-dev \
  --region=$GCP_REGION \
  --format='value(status.url)')
curl $SERVICE_URL/api/v1/health
```

### Common Issues

**Authentication Errors:**
- Verify `GCP_WORKLOAD_IDENTITY_PROVIDER` secret
- Check IAM bindings: `gcloud projects get-iam-policy $GCP_PROJECT_ID`
- Ensure repository name matches in workload identity pool

**Secret Access Errors:**
- Verify service account has `secretmanager.secretAccessor` role
- Check secret names in Secret Manager: `gcloud secrets list`
- Ensure secrets exist with correct names

**Cloud SQL Connection Errors:**
- Verify service account has `cloudsql.client` role
- Check Cloud SQL instance name in deployment
- Verify database credentials in secrets

**Firebase Connection Issues (API only):**
- Confirm emulator env vars are NOT set in production
- Verify service account has `datastore.user` and `firebaseauth.admin` roles
- Check `GOOGLE_CLOUD_PROJECT` matches actual project

**Integration Test Failures:**
- ETL: Ensure PostgreSQL service is healthy
- API: Check Firebase emulators started (ports 8080, 9099)
- API: Verify `firebase.json` exists in `apps/fermi-api/`
- Check environment variables are set correctly

---

## Security Considerations

### Authentication
- **No long-lived keys**: Uses Workload Identity Federation
- **Short-lived tokens**: GitHub Actions obtains temporary credentials

### Secrets Management
- All sensitive data in GCP Secret Manager
- Secrets mounted at runtime, never in code or images
- Environment-specific secrets (dev/prod isolation)

### Access Control
- **Least privilege**: Service accounts have minimal required permissions
- **IAM roles**: Granular permissions per service
- **Audit logs**: All deployments logged in Cloud Audit Logs

### Network Security
- Cloud SQL: Private connection via Unix socket (no public IP needed)
- Cloud Run: Can be configured with VPC connector for private networking
- Secrets: Retrieved at startup, not logged

### Best Practices
- Never commit secrets to git
- Use environment-specific service accounts
- Review IAM permissions regularly
- Monitor Cloud Audit Logs for unexpected access

---

## Setup Checklist

### Initial Setup (One-time)

- [ ] Create service accounts (`fermi-etl-runner`, `fermi-api-runner`)
- [ ] Grant IAM roles to service accounts
- [ ] Grant GitHub Actions deployment permissions
- [ ] Create Secret Manager secrets
- [ ] Create GitHub environments (dev, prod)
- [ ] Configure GitHub secrets and variables
- [ ] Create Cloud Run services or allow auto-creation
- [ ] Set up Cloud SQL instance
- [ ] Configure Artifact Registry repositories

### Before Each Deployment

- [ ] Run database migrations if schema changed
- [ ] Update `__version__` in `app/version.py`
- [ ] Verify tests pass locally
- [ ] Review changes in PR
- [ ] Monitor deployment in GitHub Actions
- [ ] Verify deployment in Cloud Run Console
- [ ] Test deployed service endpoints

---

## Local Development

### Running Tests

```bash
# ETL
make test-etl-unit          # Unit tests only
make test-etl-integration   # Integration tests with Docker
make test-etl              # All tests

# API
make test-api-unit          # Unit tests only
make test-api-endpoints     # API endpoint tests
make test-api-integration   # Integration tests with Docker + emulators
```

### Building Docker Images

```bash
# ETL
make build-etl-docker
make test-etl-docker

# API
docker build -f apps/fermi-api/Dockerfile -t fermi-api:test .
docker run -p 8080:8080 --env-file apps/fermi-api/.env fermi-api:test
```

---

## References

- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Firebase Emulator Suite](https://firebase.google.com/docs/emulator-suite)
- [Firestore IAM Roles](https://cloud.google.com/firestore/docs/security/iam#roles)
- [GitHub Actions Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [Artifact Registry Documentation](https://cloud.google.com/artifact-registry/docs)
