import pytest

from src.evaluation.rubric import RUBRIC, get_rubric_weights, validate_rubric
from src.schemas.candidate_scorecard import EvaluationDimension


def test_rubric_weights_sum_to_one():
    validate_rubric()
    assert sum(criterion.weight for criterion in RUBRIC) == pytest.approx(1.0)


def test_rubric_covers_every_dimension_once():
    dimensions = [criterion.dimension for criterion in RUBRIC]
    assert len(dimensions) == len(set(dimensions))
    assert set(dimensions) == set(EvaluationDimension)


def test_expected_proposed_weights():
    weights = get_rubric_weights()
    assert weights[EvaluationDimension.TECHNICAL_CORE] == pytest.approx(0.35)
    assert weights[EvaluationDimension.SOLUTION_DELIVERY_ARCHITECTURE] == pytest.approx(0.25)
    assert weights[EvaluationDimension.CLIENT_FACING_FDE] == pytest.approx(0.20)
    assert weights[EvaluationDimension.BILINGUAL_PROFICIENCY] == pytest.approx(0.10)
    assert weights[EvaluationDimension.RELEVANT_EXPERIENCE] == pytest.approx(0.10)
