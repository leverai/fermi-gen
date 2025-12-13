# Fermi Dashboard

Admin dashboard for auditing Fermi questions before they are approved for production.

## Quick Start

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

## Environment Variables

| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | PostgreSQL connection string (asyncpg format) |

Example for dev database:
```
DATABASE_URL=postgresql+asyncpg://postgres:YOUR_PASSWORD@localhost:5432/fermi-db
```
