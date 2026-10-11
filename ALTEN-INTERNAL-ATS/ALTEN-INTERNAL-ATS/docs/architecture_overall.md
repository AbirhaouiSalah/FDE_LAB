# ATS Copilot: Architecture Brief for the Follow-Up Dashboard

> **How to use this file with another LLM.** Paste the whole file. Ask the LLM to build the dashboard described in section 5, using the diagrams as the source of truth for components, data and flows. Sections 1 to 4 are the system; section 5 is the dashboard.

## 0. Context for the LLM

- **System:** an internal AI copilot that helps HR recruiters pre-screen candidates for Forward Deployed Engineer (FDE) roles at ALTEN (France and Porto). It parses CVs, scores them against a versioned rubric with evidence, and produces a scorecard. **A human recruiter always decides.**
- **Dashboard purpose:** follow up (suivi) the recruitment pipeline, the value delivered (time saved), the quality and fairness of the scoring, the operational health of the system, and compliance.
- **Primary KPI:** reduce initial technical pre-screening time per candidate by 50 % (median active handling time).
- **Hard constraints:** no raw CV or protected attribute is ever shown; candidates appear only under an anonymized id; every metric is traceable to rubric, model and code versions.
- **Language:** UI in French with English labels available; code and API in English.

---

## 1. Master Architecture (Components, Stores, Flows)

```mermaid
flowchart TB
    %% ---------- External actors and systems ----------
    subgraph EXT["External actors and systems"]
        ATS["Corporate ATS<br/>applications, statuses"]
        REC["HR recruiter"]
        HM["Hiring manager"]
        HRD["HR director"]
        DPO["DPO and Legal"]
        OPS["FDE team in charge of MCO"]
    end

    %% ---------- C1 ----------
    subgraph C1["C1 Integration Gateway"]
        GW["API gateway<br/>FastAPI routers"]
        AUTH["Authentication and RBAC<br/>OIDC, roles"]
        VAL["Validation<br/>Pydantic schemas"]
        IDEM["Idempotency and dedup"]
        QUEUE["Job queue"]
        WRITER["ATS writer<br/>scorecard and status push"]
        DLQ["Retry and dead-letter"]
    end

    %% ---------- C2 ----------
    subgraph C2["C2 Ingestion and Parsing"]
        CHK["File checks<br/>type, size, malware"]
        EXTR["Text extraction and OCR fallback"]
        LANG["Language detection FR or EN"]
        SEG["Section segmentation"]
        PII["PII detection and redaction"]
        ENT["Entity and evidence extraction<br/>with provenance spans"]
        QLTY["Parse quality score"]
    end

    %% ---------- C3 ----------
    subgraph C3["C3 Job Profile Service"]
        JDP["JD parsing and requirement extraction"]
        CLS["Must-have vs nice-to-have"]
        JVAL["Manager validation"]
    end

    %% ---------- C4 ----------
    subgraph C4["C4 Rubric and Knowledge Store"]
        RUB["Rubric versions<br/>D1 to D5, weights, anchors"]
        TAX["Skills taxonomy FR and EN"]
        QB["Interview question bank"]
        PRM["Prompt templates"]
        APPR["Approval workflow"]
    end

    %% ---------- C5 ----------
    subgraph C5["C5 Evaluation Engine"]
        MATCH["Requirement matching"]
        SCORE["Dimension scoring 0 to 4"]
        LLMG["LLM gateway<br/>optional, validated output"]
        CONF["Confidence and completeness"]
        ASM["Scorecard assembler"]
        GRID["Interview grid generator"]
        GUARD["Guardrails<br/>evidence required, no auto-reject"]
    end

    %% ---------- C6 ----------
    subgraph C6["C6 Human Review and Feedback"]
        VIEW["Review view"]
        DEC["Decision<br/>advance, hold, decline"]
        OVR["Override with reason"]
        FBK["Feedback event store"]
    end

    %% ---------- C7 ----------
    subgraph C7["C7 Governance and Audit"]
        AUD["Append-only audit log"]
        CONS["Consent and notice registry"]
        RET["Retention scheduler"]
        DSR["Data subject requests"]
        VREG["Version registry<br/>rubric, prompt, model, code"]
    end

    %% ---------- C8 ----------
    subgraph C8["C8 Metrics and Calibration"]
        COL["Event collector"]
        KPI["KPI computation"]
        QM["Quality metrics<br/>agreement, override rate, recall proxy"]
        FM["Fairness metrics<br/>adverse impact, matched synthetic CVs"]
        GOLD["Golden set regression in CI"]
        DRIFT["Drift detection"]
        PROP["Change proposals"]
    end

    %% ---------- Platform ----------
    subgraph PLAT["Platform services"]
        DB[("Operational DB<br/>SQLite lab, PostgreSQL prod")]
        RAW[("Raw CV store<br/>encrypted, short retention")]
        MET[("Metrics store<br/>aggregates and snapshots")]
        OBS["Observability<br/>logs, metrics, traces"]
        SECR["Secrets and keys"]
    end

    %% ---------- Dashboard ----------
    subgraph DASHB["Follow-up Dashboard (to build)"]
        DAPI["Dashboard API<br/>read-only, aggregated, RBAC"]
        DUI["Dashboard UI<br/>pages and widgets"]
    end

    %% ---------- Main flow ----------
    ATS -->|"webhook or REST"| GW
    GW --> AUTH --> VAL --> IDEM --> QUEUE
    QUEUE --> CHK
    QUEUE --> JDP
    CHK --> EXTR --> LANG --> SEG --> PII --> ENT --> QLTY
    JDP --> CLS --> JVAL
    QLTY --> MATCH
    JVAL --> MATCH
    RUB --> MATCH
    TAX -.-> ENT
    TAX -.-> CLS
    MATCH --> SCORE --> CONF --> ASM --> GRID --> GUARD
    SCORE -.-> LLMG
    LLMG -.-> SCORE
    PRM -.-> LLMG
    QB -.-> GRID
    GUARD --> VIEW
    QLTY -.->|"low quality"| VIEW
    REC --> VIEW
    HM --> VIEW
    VIEW --> DEC
    VIEW --> OVR
    DEC --> WRITER
    WRITER --> DLQ
    DLQ --> ATS
    DEC --> FBK
    OVR --> FBK

    %% ---------- Governance flows ----------
    GW -.-> AUD
    GUARD -.-> AUD
    DEC -.-> AUD
    OVR -.-> AUD
    RUB -.-> VREG
    PRM -.-> VREG
    CONS -.-> AUTH
    RET -.-> RAW
    DSR -.-> DB
    APPR --> RUB
    APPR --> QB
    APPR --> PRM

    %% ---------- Metrics flows ----------
    FBK --> COL
    AUD --> COL
    GUARD --> COL
    DLQ -.-> COL
    COL --> KPI
    COL --> QM
    COL --> FM
    GOLD --> QM
    QM --> DRIFT
    KPI --> MET
    QM --> MET
    FM --> MET
    DRIFT --> MET
    MET --> PROP
    PROP -.-> APPR

    %% ---------- Storage links ----------
    ENT -.-> DB
    ASM -.-> DB
    FBK -.-> DB
    CHK -.-> RAW
    OBS -.-> MET

    %% ---------- Dashboard flows ----------
    MET --> DAPI
    DB --> DAPI
    AUD --> DAPI
    OBS --> DAPI
    VREG --> DAPI
    DAPI --> DUI
    REC --> DUI
    HM --> DUI
    HRD --> DUI
    DPO --> DUI
    OPS --> DUI

    classDef human fill:#FAEEDA,stroke:#BA7517,color:#412402
    classDef govern fill:#EEEDFE,stroke:#534AB7,color:#26215C
    classDef metric fill:#E1F5EE,stroke:#0F6E56,color:#04342C
    classDef dash fill:#E6F1FB,stroke:#185FA5,color:#042C53
    class REC,HM,HRD,DPO,OPS,VIEW,DEC,OVR human
    class AUD,CONS,RET,DSR,VREG govern
    class COL,KPI,QM,FM,GOLD,DRIFT,PROP,MET metric
    class DAPI,DUI dash
```

### Reading guide

| Flow | Meaning |
|---|---|
| Solid arrows | Main synchronous or sequential flow |
| Dashed arrows | Asynchronous, optional, governance or storage flows |
| Orange | Human actors and steps |
| Purple | Governance and compliance |
| Green | Metrics and calibration |
| Blue | The dashboard to build |

---

## 2. Candidate Pipeline State Machine

The dashboard funnel and queue views are driven by these states.

```mermaid
stateDiagram-v2
    [*] --> Received
    Received --> Ingesting: queued
    Ingesting --> ParseFailed: unreadable or low quality
    Ingesting --> Parsed: profile extracted
    ParseFailed --> NeedsHumanReview
    Parsed --> Evaluating
    Evaluating --> Scored: scorecard generated
    Evaluating --> EvalFailed: error or guardrail breach
    EvalFailed --> NeedsHumanReview
    Scored --> NeedsHumanReview: low confidence or incomplete
    Scored --> AwaitingReview: confidence sufficient
    NeedsHumanReview --> InReview: recruiter opens
    AwaitingReview --> InReview: recruiter opens
    InReview --> Advanced: advance to phone screen
    InReview --> OnHold: hold or request info
    InReview --> Declined: decline with reason
    OnHold --> InReview
    Advanced --> SyncedToATS
    OnHold --> SyncedToATS
    Declined --> SyncedToATS
    SyncedToATS --> [*]
```

---

## 3. Data Model Feeding the Dashboard

```mermaid
erDiagram
    JOB_PROFILE ||--o{ APPLICATION : "receives"
    APPLICATION ||--|| CANDIDATE_PROFILE : "has redacted"
    APPLICATION ||--o{ EVALUATION : "scored by"
    RUBRIC_VERSION ||--o{ EVALUATION : "used in"
    JOB_PROFILE }o--|| RUBRIC_VERSION : "targets"
    EVALUATION ||--|{ DIMENSION_SCORE : "contains"
    DIMENSION_SCORE ||--o{ EVIDENCE : "justified by"
    EVALUATION ||--o{ REVIEW_DECISION : "reviewed in"
    REVIEW_DECISION ||--o{ OVERRIDE : "may include"
    APPLICATION ||--o{ PIPELINE_EVENT : "emits"
    APPLICATION ||--o{ ATS_SYNC_EVENT : "synced by"
    EVALUATION ||--o{ AUDIT_EVENT : "logged in"
    REVIEW_DECISION ||--o{ AUDIT_EVENT : "logged in"
    RUBRIC_VERSION ||--o{ CALIBRATION_RUN : "validated by"
    CALIBRATION_RUN ||--o{ FAIRNESS_RESULT : "produces"
    METRIC_SNAPSHOT }o--|| RUBRIC_VERSION : "scoped to"

    JOB_PROFILE {
        string job_id PK
        string title
        string site "FR or PT"
        string status
        int version
        datetime opened_at
    }
    APPLICATION {
        string application_id PK
        string job_id FK
        string anon_candidate_id
        string source_channel
        string current_state
        datetime received_at
    }
    CANDIDATE_PROFILE {
        string application_id FK
        string language "fr or en"
        float parse_quality
        int years_relevant_experience
        json skills
    }
    RUBRIC_VERSION {
        string rubric_version PK
        json weights
        string status "draft or released"
        datetime released_at
    }
    EVALUATION {
        string evaluation_id PK
        string application_id FK
        string rubric_version FK
        string model_version
        float overall_score
        string confidence "low or medium or high"
        string recommendation
        datetime created_at
        int latency_ms
    }
    DIMENSION_SCORE {
        string evaluation_id FK
        string dimension_id "D1 to D5"
        int score "0 to 4"
        float weight
    }
    EVIDENCE {
        string evaluation_id FK
        string dimension_id FK
        string source_span
        string excerpt_ref
    }
    REVIEW_DECISION {
        string decision_id PK
        string evaluation_id FK
        string reviewer_role
        string decision "advance or hold or decline"
        string reason_code
        int handling_seconds
        datetime decided_at
    }
    OVERRIDE {
        string decision_id FK
        string dimension_id
        int original_score
        int new_score
        string reason_code
    }
    PIPELINE_EVENT {
        string application_id FK
        string from_state
        string to_state
        datetime occurred_at
    }
    ATS_SYNC_EVENT {
        string application_id FK
        string direction "in or out"
        string status "ok or retry or failed"
        int attempts
        datetime occurred_at
    }
    AUDIT_EVENT {
        string event_id PK
        string actor_role
        string action
        string versions_hash
        datetime occurred_at
    }
    CALIBRATION_RUN {
        string run_id PK
        string rubric_version FK
        float agreement_rate
        float recall_proxy
        datetime run_at
    }
    FAIRNESS_RESULT {
        string run_id FK
        string attribute_tested
        float adverse_impact_ratio
        string status "pass or review"
    }
    METRIC_SNAPSHOT {
        string snapshot_id PK
        string metric_name
        float value
        string period
        string rubric_version FK
        string site
    }
```

---

## 4. Event Catalog (What the Dashboard Can Rely On)

| Event | Emitted by | Key fields | Used for |
|---|---|---|---|
| `application.received` | C1 | application_id, job_id, source_channel | Volume, funnel start |
| `parse.completed` / `parse.failed` | C2 | parse_quality, language | Parsing health |
| `evaluation.completed` | C5 | overall_score, confidence, latency_ms, versions | Scoring distribution |
| `guardrail.breached` | C5 | rule, evaluation_id | Quality and safety alerts |
| `review.opened` / `review.decided` | C6 | handling_seconds, decision, reason_code | **Primary KPI**, funnel |
| `override.recorded` | C6 | dimension_id, original, new, reason | Agreement, calibration |
| `ats.sync` | C1 | direction, status, attempts | Integration health |
| `audit.recorded` | C7 | actor_role, action | Governance view |
| `retention.executed` / `dsr.processed` | C7 | counts, status | Compliance view |
| `calibration.completed` | C8 | agreement_rate, fairness results | Quality and fairness views |

---

## 5. Dashboard Specification

### 5.1 Information architecture

```mermaid
flowchart LR
    subgraph ROLES["Roles"]
        R1["Recruiter"]
        R2["Hiring manager"]
        R3["HR director"]
        R4["DPO and Legal"]
        R5["FDE MCO team"]
    end

    subgraph PAGES["Pages"]
        P1["1 Overview<br/>KPI and trends"]
        P2["2 Pipeline and funnel"]
        P3["3 Review queue<br/>candidates to handle"]
        P4["4 Quality and agreement"]
        P5["5 Fairness"]
        P6["6 Operations and MCO"]
        P7["7 Governance and compliance"]
        P8["8 Rubric and calibration"]
    end

    R1 --> P1
    R1 --> P3
    R2 --> P1
    R2 --> P2
    R2 --> P3
    R3 --> P1
    R3 --> P2
    R3 --> P4
    R3 --> P5
    R4 --> P5
    R4 --> P7
    R5 --> P6
    R5 --> P4
    R5 --> P8

    P1 --> W1["KPI cards: median handling time vs baseline,<br/>time saved, volume, time to first interview"]
    P2 --> W2["Funnel by state, by job and by site,<br/>conversion shortlist to interview"]
    P3 --> W3["Queue table: anon id, score, confidence,<br/>flags, age, owner"]
    P4 --> W4["Agreement rate, override rate by dimension,<br/>recall proxy, score distribution, drift"]
    P5 --> W5["Adverse impact ratios, matched-CV test results,<br/>status per rubric version"]
    P6 --> W6["Ingestion and evaluation latency, error rate,<br/>parse quality, ATS sync, dead-letter count"]
    P7 --> W7["Audit trail search, retention jobs,<br/>data subject requests, consent coverage"]
    P8 --> W8["Rubric versions, calibration runs,<br/>pending change proposals"]
```

### 5.2 Metric definitions

| Metric | Definition | Source | Refresh | Target or alert |
|---|---|---|---|---|
| Median handling time | Median `handling_seconds` per decided candidate | `REVIEW_DECISION` | Hourly | At least 50 % below baseline |
| Baseline | Median handling time measured before launch | Baseline study | Static | Reference line on charts |
| Time saved | (Baseline minus current median) times decided candidates | Derived | Daily | Cumulative hours |
| Volume | Applications received per week, by job and site | `APPLICATION` | Hourly | Trend |
| Time to first interview | Days from received to advanced | `PIPELINE_EVENT` | Daily | Trend |
| Shortlist conversion | Advanced divided by decided | `REVIEW_DECISION` | Daily | Trend |
| Agreement rate | Share of dimension scores unchanged by the recruiter | `OVERRIDE`, `DIMENSION_SCORE` | Daily | At or above 80 % (hypothesis) |
| Override rate | Overrides per evaluation, by dimension | `OVERRIDE` | Daily | Alert on sudden rise |
| Recall proxy | Share of golden-set strong profiles recommended to advance | `CALIBRATION_RUN` | Per run | Alert on drop |
| Low-confidence share | Evaluations flagged for human review divided by total | `EVALUATION` | Hourly | Trend |
| Parse failure rate | `parse.failed` divided by received | `PIPELINE_EVENT` | Hourly | Alert above threshold |
| Evaluation latency p95 | 95th percentile of `latency_ms` | `EVALUATION` | Hourly | Alert above threshold |
| ATS sync failures | Count with status `failed` or in dead-letter | `ATS_SYNC_EVENT` | Real time | Alert if above zero for a set time |
| Adverse impact ratio | Selection rate of a group divided by the highest group rate | `FAIRNESS_RESULT` | Per run | Review if below 0.8 |
| Guardrail breaches | Count of `guardrail.breached` | Events | Real time | Alert on any |

### 5.3 Dashboard API (read-only, suggested)

| Endpoint | Returns |
|---|---|
| `GET /dashboard/kpis?from&to&job_id&site` | KPI cards and trend series |
| `GET /dashboard/funnel?from&to&job_id&site` | Counts per pipeline state |
| `GET /dashboard/queue?status&limit&cursor` | Review queue rows (anonymized) |
| `GET /dashboard/quality?from&to&rubric_version` | Agreement, overrides, drift series |
| `GET /dashboard/fairness?rubric_version` | Fairness results per run |
| `GET /dashboard/operations?from&to` | Latency, errors, parse quality, ATS sync |
| `GET /dashboard/governance/audit?actor&action&from&to` | Audit events (paginated) |
| `GET /dashboard/rubrics` | Versions, status, calibration summary |

All endpoints enforce RBAC, return aggregates or anonymized ids only, and support a `rubric_version` filter.

### 5.4 Rules the dashboard must follow

1. **Never display** names, photos, ages, addresses, nationalities, raw CV text or any protected attribute.
2. **Small groups:** hide or merge any aggregate computed on fewer than 5 people to prevent re-identification.
3. **Role-based visibility:** recruiters see their own queue; managers see their openings; fairness and governance pages are limited to HR director, DPO and Legal; operations pages to the MCO team.
4. **Version awareness:** every chart can be filtered by rubric version, and a banner signals when versions are mixed in one period.
5. **Traceability:** each KPI card links to its definition (section 5.2) and last refresh time.
6. **No automatic decisions in the UI:** the dashboard is for follow-up; decision actions live in the review view (C6).
7. **Accessibility and language:** French first, English toggle, keyboard navigation, color not the only signal.

### 5.5 Suggested stack (adjust freely)

| Layer | Suggestion |
|---|---|
| Frontend | React with TypeScript, a charting library such as Recharts or ECharts |
| Backend | FastAPI read-only service on the metrics store |
| Data | SQLite for the lab, PostgreSQL with materialized views in production |
| Auth | OIDC with role claims mapped to the roles above |
| Delivery | Docker, deployed with the same CI pipeline as the engine |

### 5.6 Deliverables to ask the LLM for

1. Project structure and data contracts (TypeScript types matching section 3).
2. Mock data generator producing a realistic, **synthetic** dataset (no real candidates).
3. The eight pages with the widgets listed in 5.1 and metrics from 5.2.
4. The read-only API with the endpoints in 5.3 and tests.
5. RBAC handling and the small-group suppression rule.
6. A README explaining how to run it locally.