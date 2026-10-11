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
