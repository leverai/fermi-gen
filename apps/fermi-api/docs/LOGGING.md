# Structured Logging with OpenTelemetry

Fermi-API uses OpenTelemetry for distributed tracing and structured logging.

## Overview

OpenTelemetry provides two complementary signals:

| Signal | Purpose | Destination |
|--------|---------|-------------|
| **Spans** | Complete request lifecycle - method, path, status, duration, custom attributes | Cloud Trace |
| **Logs** | Discrete events during processing, correlated via trace/span ID | Cloud Logging |

### Key Components

| Component | Description |
|-----------|-------------|
| `app/logging/otel.py` | OpenTelemetry initialization and FastAPI instrumentation |
| `app/logging/attributes.py` | Custom span attribute constants |
| `app/logging/formatter.py` | JSON formatter compatible with Google Cloud Logging |
| `app/logging/setup.py` | Logging configuration and initialization |

## How It Works

1. **Request starts**: `FastAPIInstrumentor` creates a span automatically with:
   - Trace ID and Span ID
   - HTTP method, path, status code
   - Timing information

2. **During processing**: Endpoints enrich the span with business context:
   ```python
   from opentelemetry import trace
   from app.logging.attributes import ACTION, QUESTION_UID

   span = trace.get_current_span()
   span.set_attribute(ACTION, 'dq_start')
   span.set_attribute(QUESTION_UID, question.uid)
   ```

3. **Logs are correlated**: Any `logger.info()` call automatically includes trace/span IDs for correlation in Cloud Logging.

## Usage Examples

### Basic Setup in Endpoints

```python
import logging
from opentelemetry import trace
from opentelemetry.trace import Status, StatusCode
from app.logging.attributes import ACTION, USER_ID

logger = logging.getLogger(__name__)

@router.post('/game/create')
async def create_game(payload: CreateGameRequest, user: User = Depends(get_current_user)):
    span = trace.get_current_span()
    span.set_attribute(ACTION, 'game_create')

    try:
        game = await game_service.create(payload)
        span.set_attribute('app.game.id', str(game.id))
        span.set_attribute('app.game.player_count', len(game.players))
        return game
    except Exception as ex:
        span.set_status(Status(StatusCode.ERROR))
        span.record_exception(ex)
        raise
```

### When to Use Span Attributes vs Logs

| Use span attributes for: | Use `logger.info()` for: |
|--------------------------|--------------------------|
| Request-level context (action, IDs, counts) | Discrete events during processing |
| Data you want to filter/search in Cloud Trace | Detailed progress or debug info |
| Metrics-like data (counts, durations) | Human-readable messages |

```python
# ✅ Good: span for context, logger for events
span.set_attribute(ACTION, 'dq_start')
span.set_attribute(QUESTION_UID, q.id)
logger.info(f'User started DQ for {date}')

# ❌ Avoid: logging structured data that belongs on spans
logger.info(f'action=dq_start question_id={q.id}')  # Use span instead
```

### Error Handling

Always record exceptions and set span status on errors:

```python
from opentelemetry import trace
from opentelemetry.trace import Status, StatusCode

@router.post('/game/join')
async def join_game(game_id: str, user: User = Depends(get_current_user)):
    span = trace.get_current_span()
    span.set_attribute(ACTION, 'game_join')
    span.set_attribute('app.game.id', game_id)

    try:
        result = await game_service.join(game_id, user)
        return result
    except GameFullError as ex:
        span.set_status(Status(StatusCode.ERROR))
        span.record_exception(ex)
        raise HTTPException(400, 'Game is full')
    except Exception as ex:
        span.set_status(Status(StatusCode.ERROR))
        span.record_exception(ex)
        logger.exception('Unexpected error joining game')
        raise
```

### Background Tasks / Scheduled Jobs

Create manual spans for background work (no HTTP request = no auto span):

```python
from opentelemetry import trace

async def scheduled_cleanup():
    tracer = trace.get_tracer(__name__)
    with tracer.start_as_current_span('scheduled_cleanup') as span:
        span.set_attribute(ACTION, 'cleanup')

        deleted = await cleanup_old_games()
        span.set_attribute('app.cleanup.deleted_count', deleted)

        logger.info(f'Cleaned up {deleted} old games')
```

## Custom Attributes

All custom attributes are defined in `app/logging/attributes.py`:

```python
from app.logging.attributes import (
    ACTION,          # 'app.action' - the operation being performed
    USER_ID,         # 'app.user.id' - internal user ID
    FIREBASE_UID,    # 'app.user.firebase_uid'
    QUESTION_UID,    # 'app.dq.question_uid'
    DQ_CATEGORY,     # 'app.dq.category'
    # ... etc
)
```

## Configuration

### Excluding URLs from Tracing

Set the `OTEL_PYTHON_FASTAPI_EXCLUDED_URLS` environment variable to a comma-delimited list of regex patterns:

```bash
export OTEL_PYTHON_FASTAPI_EXCLUDED_URLS="health,/health,/api/v1/health"
```

### Settings in `app/core/config.py`

| Setting | Default | Description |
|---------|---------|-------------|
| `log_level` | `INFO` | Logging level |
| `log_format` | `auto` | `json`, `text`, or `auto` (detect from env) |

## Cloud Logging Integration

When deployed to Cloud Run (`K_SERVICE` env var present):

- Spans are exported to Cloud Trace via `opentelemetry-exporter-gcp-trace`
- Logs are formatted as JSON with Cloud Logging special fields
- Logs include `logging.googleapis.com/trace` and `logging.googleapis.com/spanId` for correlation
- Click a log entry in Cloud Logging → navigate to trace in Cloud Trace

## Local Development

When running locally, logs use a human-readable format:

```
16:23:45.123 INFO     [span=abc12345] User started DQ for 2026-01-05
```

Spans are created but not exported locally.

## Best Practices

1. **Always add `ACTION`** to identify what the endpoint does
2. **Add IDs** (game_id, user_id, question_id) for filtering
3. **Add counts** (player_count, score) for analytics
4. **Don't log sensitive data** (passwords, tokens, PII)
5. **Use `logger.exception()` for errors** - trace IDs included automatically
6. **Always handle exceptions** with `span.record_exception()` and `span.set_status()`

## OpenTelemetry Dependencies

| Package | Purpose |
|---------|---------|
| `opentelemetry-api` | Core OTel API |
| `opentelemetry-sdk` | OTel SDK implementation |
| `opentelemetry-instrumentation-fastapi` | Auto-instrument FastAPI requests |
| `opentelemetry-instrumentation-logging` | Add trace/span IDs to all logs |
| `opentelemetry-exporter-gcp-trace` | Export spans to Cloud Trace |
