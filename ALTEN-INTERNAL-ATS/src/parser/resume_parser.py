"""
Resume Parsing module for ALTEN ATS Copilot.
Extracts structured text and entities from CVs.
"""


def parse_resume(file_path: str) -> dict:
    """Mock parser to be implemented with LLM / structured outputs."""
    return {
        "candidate_name": "Sample Candidate",
        "skills": ["Python", "APIs", "Stakeholder Management"],
        "raw_text": "Sample content...",
    }
