import os

import pytest

from app import app


@pytest.fixture()
def client():
    app.config["TESTING"] = True
    with app.test_client() as test_client:
        yield test_client


def test_home_endpoint(client):
    response = client.get("/")

    assert response.status_code == 200
    assert response.get_json() == {
        "status": "healthy",
        "service": "task1-app",
        "version": "1.0.0",
        "environment": os.getenv("ENV", "development"),
    }


def test_health_endpoint(client):
    response = client.get("/health")

    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_info_endpoint(client):
    response = client.get("/api/info")

    assert response.status_code == 200
    assert response.get_json() == {
        "name": "Task 1 App",
        "version": "1.0.0",
        "description": "Jenkins Lab Task 1 Application",
    }
