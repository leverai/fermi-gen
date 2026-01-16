# Fermi Dashboard

Admin dashboard for auditing Fermi questions before they are approved for production.

## Quick Start (Local Development)

1. **Start Cloud SQL Proxy** (for local development):
   ```bash
   cloud-sql-proxy guesstimate-dev-478820:us-central1:fermi-db
   ```

2. **Configure environment**:
   ```bash
   cd apps/dashboard
   # Edit .env with your DATABASE_URL (password for the dev db)
   ```

3. **Sync packages** (from repo root):
   ```bash
   uv sync --all-packages
   ```

4. **Run the dashboard**:
   ```bash
   uv run --package dashboard uvicorn main:app --reload --port 8000
   ```

5. **Open** http://localhost:8000 in your browser.

## Features

- **Query pending questions**: Fetch questions with `PENDING_REVIEW` status
- **Expandable rows**: Click any row to see full details and edit fields
- **Stage changes**: Edit fields and they are tracked locally (not applied until commit)
- **Visual indicators**: Changed rows are highlighted with orange border
- **Diff view**: Click "Show Diff" to see original vs. modified values
- **Reset**: Restore any entry to its original state
- **Approve/Reject**: Quick buttons to change status
- **Batch commit**: Apply all staged changes at once

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/questions/pending?limit=N` | GET | Fetch pending review questions |
| `/api/questions/commit` | POST | Commit staged changes |
| `/health` | GET | Health check |

---

## Deployment

The dashboard is deployed to Cloud Run via GitHub Actions.

### Prerequisites

#### GCP Secret Manager Secrets

Ensure these secrets exist in GCP Secret Manager:
- `database-url-dev` - Dev database connection string
- `database-url-prod` - Prod database connection string
- `dashboard-auth-username` - Dashboard login username
- `dashboard-auth-password` - Dashboard login password

#### GitHub Repository Variables

Add these variables in Settings > Secrets and Variables > Actions > Variables:
- `DASHBOARD_SERVICE` - Cloud Run service name (e.g., `fermi-dashboard`)
- `CLOUD_SQL_INSTANCE_DEV` - Dev Cloud SQL instance name
- `CLOUD_SQL_INSTANCE_PROD` - Prod Cloud SQL instance name

### Deploying

1. Go to **Actions** tab in GitHub
2. Select **Dashboard Deploy** workflow
3. Click **Run workflow**
4. Choose the environment (`dev` or `prod`) to connect to
5. Click **Run workflow**

The dashboard will be deployed to Cloud Run. After deployment, the workflow output will show the URL.

### Authentication

The deployed dashboard is protected by HTTP Basic Auth. Use the credentials stored in `dashboard-auth-username` and `dashboard-auth-password` secrets.

### Switching Environments

The dashboard can connect to either the dev or prod database. The environment is selected when triggering the deployment workflow. To switch environments, simply re-run the workflow with a different environment selection.

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | PostgreSQL connection string (for local dev) |
| `DATABASE_URL_DEV` | Dev database URL (set by Cloud Run secrets) |
| `DATABASE_URL_PROD` | Prod database URL (set by Cloud Run secrets) |
| `ENVIRONMENT` | `dev` or `prod` - selects which DB to use |
| `AUTH_USERNAME` | HTTP Basic Auth username |
| `AUTH_PASSWORD` | HTTP Basic Auth password |

Example for local development:
```
DATABASE_URL=postgresql+asyncpg://postgres:YOUR_PASSWORD@localhost:5432/fermi-db
```
