# syntax=docker/dockerfile:1
FROM ghcr.io/astral-sh/uv:python3.11-bookworm-slim AS builder
WORKDIR /app
COPY . /app

# Prepare video-gen app with dependencies
RUN uv run scripts/prepare_app.py --app-name video-gen --app-path apps/video-gen
WORKDIR /app/dist/video-gen
RUN uv venv && \
    . .venv/bin/activate && \
    uv pip install --no-cache -r requirements.txt

FROM python:3.11-slim-bookworm AS final

# Install ffmpeg and fonts for video generation
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ffmpeg \
        fonts-ubuntu \
    && rm -rf /var/lib/apt/lists/*

RUN addgroup --system app && adduser --system --group --home /home/app app
WORKDIR /home/app

# Copy built app and assets
COPY --from=builder --chown=app:app /app/dist/video-gen /home/app
COPY --from=builder --chown=app:app /app/apps/video-gen/assets /home/app/assets
COPY --from=builder --chown=app:app /app/apps/video-gen/main.py /home/app/main.py

ENV PATH="/home/app/.venv/bin:$PATH"
USER app

CMD ["python", "main.py"]
