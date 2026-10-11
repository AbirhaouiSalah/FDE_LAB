from src.evaluator.matcher import evaluate_candidate
from src.parser.resume_parser import parse_resume


def test_pipeline_basic_flow():
    parsed = parse_resume("dummy_path")
    result = evaluate_candidate(parsed, "dummy_jd")
    assert "match_score" in result
    assert result["match_score"] > 0
