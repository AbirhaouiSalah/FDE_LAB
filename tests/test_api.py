# tests/test_api.py
from fastapi.testclient import TestClient
from src.api.main import app

client = TestClient(app)

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy", "service": "alten-ats-copilot"}

def test_upload_resume_invalid_file():
    # Test uploading a non-PDF file
    response = client.post(
        "/api/v1/resumes/upload",
        files={"file": ("test.txt", b"some random text content", "text/plain")}
    )
    assert response.status_code == 400
    assert "Only PDF files are supported" in response.json()["detail"]