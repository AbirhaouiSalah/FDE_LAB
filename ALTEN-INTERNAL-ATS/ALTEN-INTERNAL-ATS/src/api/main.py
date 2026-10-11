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
    return evaluate_candidate(parsed, job_description)# src/api/main.py
from fastapi import FastAPI, HTTPException, UploadFile, File
from pathlib import Path
import shutil
from src.pipeline.schemas import CandidateProfile

app = FastAPI(
    title="ALTEN Internal ATS & Candidate Evaluation Copilot",
    version="1.0.0",
    description="FDE GenAI Platform for automated resume ingestion and candidate evaluation."
)

UPLOAD_DIR = Path("tests/fixtures/raw_resumes")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

@app.get("/health", tags=["System"])
def health_check():
    return {"status": "healthy", "service": "alten-ats-copilot"}

@app.post("/api/v1/resumes/upload", response_model=CandidateProfile, tags=["Ingestion"])
async def upload_resume(file: UploadFile = File(...)):
    """Upload a raw PDF resume, save it to the ingestion staging area, and return parsed metadata."""
    if not file.filename.endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Only PDF files are supported.")
    
    file_path = UPLOAD_DIR / file.filename
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    # Stub response matching schema (ready for full LLM parser hookup)
    return CandidateProfile(
        full_name="Extracted Candidate (Pending AI Parse)",
        email=None,
        phone=None,
        location=None,
        summary="Uploaded successfully via API gateway.",
        skills=["Pending Extraction"],
        source_file=file.filename
    )
