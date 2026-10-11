"""Pydantic schemas for the HR-DISC candidate evaluation scorecard.

The rubric is a lab proposal and must be approved before operational use.
This module validates scorecard structure; it does not make hiring decisions.
"""

from __future__ import annotations

from enum import Enum
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, model_validator


class EvaluationDimension(str, Enum):
    TECHNICAL_CORE = "technical_core"
    SOLUTION_DELIVERY_ARCHITECTURE = "solution_delivery_architecture"
    CLIENT_FACING_FDE = "client_facing_fde"
    BILINGUAL_PROFICIENCY = "bilingual_proficiency"
    RELEVANT_EXPERIENCE = "relevant_experience"


class EvaluationStatus(str, Enum):
    COMPLETE = "complete"
    PROVISIONAL = "provisional"
    NEEDS_HUMAN_REVIEW = "needs_human_review"


Rating = Annotated[int, Field(ge=1, le=5)]


class EvidenceItem(BaseModel):
    """A source-backed piece of evidence for a criterion."""

    model_config = ConfigDict(extra="forbid")

    excerpt: str = Field(min_length=1, description="Short excerpt from source material.")
    source: str = Field(min_length=1, description="Source document or assessment identifier.")
    location: str | None = Field(
        default=None,
        description="Optional page, section, or character range in the source.",
    )
    verified: bool = Field(
        default=False,
        description="Whether a human or approved validation process verified this evidence.",
    )


class CriterionAssessment(BaseModel):
    """Assessment of one dimension; unknown means evidence is insufficient."""

    model_config = ConfigDict(extra="forbid")

    dimension: EvaluationDimension
    rating: Rating | None = Field(
        default=None,
        description="Rating from 1 to 5, or null when evidence is insufficient.",
    )
    evidence: list[EvidenceItem] = Field(default_factory=list)
    rationale: str = Field(
        min_length=1,
        description="Evidence-based explanation; distinguish facts from inference.",
    )
    follow_up_question: str | None = None


class CandidateScorecard(BaseModel):
    """Structured evaluation output for human review."""

    model_config = ConfigDict(extra="forbid")

    candidate_reference: str = Field(
        min_length=1,
        description="Pseudonymous reference; avoid embedding unnecessary personal data.",
    )
    rubric_version: str = Field(default="hr-disc-2-v1", min_length=1)
    assessments: list[CriterionAssessment]
    status: EvaluationStatus
    weighted_score: float | None = Field(default=None, ge=0, le=100)
    human_review_required: bool = True
    missing_dimensions: list[EvaluationDimension] = Field(default_factory=list)

    @model_validator(mode="after")
    def validate_scorecard_consistency(self) -> "CandidateScorecard":
        dimensions = [assessment.dimension for assessment in self.assessments]
        if len(dimensions) != len(set(dimensions)):
            raise ValueError("Each evaluation dimension must appear at most once.")

        unknown_dimensions = {
            assessment.dimension
            for assessment in self.assessments
            if assessment.rating is None
        }
        declared_missing = set(self.missing_dimensions)

        if unknown_dimensions != declared_missing:
            raise ValueError(
                "missing_dimensions must exactly match assessments with unknown ratings."
            )

        if unknown_dimensions and self.weighted_score is not None:
            raise ValueError(
                "weighted_score must be null when any dimension has an unknown rating."
            )

        if unknown_dimensions and self.status == EvaluationStatus.COMPLETE:
            raise ValueError("A scorecard with unknown ratings cannot be complete.")

        if not self.human_review_required:
            raise ValueError("Candidate scorecards must require human review.")

        return self
