"""
REST API (FastAPI) for ATS / HR integration.
Run with: uvicorn src.api.main:app --reload
"""
from fastapi import FastAPI

from src.evaluator.matcher import evaluate_candidate
from src.parser.resume_parser import parse_resume

app = FastAPI(title="ALTEN ATS Copilot")


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/evaluate")
def evaluate(job_description: str = "") -> dict:
    parsed = parse_resume("dummy_path")
    return evaluate_candidate(parsed, job_description)
