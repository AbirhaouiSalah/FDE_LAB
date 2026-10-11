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
