# Fermi API Deployment Guide

This document describes the deployment configuration and process for the Fermi API application on Google Cloud Run.

## Table of Contents

- [Overview](#overview)
- [Service Configuration](#service-configuration)
  - [Port and Resources](#port-and-resources)
  - [Service Account](#service-account)
- [Environment Variables](#environment-variables)
  - [Development Environment](#development-environment)
  - [Production Environment](#production-environment)
  - [Firebase Configuration](#firebase-configuration)
- [Deployment Process](#deployment-process)
  - [To Development](#to-development)
  - [To Production](#to-production)
- [Testing Deployed Service](#testing-deployed-service)
- [Troubleshooting](#troubleshooting)
  - [Common Issues](#common-issues)
- [Related Documentation](#related-documentation)

---

## Overview

The Fermi API is deployed to Google Cloud Run with separate environments for development and production:

The deployment uses:
- **Cloud Run**: Serverless container platform
- **Cloud SQL**: PostgreSQL 17 database
- **Firestore**: Real-time game state management
- **Firebase Authentication**: User authentication
- **Secret Manager**: Secure credential storage
- **Artifact Registry**: Docker image repository

---

## Service Configuration

### Port and Resources

```yaml
Port: 8080
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

**Service Account:** `fermi-api-runner@guesstimate-5483f.iam.gserviceaccount.com`

**Required IAM Roles:**
- `roles/cloudsql.client` - Cloud SQL access via Unix socket
- `roles/secretmanager.secretAccessor` - Read secrets at runtime
- `roles/datastore.user` - Firestore Native Mode access (note: role is called "datastore" for Firestore)
- `roles/firebaseauth.admin` - Firebase Authentication management

**Creating the Service Account:**

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

**Verify Roles:**

```bash
gcloud projects get-iam-policy $GCP_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:fermi-api-runner@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --format="table(bindings.role)"
```

---

## Environment Variables

### Development Environment

The development environment connects to Cloud SQL and production Firebase services but uses dev-specific database:

```yaml
DATABASE_URL: <from Secret Manager: database-url-dev>
JWT_SECRET_KEY: <from Secret Manager: fermi-api-jwt>
GOOGLE_CLOUD_PROJECT: guesstimate-5483f
USE_EMULATORS: false
# DO NOT SET: FIRESTORE_EMULATOR_HOST, FIREBASE_AUTH_EMULATOR_HOST
```

**Important:** `FIRESTORE_EMULATOR_HOST` and `FIREBASE_AUTH_EMULATOR_HOST` must NOT be set in Cloud Run. When these are absent, Firebase Admin SDK automatically connects to production Firebase services.

### Production Environment

Production environment uses the same configuration as development but with a different database:

```yaml
DATABASE_URL: <from Secret Manager: database-url-prod>
JWT_SECRET_KEY: <from Secret Manager: fermi-api-jwt>
GOOGLE_CLOUD_PROJECT: guesstimate-5483f
USE_EMULATORS: false
# DO NOT SET: FIRESTORE_EMULATOR_HOST, FIREBASE_AUTH_EMULATOR_HOST
```

### Firebase Configuration

**Why no emulator variables in production?**

When `FIRESTORE_EMULATOR_HOST` and `FIREBASE_AUTH_EMULATOR_HOST` are **not set**, the Firebase Admin SDK automatically connects to production Firebase services using Application Default Credentials (ADC) provided by the service account.

**Local development with emulators** (not Cloud Run):

```bash
export FIRESTORE_EMULATOR_HOST=localhost:8080
export FIREBASE_AUTH_EMULATOR_HOST=localhost:9099
export GOOGLE_CLOUD_PROJECT=fermi-local
export USE_EMULATORS=true
```

---

## Deployment Process

### To Development

1. Create feature branch from `develop`
2. Make changes and push
3. Create PR to `develop`
4. After PR merge, GitHub Actions workflow automatically:
   - Runs unit + API tests
   - Runs integration tests (PostgreSQL + Firebase emulators)
   - Builds Docker image (tagged with commit SHA and version)
   - Pushes to Artifact Registry
   - Deploys to `fermi-api-dev` on Cloud Run

**Monitoring deployment:**

```bash
# View workflow status
https://github.com/MhdMartini/fermi-gen/actions

# Check service status
gcloud run services describe fermi-api-dev --region=us-central1

# View logs
gcloud run services logs read fermi-api-dev --region=us-central1
```

### To Production

1. Create PR from `develop` to `main`
2. Review and merge
3. GitHub Actions workflow automatically:
   - Runs all tests
   - Builds Docker image
   - Deploys to `fermi-api-prod` on Cloud Run

**Pre-deployment checklist:**

- [ ] All tests passing locally and in CI
- [ ] Database migrations applied (if schema changed)
- [ ] Version bumped in `app/version.py`
- [ ] Breaking changes documented
- [ ] Firebase security rules updated (if needed)

---

## Testing Deployed Service

### Get Service URL

```bash
# Development
SERVICE_URL=$(gcloud run services describe fermi-api \
  --region=us-central1 \
  --format='value(status.url)')
```

### Health Check

```bash
curl -i $SERVICE_URL/api/v1/health
```

Expected response:
```json
HTTP/2 200
{
  "status": "healthy",
  "timestamp": "2025-11-05T12:00:00Z"
}
```

### Test Authentication

```bash
# Get Firebase ID token first (from your app or firebase CLI)
FIREBASE_TOKEN="your-firebase-id-token"

# Exchange for JWT
curl -X POST $SERVICE_URL/api/v1/auth/token \
  -H "Authorization: Bearer $FIREBASE_TOKEN"
```

### Test Game Config

```bash
# Get JWT from auth token response
JWT_TOKEN="your-jwt-token"

curl -X GET $SERVICE_URL/api/v1/game/config \
  -H "Authorization: Bearer $JWT_TOKEN"
```

---

## Troubleshooting

### Common Issues

**Authentication Errors**

```
Error: 401 Unauthorized
```

**Causes:**
- Invalid or expired Firebase token
- JWT secret mismatch
- Service account lacks `firebaseauth.admin` role

**Solutions:**
- Verify Firebase token is fresh and valid
- Check Secret Manager for `fermi-api-jwt` secret
- Verify service account roles: `gcloud projects get-iam-policy`

**Firestore Connection Issues**

```
Error: Failed to initialize Firestore
```

**Causes:**
- `FIRESTORE_EMULATOR_HOST` set in production
- Service account lacks `datastore.user` role
- Wrong `GOOGLE_CLOUD_PROJECT` value

**Solutions:**
- Ensure emulator env vars are NOT set in Cloud Run
- Verify service account has `roles/datastore.user`
- Confirm `GOOGLE_CLOUD_PROJECT=guesstimate-5483f`

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

**Integration Test Failures in CI**

```
Error: Firebase emulators not ready
```

**Causes:**
- Emulators not started before tests
- Wrong ports (should be 8080, 9099)
- `firebase.json` not found

**Solutions:**
- Check workflow uses `invertase/firebase-emulator-action`
- Verify ports: Firestore=8080, Auth=9099
- Ensure `firebase.json` exists in `apps/fermi-api/`

### Viewing Logs

**Recent logs:**

```bash
gcloud run services logs read fermi-api \
  --region=us-central1 \
  --limit=50
```

**Filter by severity:**

```bash
gcloud run services logs read fermi-api \
  --region=us-central1 \
  --log-filter='severity>=ERROR'
```

**Follow logs in real-time:**

```bash
gcloud run services logs tail fermi-api \
  --region=us-central1
```

---

## Related Documentation

- [Fermi API README](../README.md): Quick start and API reference
- [Architecture Guide](ARCHITECTURE.md): Detailed design and game flow
- [Main CI/CD Documentation](../../docs/CICD.md): Complete infrastructure setup
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Firebase Admin SDK](https://firebase.google.com/docs/admin/setup)
