"""Deterministic score calculation, separate from LLM extraction and generation."""

from collections.abc import Mapping

from src.evaluation.rubric import get_rubric_weights
from src.schemas.candidate_scorecard import EvaluationDimension


def calculate_weighted_score(
    ratings: Mapping[EvaluationDimension, int | None],
) -> float | None:
    """Calculate a 0–100 weighted score, or None when any dimension is unknown.

    All rubric dimensions must be present. Ratings must be integers from 1 to 5;
    booleans are rejected even though bool is a subclass of int in Python.
    """
    weights = get_rubric_weights()

    if set(ratings) != set(weights):
        missing = set(weights) - set(ratings)
        extra = set(ratings) - set(weights)
        raise ValueError(
            f"Ratings must cover every rubric dimension exactly; "
            f"missing={sorted(item.value for item in missing)}, "
            f"extra={sorted(str(item) for item in extra)}"
        )

    unknown = [dimension for dimension, rating in ratings.items() if rating is None]
    if unknown:
        return None

    total = 0.0
    for dimension, rating in ratings.items():
        if isinstance(rating, bool) or not isinstance(rating, int):
            raise ValueError(f"Rating for {dimension.value} must be an integer from 1 to 5.")
        if not 1 <= rating <= 5:
            raise ValueError(f"Rating for {dimension.value} must be between 1 and 5.")
        total += weights[dimension] * (rating / 5.0) * 100.0

    return round(total, 2)
