from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_create_person():
    response = client.post("/api/v1/persons", json={
        "name": "Test User",
        "nickname": "Test",
        "relationship": "Friend"
    })
    assert response.status_code == 201
    data = response.json()
    assert data["success"] is True
    assert data["data"]["name"] == "Test User"

def test_get_persons_pagination():
    response = client.get("/api/v1/persons?page=1&limit=10")
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert "items" in data["data"]

def test_search_persons():
    response = client.get("/api/v1/persons?search=test")
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True

def test_person_not_found():
    response = client.get("/api/v1/persons/99999")
    assert response.status_code == 404
    data = response.json()
    assert data["success"] is False