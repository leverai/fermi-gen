# syntax=docker/dockerfile:1
FROM ghcr.io/astral-sh/uv:python3.11-bookworm-slim AS builder
WORKDIR /app
COPY . /app

# Prepare fermi-db package for migrations
RUN uv run scripts/prepare_app.py --app-name fermi-db --app-path packages/fermi-db
WORKDIR /app/dist/fermi-db
RUN uv venv && \
    . .venv/bin/activate && \
    uv pip install --no-cache -r requirements.txt && \
    uv pip install --no-cache alembic

FROM python:3.11-slim-bookworm AS final
RUN addgroup --system app && adduser --system --group --home /home/app app
WORKDIR /home/app
COPY --from=builder --chown=app:app /app/dist/fermi-db /home/app
COPY --from=builder --chown=app:app /app/alembic.ini /home/app/
ENV PATH="/home/app/.venv/bin:$PATH"
USER app
# Run migrations

CMD ["alembic", "-c", "alembic.ini", "upgrade", "head"]