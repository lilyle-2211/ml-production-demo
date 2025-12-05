"""Test script for the FastAPI inference service."""
import json

import requests

# API endpoint
BASE_URL = "http://localhost:8000"


def test_health():
    """Test health endpoint."""
    print("\n=== Testing Health Endpoint ===")
    response = requests.get(f"{BASE_URL}/health")
    print(f"Status Code: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    return response.status_code == 200


def test_single_prediction():
    """Test single prediction endpoint."""
    print("\n=== Testing Single Prediction ===")

    # Sample input
    input_data = {
        "f_0": 0.5,
        "f_1": 0.3,
        "f_2": 0.8,
        "f_3": 0.2,
        "f_4": 0.6,
        "months_since_signup": 12,
        "calendar_month": 6,
        "signup_month": 6,
        "is_first_month": 0,
    }

    response = requests.post(f"{BASE_URL}/predict", json=input_data)

    print(f"Status Code: {response.status_code}")
    print(f"Request: {json.dumps(input_data, indent=2)}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    return response.status_code == 200


def test_batch_prediction():
    """Test batch prediction endpoint."""
    print("\n=== Testing Batch Prediction ===")

    # Sample batch input
    batch_data = {
        "instances": [
            {
                "f_0": 0.5,
                "f_1": 0.3,
                "f_2": 0.8,
                "f_3": 0.2,
                "f_4": 0.6,
                "months_since_signup": 12,
                "calendar_month": 6,
                "signup_month": 6,
                "is_first_month": 0,
            },
            {
                "f_0": 0.2,
                "f_1": 0.7,
                "f_2": 0.4,
                "f_3": 0.9,
                "f_4": 0.3,
                "months_since_signup": 3,
                "calendar_month": 3,
                "signup_month": 12,
                "is_first_month": 1,
            },
        ]
    }

    response = requests.post(f"{BASE_URL}/predict/batch", json=batch_data)

    print(f"Status Code: {response.status_code}")
    print(f"Number of instances: {len(batch_data['instances'])}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    return response.status_code == 200


def main():
    """Run all tests."""
    print("Starting API tests...")

    tests = [
        ("Health Check", test_health),
        ("Single Prediction", test_single_prediction),
        ("Batch Prediction", test_batch_prediction),
    ]

    results = []
    for name, test_func in tests:
        try:
            success = test_func()
            results.append((name, "✓ PASSED" if success else "✗ FAILED"))
        except Exception as e:
            print(f"Error: {e}")
            results.append((name, f"✗ ERROR: {str(e)}"))

    print("\n=== Test Summary ===")
    for name, result in results:
        print(f"{name}: {result}")


if __name__ == "__main__":
    main()
