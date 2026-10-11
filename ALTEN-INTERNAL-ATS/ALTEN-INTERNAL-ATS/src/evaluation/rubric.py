"""Versioned, deterministic FDE candidate-evaluation rubric.

Weights are proposed defaults for the lab, not an official ALTEN policy.
"""

from dataclasses import dataclass

from src.schemas.candidate_scorecard import EvaluationDimension


@dataclass(frozen=True)
class RubricCriterion:
    dimension: EvaluationDimension
    weight: float
    description: str
    evidence_expectations: tuple[str, ...]


RUBRIC_VERSION = "hr-disc-2-v1"

RUBRIC: tuple[RubricCriterion, ...] = (
    RubricCriterion(
        dimension=EvaluationDimension.TECHNICAL_CORE,
        weight=0.35,
        description="Python, SQL, REST APIs, testing, and software engineering.",
        evidence_expectations=(
            "Concrete Python implementation or maintenance example",
            "SQL and relational data handling",
            "REST API design or integration",
            "Testing and engineering practices",
        ),
    ),
    RubricCriterion(
        dimension=EvaluationDimension.SOLUTION_DELIVERY_ARCHITECTURE,
        weight=0.25,
        description="Requirements translation, architecture, integration, and operations.",
        evidence_expectations=(
            "Requirements translated into an implementable solution",
            "Design decisions and trade-offs explained",
            "Enterprise integration or deployment",
            "Reliability, observability, or maintenance",
        ),
    ),
    RubricCriterion(
        dimension=EvaluationDimension.CLIENT_FACING_FDE,
        weight=0.20,
        description="Discovery, ambiguity management, stakeholder communication, and adoption.",
        evidence_expectations=(
            "Stakeholder discovery or requirements workshop",
            "Communication with technical and non-technical stakeholders",
            "Delivery in an ambiguous client environment",
            "Adoption or measurable delivery outcome",
        ),
    ),
    RubricCriterion(
        dimension=EvaluationDimension.BILINGUAL_PROFICIENCY,
        weight=0.10,
        description="Role-relevant professional communication in French and English.",
        evidence_expectations=(
            "Evidence of professional communication in French",
            "Evidence of professional communication in English",
        ),
    ),
    RubricCriterion(
        dimension=EvaluationDimension.RELEVANT_EXPERIENCE,
        weight=0.10,
        description="Relevance, scope, complexity, and ownership of prior engineering work.",
        evidence_expectations=(
            "Relevant engineering or delivery responsibilities",
            "Scope and complexity of owned work",
            "Concrete contribution or outcome",
        ),
    ),
)


def validate_rubric() -> None:
    """Raise ValueError if rubric dimensions or weights are invalid."""
    dimensions = [criterion.dimension for criterion in RUBRIC]
    if len(dimensions) != len(set(dimensions)):
        raise ValueError("Rubric dimensions must be unique.")

    if set(dimensions) != set(EvaluationDimension):
        raise ValueError("Rubric must define every EvaluationDimension exactly once.")

    if any(criterion.weight <= 0 for criterion in RUBRIC):
        raise ValueError("Every rubric weight must be positive.")

    if abs(sum(criterion.weight for criterion in RUBRIC) - 1.0) > 1e-9:
        raise ValueError("Rubric weights must sum to 1.0.")


def get_rubric_weights() -> dict[EvaluationDimension, float]:
    """Return a fresh mapping of dimension to approved-in-this-build weight."""
    validate_rubric()
    return {criterion.dimension: criterion.weight for criterion in RUBRIC}
