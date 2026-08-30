from fastapi.testclient import TestClient

from backend.main import app


client = TestClient(app)


def test_root():
    response = client.get("/")

    assert response.status_code == 200

    data = response.json()

    assert data["name"] == "ThermoRoute"
    assert data["status"] == "running"
    assert data["mode"] == "live"
    assert data["routing_source"] == "OSRM"
    assert data["climate_source"] == "FortyGuard"
    assert data["docs"] == "/docs"


def test_health():
    response = client.get("/health")

    assert response.status_code == 200

    data = response.json()

    assert data["status"] == "healthy"


def test_api_health_alias():
    response = client.get("/api/health")

    assert response.status_code == 200

    data = response.json()

    assert data["status"] == "healthy"


def test_docs_available():
    response = client.get("/docs")

    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]


def test_openapi_available():
    response = client.get("/openapi.json")

    assert response.status_code == 200

    data = response.json()

    assert data["info"]["title"] == "ThermoRoute API"
    assert "/api/optimize" in data["paths"]


def test_optimize_rejects_invalid_coordinates():
    payload = {
        "origin_latitude": 200.0,
        "origin_longitude": -112.0740,
        "destination_latitude": 33.4650,
        "destination_longitude": -112.0600,
        "date": "2026-08-30",
        "time": "14:00",
    }

    response = client.post(
        "/api/optimize",
        json=payload,
    )

    assert response.status_code == 422


def test_optimize_rejects_same_origin_and_destination():
    payload = {
        "origin_latitude": 33.4484,
        "origin_longitude": -112.0740,
        "destination_latitude": 33.4484,
        "destination_longitude": -112.0740,
        "date": "2026-08-30",
        "time": "14:00",
    }

    response = client.post(
        "/api/optimize",
        json=payload,
    )

    # This request passes Pydantic validation, then the
    # route service rejects identical coordinates.
    assert response.status_code == 422