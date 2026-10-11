import pytest

from src.evaluation.scoring import calculate_weighted_score
from src.schemas.candidate_scorecard import EvaluationDimension


ALL_DIMENSIONS = list(EvaluationDimension)


def ratings_with(value: int | None) -> dict[EvaluationDimension, int | None]:
    return {dimension: value for dimension in ALL_DIMENSIONS}


def test_all_fives_produce_100():
    assert calculate_weighted_score(ratings_with(5)) == pytest.approx(100.0)


def test_all_ones_produce_20():
    assert calculate_weighted_score(ratings_with(1)) == pytest.approx(20.0)


def test_mixed_ratings_are_deterministic():
    ratings = {
        EvaluationDimension.TECHNICAL_CORE: 4,
        EvaluationDimension.SOLUTION_DELIVERY_ARCHITECTURE: 3,
        EvaluationDimension.CLIENT_FACING_FDE: 5,
        EvaluationDimension.BILINGUAL_PROFICIENCY: 4,
        EvaluationDimension.RELEVANT_EXPERIENCE: 3,
    }
    assert calculate_weighted_score(ratings) == pytest.approx(77.0)


def test_unknown_rating_makes_score_provisional():
    ratings = ratings_with(4)
    ratings[EvaluationDimension.BILINGUAL_PROFICIENCY] = None
    assert calculate_weighted_score(ratings) is None


@pytest.mark.parametrize("invalid_rating", [0, 6, -1, 2.5, True, "4"])
def test_invalid_rating_is_rejected(invalid_rating):
    ratings = ratings_with(3)
    ratings[EvaluationDimension.TECHNICAL_CORE] = invalid_rating
    with pytest.raises(ValueError):
        calculate_weighted_score(ratings)


def test_missing_dimension_is_rejected():
    ratings = ratings_with(3)
    ratings.pop(EvaluationDimension.TECHNICAL_CORE)
    with pytest.raises(ValueError, match="cover every rubric dimension"):
        calculate_weighted_score(ratings)


def test_extra_dimension_is_rejected():
    ratings = ratings_with(3)
    ratings["unknown_dimension"] = 3  # type: ignore[index]
    with pytest.raises(ValueError, match="cover every rubric dimension"):
        calculate_weighted_score(ratings)
