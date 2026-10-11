#!/usr/bin/env bash
set -Eeuo pipefail

# Generate Epic 1 (HR-DISC) artifacts for alten-internal-ats-copilot.
# By default, existing files are preserved. Set OVERWRITE=1 to replace them.
#
# Usage:
#   chmod +x scripts/generate_hr_disc_artifacts.sh
#   ./scripts/generate_hr_disc_artifacts.sh
#   OVERWRITE=1 ./scripts/generate_hr_disc_artifacts.sh
#
# Optional:
#   PROJECT_ROOT=/path/to/alten-internal-ats-copilot ./scripts/generate_hr_disc_artifacts.sh

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
OVERWRITE="${OVERWRITE:-0}"

if [[ ! -d "$PROJECT_ROOT" ]]; then
  printf 'Error: project root does not exist: %s\n' "$PROJECT_ROOT" >&2
  exit 1
fi

write_file() {
  local relative_path="$1"
  local target="$PROJECT_ROOT/$relative_path"
  local parent
  parent="$(dirname "$target")"
  mkdir -p "$parent"

  if [[ -e "$target" && "$OVERWRITE" != "1" ]]; then
    printf 'SKIP  %s (already exists; set OVERWRITE=1 to replace)\n' "$relative_path"
    return
  fi

  cat > "$target"
  printf 'WRITE %s\n' "$relative_path"
}

write_file "docs/hr-discovery/HR-DISC-1-pain-points.md" <<'EOF'
# HR-DISC-1 — Map HR Recruiter & Hiring Manager Pain Points

**Epic:** HR Discovery & Scoping  
**Status:** Draft — stakeholder validation required  
**Use case:** AI-powered ATS and Candidate Evaluation Copilot for FDE recruitment

## 1. Objective

Document the current recruitment workflow for high-volume technical roles, identify screening bottlenecks, and establish an evidence-based baseline for the target of reducing initial technical pre-screening time per candidate by 50%.

> Important: The pain points in this document are discovery hypotheses for the lab, not confirmed statements about ALTEN's internal HR operations. Validate them with recruiters, hiring managers, HR operations, IT, and security stakeholders.

## 2. Hypothesized current-state workflow

1. **Application intake:** CVs arrive through job boards, referrals, direct applications, and other channels.
2. **Initial CV screening:** A recruiter reviews relevant experience, skills, language proficiency, and role alignment.
3. **Technical pre-screening:** The recruiter or technical stakeholder identifies evidence of relevant technical capabilities.
4. **Hiring-manager review:** Shortlisted profiles are reviewed for solution-delivery and client-facing fit.
5. **Interview preparation:** Findings are consolidated and interview questions are prepared.

During discovery, confirm which steps exist, what the current ATS already automates, where data is stored, and who owns each decision.

## 3. Pain-point register

| ID | Hypothesized pain point | Potential consequence | Evidence to collect |
|---|---|---|---|
| PP-01 | High volume of inbound applications | Large manual screening workload | Applications per role and per week |
| PP-02 | CV information is unstructured | Time spent extracting relevant evidence | Median and mean review time per CV |
| PP-03 | Technical skills are interpreted inconsistently | Variable shortlist quality | Differences between independent reviewers |
| PP-04 | Evidence is difficult to compare | Hiring managers reread CVs | Review time per forwarded candidate |
| PP-05 | Interview preparation is repetitive | Recruiters recreate similar questions | Preparation time per shortlisted candidate |
| PP-06 | Decisions have limited traceability | Harder to explain or audit decisions | Share of decisions with recorded evidence |
| PP-07 | Language or delivery evidence is unclear | Additional clarification cycles | Follow-up rate for missing information |

Prioritize pain points by frequency, business impact, and feasibility. Do not assume every hypothesis is true.

## 4. Stakeholder discovery questions

### Recruiters

- How many applications arrive per FDE opening and per week?
- What is the current screening process, and how much active time does each step require?
- Which CV fields or skills are hardest to assess consistently?
- How often do hiring managers ask for additional information?
- Which functions does the current ATS already provide?
- Which decisions must remain exclusively with a human reviewer?

### Hiring managers and technical interviewers

- What distinguishes an effective FDE from a conventional software engineer in this role?
- Which skills must be demonstrated rather than merely listed?
- How do you assess problem discovery, requirements translation, and client communication?
- What evidence indicates that a candidate can deliver and maintain an enterprise solution?
- What information would make a candidate summary useful without replacing review of the source CV?

### HR operations, IT, and security

- Which ATS integration mechanisms and authentication methods are available?
- Where may CVs be processed and stored?
- What are the retention, deletion, access-control, and audit requirements?
- Which LLM providers, if any, are approved for personal data?
- How should recommendations be explained, corrected, and challenged?

## 5. KPI: 50% reduction in initial technical pre-screening time

### Definition

Measure active recruiter time required to complete an initial technical pre-screening, including reviewing the CV, checking extracted evidence, correcting errors, and recording the screening outcome.

Let:

- `T_baseline` = baseline mean active screening time per candidate without the copilot.
- `T_assisted` = mean active screening time per candidate using the copilot, including verification and corrections.

```text
time_reduction_percent =
    ((T_baseline - T_assisted) / T_baseline) * 100
```

**Target:** `time_reduction_percent >= 50%`, equivalently `T_assisted <= 0.5 * T_baseline`.

Illustration only: if the validated baseline is 20 minutes, the target is 10 minutes or less. This is not a measured ALTEN result.

### Measurement protocol

1. Agree on the exact start and end points of a screening task.
2. Measure a representative baseline sample using the current workflow.
3. Measure assisted screening using the same task definition and comparable candidate profiles.
4. Include recruiter verification, correction, and documentation time in assisted measurements.
5. Record reviewer experience, CV complexity, incomplete data, and interruptions where feasible.
6. Report sample size, mean, median, dispersion, and any material differences between cohorts.
7. Pair time reduction with quality, correction rate, adoption, and safety guardrails.

Avoid attributing improvements to the copilot when candidate complexity or reviewer experience differs materially between comparison groups.

## 6. Guardrail metrics

- **Quality:** human-reviewed screening quality must not materially deteriorate.
- **Traceability:** recommendations should cite evidence from the candidate's source material.
- **Human oversight:** no automatic rejection based solely on an AI-generated score.
- **Correction rate:** record how often reviewers amend extracted facts or scores.
- **Adoption:** measure the percentage of eligible screenings completed with the copilot.
- **Privacy:** enforce approved processing, access, retention, and deletion requirements.

## 7. Acceptance criteria

- [ ] Current-state workflow validated with relevant stakeholders or explicitly marked as provisional.
- [ ] Pain points prioritized using evidence of frequency and impact.
- [ ] Baseline and assisted-time measurement protocols agreed.
- [ ] Formula for the 50% target documented and testable.
- [ ] Quality, traceability, human-review, and privacy guardrails agreed.
- [ ] Assumptions, owners, and open questions recorded.

## 8. Open questions

| Question | Owner | Status |
|---|---|---|
| What is the actual application volume per FDE opening? | HR | Open |
| What is the measured baseline screening time? | HR / Product | Open |
| Which ATS and integration interfaces are available? | HR IT | Open |
| Which model and hosting options are approved? | IT / Security | Open |
| What quality metric will be used to guard against faster but worse screening? | HR / Hiring Manager | Open |
EOF

write_file "docs/hr-discovery/HR-DISC-1-kpi-baseline.md" <<'EOF'
# HR-DISC-1 — KPI Baseline and Measurement Protocol

**Status:** Proposal — requires stakeholder approval  
**Primary KPI:** Reduction in active initial technical pre-screening time per candidate  
**Target:** At least 50%

## 1. Operational definition

Count active recruiter time spent completing the agreed initial technical pre-screening task.

Include:
- Reviewing the CV and relevant candidate information.
- Inspecting the copilot's extracted evidence and summary, if used.
- Correcting extraction errors or unsupported claims.
- Recording the screening outcome and rationale.

Exclude unrelated administrative delays and time spent waiting for external systems, unless the business explicitly chooses to include them. Apply the same boundary to baseline and assisted measurements.

## 2. Formula

Let:

- `T_baseline` = mean active minutes per candidate under the current workflow.
- `T_assisted` = mean active minutes per candidate with the copilot.

```text
reduction_percent = 100 * (T_baseline - T_assisted) / T_baseline
target_met = reduction_percent >= 50
```

The baseline must be greater than zero. If it is zero or unavailable, the KPI cannot be calculated and must be reported as undefined.

## 3. Data collection plan

For every measured screening, capture:

| Field | Description |
|---|---|
| measurement_id | Pseudonymous measurement record ID |
| workflow | `baseline` or `assisted` |
| active_minutes | Active screening time, numeric and non-negative |
| cv_complexity | Agreed categorical complexity label |
| reviewer_experience | Agreed reviewer-experience category |
| corrections_count | Number of corrections to extracted information |
| review_outcome | Outcome category, recorded according to the approved process |
| quality_review | Result of a defined human quality check, where available |
| measurement_notes | Minimal non-sensitive notes about measurement anomalies |

Do not duplicate CV contents or unnecessary personal data into the KPI dataset. Define access and retention controls before collection.

## 4. Comparison method

1. Define a common screening task and completion criteria.
2. Collect a representative baseline sample.
3. Collect assisted-workflow measurements on comparable tasks.
4. Prefer paired or stratified comparisons where operationally feasible.
5. Report mean and median active time, sample size, distribution, and uncertainty.
6. Examine differences in candidate complexity, reviewer experience, and missing data.
7. Review screening quality, correction rate, and safety outcomes alongside time savings.

A pilot result should not be presented as causal proof unless the evaluation design supports that conclusion.

## 5. Reporting template

| Metric | Baseline | Assisted | Result |
|---|---:|---:|---:|
| Sample size | TBD | TBD | — |
| Mean active minutes per screen | TBD | TBD | TBD |
| Median active minutes per screen | TBD | TBD | TBD |
| Correction rate | TBD | TBD | TBD |
| Quality-review result | TBD | TBD | TBD |
| Time reduction | — | — | TBD |
| 50% target achieved | — | — | TBD |

## 6. Acceptance criteria

- [ ] Screening start and end points agreed.
- [ ] Baseline sample is representative enough for the intended pilot.
- [ ] Assisted time includes human verification and corrections.
- [ ] Formula handles zero or missing baseline safely.
- [ ] Mean, median, sample size, and quality guardrails are reported.
- [ ] Data minimization and access controls are documented.
EOF

write_file "docs/hr-discovery/HR-DISC-2-evaluation-rubric.md" <<'EOF'
# HR-DISC-2 — FDE Candidate Evaluation Rubric

**Status:** Draft for HR and hiring-manager validation  
**Use case:** Candidate Evaluation Copilot for FDE recruitment  
**Important:** The weights and criteria below are a proposed lab rubric, not an official ALTEN hiring policy.

## 1. Evaluation principles

1. Assess job-related evidence rather than writing style or subjective impressions.
2. Distinguish demonstrated capability from a skill merely listed on a CV.
3. Treat missing evidence as unknown, not automatically as evidence of incompetence.
4. Use consistent rating anchors for every candidate.
5. Make each assessment traceable to source evidence or a structured assessment result.
6. Keep hiring decisions under accountable human review.
7. Do not infer protected or sensitive personal characteristics.
8. Validate the rubric for job relevance, consistency, and disparate impact before operational use.

## 2. Proposed dimensions and weights

| Dimension | Weight | Evidence sought |
|---|---:|---|
| Technical core | 35% | Python, SQL, REST APIs, testing, software engineering |
| Solution delivery and architecture | 25% | Requirements translation, design trade-offs, integration, reliability, deployment and maintenance |
| Client-facing FDE capabilities | 20% | Discovery, ambiguity management, stakeholder communication, iteration and adoption |
| French and English proficiency | 10% | Role-relevant professional communication in both languages |
| Relevant professional experience | 10% | Scope, complexity, ownership and relevance of engineering and delivery work |
| **Total** | **100%** | |

Weights are provisional and should be approved by the hiring manager before they are used to rank or compare candidates.

## 3. Common rating scale

| Rating | Label | Anchor |
|---:|---|---|
| 1 | No demonstrated evidence | Available evidence does not establish the capability |
| 2 | Limited | Basic exposure, with limited practical examples |
| 3 | Meets expected level | Relevant practical example demonstrating the capability |
| 4 | Strong | Multiple relevant examples showing ownership and sound decisions |
| 5 | Exceptional | Deep, independently demonstrated expertise and strong trade-off reasoning |

Use `unknown` when evidence is insufficient to rate fairly. Do not convert unknown to zero or silently redistribute its weight.

## 4. Dimension-specific guidance

### A. Technical core — 35%

Assess evidence of:
- Python implementation, modularity, error handling, and maintainability.
- SQL queries, relational data modelling, joins, transactions, and data integrity.
- REST API design, validation, status codes, authentication, and integration.
- Testing, Git, CI/CD, debugging, and engineering practices.

CV evidence is preliminary. Verify depth through a structured technical interview or coding exercise.

### B. Solution delivery and architecture — 25%

Assess evidence of:
- Translating ambiguous requirements into implementable specifications.
- Designing components and interfaces with explicit trade-offs.
- Integrating with existing enterprise systems.
- Addressing deployment, observability, reliability, and maintenance.
- Explaining the rationale and consequences of design decisions.

### C. Client-facing FDE capabilities — 20%

Assess evidence of:
- Leading discovery and requirements workshops.
- Explaining technical constraints to non-technical stakeholders.
- Iterating in real client environments.
- Handling conflicting priorities and ambiguity.
- Supporting adoption and communicating delivery outcomes.

### D. French and English proficiency — 10%

Assess role-relevant communication in both languages:
- Explaining technical decisions clearly.
- Participating in or leading client meetings.
- Writing understandable technical documentation.

Use equivalent tasks and consistent rating anchors across languages. Do not infer language proficiency from nationality or name.

### E. Relevant professional experience — 10%

Assess the relevance, scope, complexity, and ownership of prior work. Do not reward employer prestige or raw tenure as a substitute for demonstrated capability.

## 5. Experience range: 4–10 years

The 4–10-year range is a proposed role requirement and must be validated by the hiring manager. If approved, represent it as a separate, explicit eligibility or review criterion rather than automatically giving more points to candidates with more years.

Do not silently reject candidates outside the range. Record the relevant evidence and route ambiguous cases to human review. Evaluate part-time work, overlapping roles, career breaks, and other non-standard histories consistently.

## 6. Scoring

For fully rated dimensions, where weights sum to 1 and each rating is from 1 to 5:

```text
weighted_score = sum(weight_i * rating_i / 5) * 100
```

The result is between 20 and 100 if all dimensions have ratings in the range 1–5 and weights sum to 1. If a different score range is desired, explicitly define it rather than changing the formula implicitly.

If any required dimension is unknown:
- Mark the overall score as provisional.
- List the missing evidence.
- Do not treat unknown as zero.
- Do not redistribute weights unless an approved scoring policy explicitly defines that behavior.
- Route the profile for clarification or human assessment.

The score is a decision-support signal, not a definitive measure of candidate quality and not an automatic rejection mechanism.

## 7. Evidence and traceability

Each assessed criterion should record:
- Criterion identifier.
- Rating or `unknown`.
- Evidence excerpt or reference to source material.
- Evidence source and location, where available.
- Confidence or verification status, clearly distinguished from the rating.
- Missing information and suggested follow-up question.
- Human reviewer correction or override, with rationale where required.

Do not let an LLM invent evidence. Generated summaries must remain consistent with the source CV and clearly identify uncertainty.

## 8. Human review and responsible use

- No automatic rejection solely on the basis of an AI-generated score.
- Recruiters must be able to inspect and correct extracted evidence.
- Record score changes and review decisions according to approved audit requirements.
- Minimize personal data and define retention and deletion rules.
- Treat CV text as untrusted input; protect the system against prompt injection.
- Validate job relevance and monitor for systematic differences in outcomes.
- Obtain legal, HR, privacy, and security review before operational deployment.

## 9. Approval checklist

- [ ] Dimensions reflect validated FDE job requirements.
- [ ] Weights approved by the hiring manager.
- [ ] Rating anchors accepted by reviewers.
- [ ] Treatment of missing evidence agreed.
- [ ] Experience-range requirement validated.
- [ ] Human-review and override process defined.
- [ ] Privacy, security, and fairness checks agreed.
EOF

write_file "docs/hr-discovery/HR-DISC-2-acceptance-criteria.md" <<'EOF'
# HR-DISC-2 — Evaluation Rubric Acceptance Criteria

**Status:** Draft  
**Purpose:** Define testable conditions before implementing candidate scoring.

## Functional criteria

- [ ] The rubric contains the five approved dimensions and weights sum to exactly 1.0 (100%).
- [ ] Each dimension has a documented description and evidence expectations.
- [ ] Ratings are restricted to integers from 1 through 5, or explicitly marked unknown.
- [ ] Evidence excerpts or references are retained for assessed criteria.
- [ ] Missing evidence is not silently converted to a zero rating.
- [ ] An overall score is provisional when a required dimension is unknown.
- [ ] Scores are deterministic for the same validated ratings and rubric version.
- [ ] Invalid weights, invalid ratings, and malformed scorecard data are rejected.
- [ ] Score calculation is separate from LLM extraction and narrative generation.
- [ ] The scorecard records rubric version and evaluation status.

## Human-review criteria

- [ ] The reviewer can inspect the evidence supporting each rating.
- [ ] The reviewer can identify missing evidence and request clarification.
- [ ] The reviewer can correct an extraction or rating.
- [ ] Overrides can be recorded with reviewer identity and rationale according to the approved audit policy.
- [ ] The system does not automatically reject candidates solely on the AI score.

## Quality and security criteria

- [ ] Tests cover score bounds, weight totals, invalid inputs, and missing evidence.
- [ ] Tests verify that unsupported evidence is not fabricated by the deterministic scoring layer.
- [ ] CV content is treated as untrusted input, including possible prompt-injection instructions.
- [ ] Personal data is minimized in logs and test fixtures.
- [ ] Privacy, retention, access-control, and deletion requirements are documented.
- [ ] The rubric is reviewed for job relevance and potential disparate impact before production use.

## KPI criteria

- [ ] The initial-screening time baseline is defined and measured.
- [ ] Assisted screening time includes reviewer verification and correction.
- [ ] The 50% reduction formula is implemented or independently reproducible.
- [ ] Quality and safety guardrails are reported alongside time reduction.

## Definition of Done

The rubric is ready for implementation when HR and the hiring manager have approved its dimensions, weights, evidence requirements, treatment of unknown information, and human-review process. Until then, it remains a lab proposal.
EOF

write_file "src/schemas/candidate_scorecard.py" <<'EOF'
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
EOF

write_file "src/evaluation/rubric.py" <<'EOF'
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
EOF

write_file "src/evaluation/scoring.py" <<'EOF'
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
EOF

write_file "tests/evaluation/test_rubric.py" <<'EOF'
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
EOF

write_file "tests/evaluation/test_scoring.py" <<'EOF'
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
EOF

printf '\nEpic 1 artifact generation finished.\n'
printf 'Project root: %s\n' "$PROJECT_ROOT"
printf 'Overwrite existing files: %s\n' "$OVERWRITE"
printf '\nSuggested next steps:\n'
printf '  1. Ensure src/evaluation/__init__.py, src/schemas/__init__.py, and tests/evaluation/__init__.py exist if required by your project setup.\n'
printf '  2. Install dependencies: python -m pip install "pydantic>=2" pytest\n'
printf '  3. Run tests: python -m pytest tests/evaluation -q\n'
