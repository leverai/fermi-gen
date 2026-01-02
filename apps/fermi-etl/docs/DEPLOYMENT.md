# Fermi ETL Deployment Guide

This document describes the deployment configuration and process for the Fermi ETL Pipeline on Google Cloud Run.

## Table of Contents

- [Overview](#overview)
- [Service Configuration](#service-configuration)
  - [Port and Resources](#port-and-resources)
  - [Service Account](#service-account)
- [Environment Variables](#environment-variables)
- [Deployment Process](#deployment-process)
  - [To Development](#to-development)
  - [To Production](#to-production)
- [Testing Deployed Service](#testing-deployed-service)
- [Troubleshooting](#troubleshooting)
  - [Common Issues](#common-issues)
- [Related Documentation](#related-documentation)

---

## Overview

The Fermi ETL Pipeline is deployed to Google Cloud Run with separate environments for development and production:

- **Development**: `fermi-etl-dev` (auto-deploys from `develop` branch)
- **Production**: `fermi-etl-prod` (auto-deploys from `main` branch)

The deployment uses:
- **Cloud Run**: Serverless container platform
- **Cloud SQL**: PostgreSQL 17 database with pgvector extension
- **Secret Manager**: Secure credential storage (OpenAI, SerpAPI keys)
- **Artifact Registry**: Docker image repository

---

## Service Configuration

### Port and Resources

```yaml
Port: 8081
Memory: 512Mi
CPU: 1
Timeout: 300s
Min Instances:
  - Development: 0
  - Production: 1
Max Instances:
  - Development: 3
  - Production: 10
```

### Service Account

**Service Account:** `fermi-etl-runner@guesstimate-5483f.iam.gserviceaccount.com`

**Required IAM Roles:**
- `roles/cloudsql.client` - Cloud SQL access via Unix socket
- `roles/secretmanager.secretAccessor` - Read secrets at runtime

**Creating the Service Account:**

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

**Verify Roles:**

```bash
gcloud projects get-iam-policy $GCP_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:fermi-etl-runner@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --format="table(bindings.role)"
```

---

## Environment Variables

The ETL pipeline requires the following environment variables in Cloud Run:

### Required Variables

```yaml
# Database connection (from Secret Manager)
DATABASE_URL: <from Secret Manager: database-url-dev or database-url-prod>

# API keys (from Secret Manager)
OPENAI_API_KEY: <from Secret Manager: openai-api-key>
SERP_API_KEY: <from Secret Manager: serp-api-key>
```

### Optional Variables (with defaults)

```yaml
# Semantic deduplication thresholds
SEED_SIMILARITY_THRESHOLD: "0.1"           # Cosine distance for seed uniqueness
QUESTION_SIMILARITY_THRESHOLD: "0.15"      # Cosine distance for question uniqueness
```

> [!NOTE]
> Model configuration (question_model, location_model, extraction_model, etc.) is now passed as request arguments rather than environment variables. This allows runtime configuration per-request.

### Environment-Specific Configuration

**Development:**
- Lower similarity thresholds for more exploration
- Smaller batch sizes for faster iteration
- More permissive confidence threshold

**Production:**
- Stricter similarity thresholds for quality
- Larger batch sizes for efficiency
- Higher confidence threshold for accuracy

---

## Deployment Process

### To Development

1. Create feature branch from `develop`
2. Make changes and push
3. Create PR to `develop`
4. After PR merge, GitHub Actions workflow automatically:
   - Runs unit tests (fast, no Docker)
   - Runs integration tests (PostgreSQL service container)
   - Builds Docker image (tagged with commit SHA and version)
   - Pushes to Artifact Registry
   - Deploys to `fermi-etl-dev` on Cloud Run

**Monitoring deployment:**

```bash
# View workflow status
https://github.com/MhdMartini/fermi-gen/actions

# Check service status
gcloud run services describe fermi-etl --region=us-central1

# View logs
gcloud run services logs read fermi-etl --region=us-central1
```

### To Production

1. Create PR from `develop` to `main`
2. Review and merge
3. GitHub Actions workflow automatically:
   - Runs all tests
   - Builds Docker image
   - Deploys to `fermi-etl-prod` on Cloud Run

**Pre-deployment checklist:**

- [ ] All tests passing locally and in CI
- [ ] Database migrations applied (if schema changed)
- [ ] Version bumped in `app/version.py`
- [ ] Breaking changes documented
- [ ] API keys valid and not rate-limited

**Versioning:**

Docker images are tagged with:
- `{commit-sha}` - Unique identifier
- `{version}` - Semantic version from `app/version.py` (e.g., `0.1.0`)
- `latest` - Latest build

To release a new version:

```bash
# Update version
echo "__version__ = '0.2.0'" > apps/fermi-etl/app/version.py

# Commit and push
git add apps/fermi-etl/app/version.py
git commit -m "Bump ETL version to 0.2.0"
git push
```

---

## Testing Deployed Service

### Get Service URL

```bash
SERVICE_URL=$(gcloud run services describe fermi-etl \
  --region=us-central1 \
  --format='value(status.url)')
```

### Health Check

```bash
curl -i $SERVICE_URL/health
```

Expected response:
```json
HTTP/2 200
{
  "status": "healthy",
  "service": "fermi-etl",
  "version": "0.1.0",
  "timestamp": "2025-11-05T12:00:00Z"
}
```

### Test Seed Insertion

```bash
curl -X POST $SERVICE_URL/seeds/insert_literal \
  -H "Content-Type: application/json" \
  -d '{"seeds": ["Test Topic A", "Test Topic B"]}'
```

### Test Question Generation

```bash
curl -X POST $SERVICE_URL/insert_llm \
  -H "Content-Type: application/json" \
  -d '{"num_seeds": 2, "questions_per_seed": 5, "mode": "thompson"}'
```

### Test Answer Generation

```bash
curl -X POST $SERVICE_URL/answers/insert_serp \
  -H "Content-Type: application/json" \
  -d '{"num_questions": 10}'
```

---

## Troubleshooting

### Common Issues

**Cloud SQL Connection Errors**

```
Error: Cannot connect to database
```

**Causes:**
- Service account lacks `cloudsql.client` role
- Wrong Cloud SQL instance name
- Database credentials incorrect in Secret Manager

**Solutions:**
- Verify service account has `roles/cloudsql.client`
- Check Cloud SQL instance name in deployment config
- Verify `database-url-dev` or `database-url-prod` secret value
- Check Cloud SQL instance is running and accessible

**OpenAI API Errors**

```
Error: 429 Rate Limit Exceeded
Error: 401 Unauthorized
```

**Causes:**
- API key invalid or expired
- Rate limit exceeded
- Quota exhausted

**Solutions:**
- Verify `openai-api-key` in Secret Manager
- Check OpenAI account usage and limits
- Implement exponential backoff (already in code)
- Reduce batch sizes

**SerpAPI Errors**

```
Error: SerpAPI request failed
Error: 429 Too Many Requests
```

**Causes:**
- API key invalid
- Monthly search limit reached
- Rate limiting

**Solutions:**
- Verify `serp-api-key` in Secret Manager
- Check SerpAPI account usage dashboard
- Wait for limit reset or upgrade plan
- Reduce `num_questions` parameter

**Integration Test Failures in CI**

```
Error: PostgreSQL connection refused
```

**Causes:**
- PostgreSQL service not healthy
- Wrong database port (should be 5433)
- Environment variables not set correctly

**Solutions:**
- Check workflow uses PostgreSQL service container
- Verify port mapping: `5433:5432`
- Ensure `DATABASE_URL` uses `localhost:5433`
- Wait for PostgreSQL health check before tests

**Embedding Generation Slow**

```
Timeout after 300s
```

**Causes:**
- Large batch sizes
- Network latency to OpenAI
- Database connection pool exhaustion

**Solutions:**
- Reduce `questions_per_seed` parameter
- Increase Cloud Run timeout (max 3600s)
- Check OpenAI API status
- Monitor database connection pool

### Viewing Logs

**Recent logs:**

```bash
gcloud run services logs read fermi-etl \
  --region=us-central1 \
  --limit=50
```

**Filter by severity:**

```bash
gcloud run services logs read fermi-etl \
  --region=us-central1 \
  --log-filter='severity>=ERROR'
```

**Follow logs in real-time:**

```bash
gcloud run services logs tail fermi-etl \
  --region=us-central1
```

**Filter by specific endpoint:**

```bash
gcloud run services logs read fermi-etl \
  --region=us-central1 \
  --log-filter='textPayload=~"POST /insert_llm"'
```

---

## Related Documentation

- [Fermi ETL README](../README.md): Quick start and API reference
- [Architecture Guide](ARCHITECTURE.md): Detailed design and pipeline components
- [Main CI/CD Documentation](../../docs/CICD.md): Complete infrastructure setup
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [SerpAPI Documentation](https://serpapi.com/docs)
- [OpenAI API Documentation](https://platform.openai.com/docs)
