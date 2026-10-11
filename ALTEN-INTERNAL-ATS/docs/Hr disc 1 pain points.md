# HR-DISC-1: Recruiter & Hiring Manager Pain Points

**Epic:** HR-DISC (HR Discovery & Scoping)
**Status:** Draft v0.1 — hypotheses to validate through stakeholder interviews
**Scope:** Inbound applications for strategic technical roles (FDE, France and Porto)

> All figures below marked **[HYPOTHESIS]** are placeholders. Replace them with measured values from the baseline study (section 5) before presenting any ROI claim.

---

## 1. Problem Statement

HR teams receive a high volume of applications for hybrid technical profiles. Initial technical pre-screening is manual, slow and inconsistent, and delays the time-to-hire for roles that ALTEN considers strategic.

## 2. Stakeholders

| Stakeholder | Role in the process | What they need |
|---|---|---|
| HR recruiter | First CV screen, candidate contact | Faster triage, a defensible shortlist |
| Hiring manager (FDE team lead) | Technical validation, final decision | Relevant profiles only, a structured interview grid |
| Chief AI Officer / DSI Groupe | Sponsor of the FDE cell | Measurable impact, safe AI adoption |
| DPO / Legal | Compliance | GDPR, non-discrimination, auditability |
| Candidate (indirect) | Subject of the evaluation | Fair, explainable treatment |

## 3. Pain Points (Hypotheses to Validate)

| ID | Pain point | Who feels it | Evidence to collect |
|---|---|---|---|
| PP-1 | Manual CV reading of technical profiles takes several minutes each, with no technical filter | Recruiter | Minutes per CV, volume per week |
| PP-2 | Recruiters cannot easily judge hybrid profiles (Python/API skills plus a client-facing posture) | Recruiter | Share of CVs escalated to managers "just to check" |
| PP-3 | Hiring managers receive shortlists with poor technical fit and lose time | Hiring manager | Shortlist-to-interview conversion rate |
| PP-4 | Screening criteria vary from one recruiter to another | Recruiter, Manager | Inter-recruiter agreement on a sample of CVs |
| PP-5 | Interview questions are improvised, so evaluations are hard to compare | Manager | Existence and use of a standard grid |
| PP-6 | Candidate feedback and tracking in the ATS are incomplete | Recruiter | Share of candidates with documented rationale |
| PP-7 | Time-to-hire is long for competitive profiles | All | Days from application to first interview |

## 4. Target KPI

**Primary KPI:** reduce initial technical pre-screening time per candidate by **50 %**.

| Item | Definition |
|---|---|
| Metric | Median active handling time per candidate between "application received" and "screening decision recorded" |
| Baseline | To be measured (section 5) **[HYPOTHESIS: 6–10 min per CV]** |
| Target | 50 % below baseline, measured at the median |
| Measurement | Recruiter time-tracking sample, then ATS timestamps once the copilot is in use |

**Guardrail metrics.** The primary KPI must not be reached at the expense of quality or fairness:

| Guardrail | Why it matters |
|---|---|
| Recall of strong candidates (false-negative rate) | A faster process that drops good candidates is a failure |
| Recruiter–copilot agreement rate | Shows whether the scoring matches human judgment |
| Adverse impact ratio across protected groups | Legal and ethical requirement (see HR-DISC-2, section 6) |
| Recruiter override rate | High overrides signal low trust or poor rubric fit |
| Candidate-facing complaints | Early warning of unfair treatment |

Secondary KPIs: time-to-first-interview, shortlist-to-interview conversion, hiring-manager satisfaction (short survey).

## 5. Discovery Plan

1. **Baseline study (week 1).** Sample 30–50 recent applications. Record the time a recruiter takes to screen each and the decision taken.
2. **Recruiter interviews (3–5 people, 45 min).** Walk through a real screening session ("show me how you did this one").
3. **Hiring manager interviews (2–3 people, 30 min).** Clarify what a "good" FDE shortlist looks like and the top reasons for rejection.
4. **DPO / Legal session (30 min).** Retention, lawful basis, rules on automated decisions.
5. **Synthesis workshop (60 min).** Validate pain points, prioritize, confirm the KPI baseline.

### Interview guide (recruiters)

- Walk me through the last time you screened a technical CV. What did you look at first?
- Which parts of the CV do you trust? Which do you find hard to judge?
- When do you ask a technical colleague for help? How long does it take to get an answer?
- What makes you reject a CV in under a minute?
- What does the ATS give you today, and what do you do outside it (spreadsheets, notes, email)?
- What would make you trust an automated suggestion? What would make you ignore it?

### Interview guide (hiring managers)

- What are the three things that separate a strong FDE candidate from an average one?
- What proportion of shortlisted candidates are worth an interview today?
- What information would you want on a one-page candidate summary?
- Which interview questions have proven most predictive in the past?
- What would worry you about an AI-assisted screening process?

## 6. Current-State Process (To Confirm)

```
Application received (ATS / job board)
        -> Recruiter reads CV (manual)
        -> Technical doubt? -> escalate to hiring manager (async, slow)
        -> Shortlist decision
        -> Phone screen / interview (questions improvised)
        -> Feedback entered in ATS (partial)
```

Target-state candidates for automation: CV structuring, rubric-based scoring with evidence, standard interview grid generation. The decision itself stays with the human (see HR-DISC-2).

## 7. Risks & Open Questions

- Baseline may show that pre-screening is not the main bottleneck (for example, scheduling delays dominate). The KPI should then be reframed.
- Application volume for FDE roles may be too low for a 50 % saving to matter. Confirm volume.
- Recruiters may fear replacement. Position the tool as a copilot that prepares and explains, not one that decides.
- Data access: CVs are personal data. Confirm what can be used for the lab (anonymized or synthetic only).

## 8. Deliverables & Acceptance Criteria

- [ ] Baseline measured on at least 30 applications
- [ ] At least 3 recruiters and 2 hiring managers interviewed
- [ ] Pain points ranked, with evidence for each
- [ ] KPI definition and baseline signed off by the HR sponsor
- [ ] Guardrail metrics agreed with HR and the DPO