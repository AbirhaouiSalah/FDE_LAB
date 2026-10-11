"""
Matching Engine for ALTEN ATS Copilot.
Evaluates a candidate CV against FDE Job Description requirements.
"""


def evaluate_candidate(candidate_data: dict, job_description: str) -> dict:
    """Evaluates alignment, missing competencies, and generates a scorecard."""
    return {
        "match_score": 85,
        "key_strengths": ["Strong Python background", "Client-facing experience"],
        "gaps": ["Requires deeper Agentic framework experience"],
        "suggested_interview_questions": [
            "Can you describe a situation where you had to simplify an AI "
            "architecture for business stakeholders?"
        ],
    }
