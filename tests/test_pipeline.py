# tests/test_pipeline.py
import pytest
from pathlib import Path
from src.pipeline.schemas import CandidateProfile, ExperienceItem
from src.pipeline.extractor import PDFResumeExtractor

def test_candidate_profile_schema():
    """Verify that Pydantic validates valid candidate data correctly."""
    data = {
        "full_name": "Alice Dupont",
        "email": "alice.dupont@alten.com",
        "skills": ["Python", "Docker", "Kubernetes"],
        "source_file": "alice_resume.pdf"
    }
    profile = CandidateProfile(**data)
    assert profile.full_name == "Alice Dupont"
    assert "Python" in profile.skills
    assert profile.source_file == "alice_resume.pdf"

def test_text_cleaner_logic():
    """Verify private text cleaning method removes messy artifacts."""
    messy_text = "  Senior\xa0FDE   Engineer \n\n\n Python Developer  "
    cleaned = PDFResumeExtractor._clean_text(messy_text)
    assert cleaned == "Senior FDE Engineer\n\nPython Developer"