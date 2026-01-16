# syntax=docker/dockerfile:1

# --- Builder Stage: Prepare the application and install dependencies ---
FROM ghcr.io/astral-sh/uv:python3.11-bookworm-slim AS builder

WORKDIR /app

# Copy the entire project context to run the preparation script
COPY . /app

# Run the script to prepare the dashboard app.
RUN uv run scripts/prepare_app.py --app-name dashboard --app-path apps/dashboard

# Create a virtual environment and install dependencies into it
WORKDIR /app/dist/dashboard
RUN uv venv && \
    . .venv/bin/activate && \
    uv pip install --no-cache -r requirements.txt


# --- Final Stage: Create the lean production image ---
FROM python:3.11-slim-bookworm AS final

# Create a non-root user and its home directory
RUN addgroup --system app && adduser --system --group --home /home/app app

WORKDIR /home/app

# Copy the application code and the populated virtual environment from the builder stage
COPY --from=builder --chown=app:app /app/dist/dashboard /home/app

# Add the virtual environment to the PATH
ENV PATH="/home/app/.venv/bin:$PATH"

USER app

# expose the port
EXPOSE 8080

# Run the application using the python from the virtual environment
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
