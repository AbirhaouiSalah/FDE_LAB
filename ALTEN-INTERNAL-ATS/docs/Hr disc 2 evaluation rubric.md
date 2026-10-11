# HR-DISC-2: Candidate Evaluation Rubric (FDE)

**Epic:** HR-DISC (HR Discovery & Scoping)
**Status:** Draft v0.1 — weights and anchors to be calibrated with hiring managers
**Principle:** the copilot **prepares and explains**; a human recruiter **decides**.

---

## 1. Design Principles

1. **Evidence-based.** Every score must cite a concrete element from the CV (quote or reference). No evidence means no points.
2. **Explainable.** Each dimension returns a score, a justification and the evidence used.
3. **Human in the loop.** The output is a recommendation with a rationale, never an automated rejection.
4. **Job-related criteria only.** No protected attribute or proxy is used (section 6).
5. **Soft ranges, few hard filters.** Missing information lowers confidence; it does not silently eliminate the candidate.

## 2. Dimensions and Weights (Proposed)

The four dimensions requested for the lab are in bold. A fifth dimension (GenAI / agentic exposure) is proposed because the FDE cell exists to accelerate GenAI adoption. Remove it if hiring managers disagree.

| # | Dimension | Weight | What it measures |
|---|---|---|---|
| D1 | **Technical core** (Python, SQL, APIs) | 30 % | Depth and recency of hands-on delivery |
| D2 | **Client-facing / solution delivery** | 30 % | Embedded work, requirement translation, stakeholder management |
| D3 | GenAI / agentic exposure (proposed) | 15 % | LLM, prompt engineering, agent integrations |
| D4 | **Experience fit** (4–10 years) | 15 % | Seniority aligned with the role |
| D5 | **Bilingual proficiency** (FR / EN) | 10 % | Ability to work in both languages with clients and teams |

Total score = weighted sum of dimension scores, normalized to 0–100.

## 3. Scoring Scale

Each dimension is scored **0 to 4** with an explicit evidence requirement.

| Score | Meaning |
|---|---|
| 0 | No evidence |
| 1 | Weak or indirect evidence |
| 2 | Partial: relevant but limited in scope or depth |
| 3 | Strong: clear, repeated, recent evidence |
| 4 | Outstanding: leadership or ownership at scale, with measurable results |

## 4. Anchors per Dimension

### D1 — Technical core (30 %)

| Score | Anchor |
|---|---|
| 0 | No Python, SQL or API work mentioned |
| 1 | Skills listed without project context |
| 2 | Used in coursework or small projects, or only one of the three areas |
| 3 | Production use of Python **and** SQL **and** REST APIs, with named projects |
| 4 | Designed and shipped services end to end (API design, persistence, tests, CI/CD) with measurable outcomes |

Signals: Python, FastAPI/Flask, SQL and migrations, REST design, Pytest, Docker, CI/CD.

### D2 — Client-facing / solution delivery (30 %)

| Score | Anchor |
|---|---|
| 0 | No client or stakeholder interaction |
| 1 | Internal team work only, with incidental user contact |
| 2 | Occasional client interaction, support role |
| 3 | Embedded on client site or regular workshops; translated needs into solutions |
| 4 | Led discovery, scoped and delivered solutions for clients, with adoption results |

Signals: on-site deployment, workshops, requirements gathering, demos, training, regulated or complex environments.

### D3 — GenAI / agentic exposure (15 %, proposed)

| Score | Anchor |
|---|---|
| 0 | None |
| 1 | Mentions LLMs or AI tools only |
| 2 | Personal or academic projects with prompts or API calls |
| 3 | Built agent or RAG workflows, structured outputs, evaluation |
| 4 | Deployed LLM solutions in a business context with monitoring and adoption |

### D4 — Experience fit (15 %)

Treat 4–10 years as the **target band**, not a hard filter.

| Years of relevant experience | Score |
|---|---|
| < 2 | 0 |
| 2 to < 4 | 2, only if D1 and D2 are both ≥ 3 |
| 4 to 10 | 4 |
| > 10 | 3, with a note for the recruiter (role level and compensation fit to check) |

Count relevant professional experience, including apprenticeships and internships at their actual duration. Do **not** infer age from graduation dates.

### D5 — Bilingual proficiency, FR / EN (10 %)

Use the CEFR scale and only explicit evidence: declared level, certifications, studies or work conducted in the language, CV written in the language.

| Score | Anchor |
|---|---|
| 0 | Neither language evidenced |
| 2 | One language evidenced at B2 or above, the other basic or unknown |
| 3 | Both at B2 or above, one with professional use |
| 4 | Both at C1 or above, with professional use in both |

Never infer language ability from name, nationality, photo or place of birth. When unknown, flag **"to verify at phone screen"**.

## 5. Output Contract (Scorecard)

The evaluator returns a structured result, which maps directly to the Pydantic model in `src/evaluator/`.

```json
{
  "candidate_id": "anonymized-id",
  "job_id": "FDE-FR-001",
  "overall_score": 78,
  "confidence": "medium",
  "dimensions": [
    {
      "id": "D1",
      "name": "Technical core",
      "score": 3,
      "weight": 0.30,
      "justification": "Production Python and SQL migrations on enterprise software.",
      "evidence": ["Built automated version lifecycle workflows ...", "Relational database migrations ..."]
    }
  ],
  "gaps": ["No evidence of agentic framework use"],
  "to_verify": ["English level (not stated)"],
  "suggested_interview_questions": [
    "Describe a time you simplified a technical design for a non-technical stakeholder."
  ],
  "recommendation": "advance_to_phone_screen",
  "decision_owner": "human"
}
```

`recommendation` is limited to `advance_to_phone_screen`, `needs_human_review` or `low_fit_flagged`. There is no automatic "reject" value.

## 6. Fairness, Compliance & Governance

- **Excluded inputs:** name, photo, age or date of birth, gender, nationality, address, marital status, health, and any other protected characteristic. Strip or ignore these before scoring.
- **Proxy risk:** school prestige, graduation year, employment gaps and career breaks must not penalize candidates. Review the rubric for indirect proxies with HR and Legal.
- **GDPR:** document the lawful basis, retention period and candidate information notice. Article 22 limits decisions based solely on automated processing, which is why a human makes the final call.
- **EU AI Act:** AI systems used for recruitment and candidate evaluation fall in the high-risk category (Annex III). Check with Legal the current application timeline and obligations (risk management, logging, human oversight, transparency).
- **Auditability:** log inputs, rubric version, model version and output for every evaluation.
- **Bias testing:** compare score distributions on synthetic matched CVs that differ only by a protected attribute. Track the adverse impact ratio over time.

## 7. Calibration Plan

1. Select 20–30 historical CVs (anonymized) with known outcomes.
2. Have 2 recruiters and 1 hiring manager score them independently with this rubric.
3. Measure inter-rater agreement. Rewrite anchors where agreement is low.
4. Run the copilot on the same set and compare. Target: agreement with the human consensus within ±1 point on at least 80 % of dimension scores **[HYPOTHESIS]**.
5. Adjust weights with the hiring managers and freeze rubric v1.0.

## 8. Acceptance Criteria

- [ ] Dimensions, weights and anchors validated by at least 2 hiring managers
- [ ] Excluded inputs and proxy-risk list reviewed by HR and the DPO
- [ ] Scorecard schema agreed and implemented as a Pydantic model
- [ ] Calibration set scored and agreement measured
- [ ] Rubric versioned (v1.0) and referenced in every scorecard