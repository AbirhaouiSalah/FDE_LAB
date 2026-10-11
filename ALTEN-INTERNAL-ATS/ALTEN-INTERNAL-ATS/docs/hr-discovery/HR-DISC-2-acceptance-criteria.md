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
