"""Simple FastAPI endpoint tests - just test the API works, not the model."""
import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def client():
    """Create test client."""
    from inference.main import app

    return TestClient(app)


def test_docs_accessible(client):
    """Test that API docs are accessible."""
    response = client.get("/docs")
    assert response.status_code == 200


def test_predict_validates_input(client):
    """Test that prediction endpoint validates input."""
    # Missing required fields
    response = client.post("/predict", json={"f_0": 1.5})
    assert response.status_code == 422  # Validation error


def test_predict_accepts_valid_input(client):
    """Test that prediction endpoint accepts valid input format."""
    payload = {
        "f_0": 1.5,
        "f_1": 2.3,
        "f_2": 0.8,
        "f_3": -0.5,
        "f_4": 1.2,
        "months_since_signup": 12,
        "calendar_month": 6,
        "signup_month": 6,
        "is_first_month": 0,
    }
    response = client.post("/predict", json=payload)
    # Don't assert 200 since model might not load, just check it's valid FastAPI response
    assert response.status_code in [200, 503]  # 503 = model not loaded


def test_batch_predict_accepts_list(client):
    """Test that batch endpoint accepts list of inputs."""
    payload = [
        {
            "f_0": 1.5,
            "f_1": 2.3,
            "f_2": 0.8,
            "f_3": -0.5,
            "f_4": 1.2,
            "months_since_signup": 12,
            "calendar_month": 6,
            "signup_month": 6,
            "is_first_month": 0,
        }
    ]
    response = client.post("/predict/batch", json=payload)
    assert response.status_code in [200, 503]


def test_predict_rejects_invalid_types(client):
    """Test that endpoint rejects wrong data types."""
    payload = {
        "f_0": "not_a_number",  # Should be float
        "f_1": 2.3,
        "f_2": 0.8,
        "f_3": -0.5,
        "f_4": 1.2,
        "months_since_signup": 12,
        "calendar_month": 6,
        "signup_month": 6,
        "is_first_month": 0,
    }
    response = client.post("/predict", json=payload)
    assert response.status_code == 422  # Validation error
