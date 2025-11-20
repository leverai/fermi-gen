"""API test for health endpoint (no emulators or DB required)."""

from fastapi.testclient import TestClient


def test_health_endpoint_returns_200(client: TestClient) -> None:
    """Ensure GET /health/health returns 200 with JSON 200."""
    resp = client.get('/api/v1/health/health')
    assert resp.status_code == 200
    assert resp.json() == 200
