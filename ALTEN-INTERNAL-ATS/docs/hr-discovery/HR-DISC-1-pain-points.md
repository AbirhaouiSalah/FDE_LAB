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
