#!/usr/bin/env bash
# scripts/lots/build-lot-6.sh
# Lot L6 — Données de démo
# Branche pivot : ats-lab/docs/spec/dashboard
# Sous-lots fusionnés : src/mock/data.ts + src/mock/dashboard-data.ts
#
# Produit :
#   src/mock/data.ts
#   src/mock/dashboard-data.ts
#   src/mock/__tests__/data.test.ts
#   docs/spec/mock-data.md
#   docs/invariants/no-pii.md
#
# Prérequis : L1 déjà appliqué (src/api/types.ts doit exister).
# Idempotent : ne réécrit pas sans FORCE=1.

set -euo pipefail

# Source unique des helpers (doit être en 1ère instruction utile)
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_lib.sh

LOT_ID="L6"
LOT_NAME="Données de démo"
LOT_BRANCH="ats-lab/docs/spec/dashboard"

log_step "$LOT_ID — $LOT_NAME (branche: $LOT_BRANCH)"

# ---------------------------------------------------------------------------
# 0. Préflight
# ---------------------------------------------------------------------------

require_cmd git

if [[ ! -f "$LOT_ROOT/src/api/types.ts" ]]; then
  die "L1 non appliqué : src/api/types.ts introuvable.
     → Lancer d'abord: ./scripts/lots/build-lot-1.sh"
fi

if ! grep -q "export interface QueueRow" "$LOT_ROOT/src/api/types.ts" 2>/dev/null; then
  log_warn "src/api/types.ts ne contient pas QueueRow."
  log_warn "L6 suppose que L1 a été étendu avec les types métier (QueueRow, Alert,"
  log_warn "TimeSeries, FunnelStage, GaugeValue, Heatmap). Voir docs/spec/mock-data.md."
  log_warn "Poursuite : les imports TypeScript échoueront si ces types manquent."
fi

# ---------------------------------------------------------------------------
# 1. src/mock/data.ts
# ---------------------------------------------------------------------------

log_step "1/5 — src/mock/data.ts"

write_file "$LOT_ROOT/src/mock/data.ts" <<'EOF'
// src/mock/data.ts
// Fixtures déterministes, sans PII, read-only.
// Consommé par src/mock/dashboard-data.ts et les tests.
// NE PAS muter : les invariants L6 (déterminisme, no-PII) en dépendent.

import type {
  Alert,
  FunnelStage,
  GaugeValue,
  Heatmap,
  KpiSnapshot,
  QueueRow,
  Site,
  TimeSeries,
} from "../api/types";

export const DEMO_SOURCE = "demo" as const;
export const DEMO_GENERATED_AT = "2025-01-15T08:00:00.000Z";

// ---------- Sites ----------

export const SITES: readonly Site[] = [
  {
    id: "site-paris",
    name: "Paris",
    country: "FR",
    openRoles: 7,
    kpis: [
      {
        id: "kpi-tts-paris",
        label: "Time-to-shortlist",
        value: 3.2,
        unit: "days",
        confidence: "high",
        capturedAt: DEMO_GENERATED_AT,
      },
    ],
  },
  {
    id: "site-berlin",
    name: "Berlin",
    country: "DE",
    openRoles: 4,
    kpis: [
      {
        id: "kpi-tts-berlin",
        label: "Time-to-shortlist",
        value: 4.1,
        unit: "days",
        confidence: "medium",
        capturedAt: DEMO_GENERATED_AT,
      },
    ],
  },
  {
    id: "site-madrid",
    name: "Madrid",
    country: "ES",
    openRoles: 2,
    kpis: [
      {
        id: "kpi-tts-madrid",
        label: "Time-to-shortlist",
        value: 5.6,
        unit: "days",
        confidence: "low",
        capturedAt: DEMO_GENERATED_AT,
      },
    ],
  },
];

// ---------- KPIs agrégés ----------

export const KPIS: readonly KpiSnapshot[] = [
  {
    id: "kpi-open-roles",
    label: "Postes ouverts",
    value: 13,
    unit: "roles",
    confidence: "high",
    capturedAt: DEMO_GENERATED_AT,
  },
  {
    id: "kpi-time-to-shortlist",
    label: "Time-to-shortlist médian",
    value: 4.1,
    unit: "days",
    confidence: "medium",
    capturedAt: DEMO_GENERATED_AT,
  },
  {
    id: "kpi-fairness",
    label: "Indice d'équité",
    value: 82,
    unit: "%",
    confidence: "medium",
    capturedAt: DEMO_GENERATED_AT,
  },
];

// ---------- File de pré-screening ----------
// IDs pseudonymisés : jamais de nom, email, téléphone.

export const QUEUE: readonly QueueRow[] = [
  {
    id: "cand_001",
    siteId: "site-paris",
    roleId: "role_backend",
    status: "new",
    score: 78,
    confidence: "high",
    updatedAt: "2025-01-14T10:12:00.000Z",
    flags: [],
  },
  {
    id: "cand_002",
    siteId: "site-paris",
    roleId: "role_backend",
    status: "screening",
    score: 64,
    confidence: "medium",
    updatedAt: "2025-01-14T11:03:00.000Z",
    flags: ["needs_review"],
  },
  {
    id: "cand_003",
    siteId: "site-berlin",
    roleId: "role_data",
    status: "shortlist",
    score: 91,
    confidence: "high",
    updatedAt: "2025-01-14T09:40:00.000Z",
    flags: [],
  },
  {
    id: "cand_004",
    siteId: "site-berlin",
    roleId: "role_data",
    status: "hold",
    score: 55,
    confidence: "low",
    updatedAt: "2025-01-13T16:20:00.000Z",
    flags: ["small_group"],
  },
  {
    id: "cand_005",
    siteId: "site-madrid",
    roleId: "role_frontend",
    status: "rejected",
    score: 22,
    confidence: "low",
    updatedAt: "2025-01-12T08:00:00.000Z",
    flags: [],
  },
  {
    id: "cand_006",
    siteId: "site-madrid",
    roleId: "role_frontend",
    status: "new",
    score: 71,
    confidence: "medium",
    updatedAt: "2025-01-14T07:45:00.000Z",
    flags: ["needs_review"],
  },
];

// ---------- Alertes ----------

export const ALERTS: readonly Alert[] = [
  {
    id: "alert_small_group_berlin",
    severity: "warning",
    code: "SMALL_GROUP",
    page: "sites",
    createdAt: "2025-01-14T08:00:00.000Z",
    context: { siteId: "site-berlin", cohort: 4, threshold: 5 },
  },
  {
    id: "alert_tts_regression_madrid",
    severity: "warning",
    code: "TTS_REGRESSION",
    page: "kpis",
    createdAt: "2025-01-14T08:00:00.000Z",
    context: { siteId: "site-madrid", deltaDays: 1.2 },
  },
  {
    id: "alert_data_freshness",
    severity: "info",
    code: "DATA_FRESHNESS",
    page: "dashboard",
    createdAt: "2025-01-15T07:00:00.000Z",
    context: { ageHours: 1 },
  },
];

// ---------- Séries temporelles ----------

export const TIME_SERIES: readonly TimeSeries[] = [
  {
    id: "ts_queue_volume",
    labelKey: "kpi.queueVolume",
    unit: "candidates",
    points: [
      { t: "2025-01-08T00:00:00.000Z", v: 42 },
      { t: "2025-01-09T00:00:00.000Z", v: 51 },
      { t: "2025-01-10T00:00:00.000Z", v: 47 },
      { t: "2025-01-11T00:00:00.000Z", v: 33 },
      { t: "2025-01-12T00:00:00.000Z", v: 28 },
      { t: "2025-01-13T00:00:00.000Z", v: 58 },
      { t: "2025-01-14T00:00:00.000Z", v: 63 },
    ],
  },
  {
    id: "ts_time_to_shortlist",
    labelKey: "kpi.timeToShortlist",
    unit: "days",
    points: [
      { t: "2025-01-08T00:00:00.000Z", v: 4.8 },
      { t: "2025-01-09T00:00:00.000Z", v: 4.6 },
      { t: "2025-01-10T00:00:00.000Z", v: 4.5 },
      { t: "2025-01-11T00:00:00.000Z", v: 4.5 },
      { t: "2025-01-12T00:00:00.000Z", v: 4.3 },
      { t: "2025-01-13T00:00:00.000Z", v: 4.2 },
      { t: "2025-01-14T00:00:00.000Z", v: 4.1 },
    ],
  },
];

// ---------- Entonnoir ----------

export const FUNNEL: readonly FunnelStage[] = [
  { id: "f_received",  labelKey: "funnel.received",  count: 240 },
  { id: "f_screened",  labelKey: "funnel.screened",  count: 180 },
  { id: "f_interview", labelKey: "funnel.interview", count: 64  },
  { id: "f_shortlist", labelKey: "funnel.shortlist", count: 28  },
  { id: "f_offer",     labelKey: "funnel.offer",     count: 9   },
];

// ---------- Jauges ----------

export const GAUGES: readonly GaugeValue[] = [
  { id: "g_fairness",       labelKey: "gauge.fairness",      value: 82, target: 90 },
  { id: "g_coverage",       labelKey: "gauge.coverage",      value: 71, target: 85 },
  { id: "g_sla_compliance", labelKey: "gauge.slaCompliance", value: 94, target: 95 },
];

// ---------- Heatmap ----------

export const HEATMAP_SITES_ROLES: Heatmap = {
  rows: ["site-paris", "site-berlin", "site-madrid"],
  cols: ["role_backend", "role_data", "role_frontend"],
  unit: "candidates",
  cells: [
    { row: "site-paris",  col: "role_backend",  value: 12 },
    { row: "site-paris",  col: "role_data",     value: 3  },
    { row: "site-paris",  col: "role_frontend", value: 5  },
    { row: "site-berlin", col: "role_backend",  value: 4  },
    { row: "site-berlin", col: "role_data",     value: 11 },
    { row: "site-berlin", col: "role_frontend", value: 2  },
    { row: "site-madrid", col: "role_backend",  value: 1  },
    { row: "site-madrid", col: "role_data",     value: 2  },
    { row: "site-madrid", col: "role_frontend", value: 7  },
  ],
};

// ---------- Sélecteurs purs (read-only, aucune mutation) ----------

export function countByStatus(status: QueueRow["status"]): number {
  return QUEUE.filter((r) => r.status === status).length;
}

export function queueForSite(siteId: string): readonly QueueRow[] {
  return QUEUE.filter((r) => r.siteId === siteId);
}

export function alertsForPage(page: Alert["page"]): readonly Alert[] {
  return ALERTS.filter((a) => a.page === page);
}
EOF

# ---------------------------------------------------------------------------
# 2. src/mock/dashboard-data.ts
# ---------------------------------------------------------------------------

log_step "2/5 — src/mock/dashboard-data.ts"

write_file "$LOT_ROOT/src/mock/dashboard-data.ts" <<'EOF'
// src/mock/dashboard-data.ts
// Agrégat unique, immuable, exposé aux pages (L5).
// Aucune donnée calculée au runtime côté client : tout est figé pour la démo.

import type {
  Alert,
  FunnelStage,
  GaugeValue,
  Heatmap,
  KpiSnapshot,
  QueueRow,
  Site,
  TimeSeries,
} from "../api/types";
import {
  ALERTS,
  DEMO_GENERATED_AT,
  DEMO_SOURCE,
  FUNNEL,
  GAUGES,
  HEATMAP_SITES_ROLES,
  KPIS,
  QUEUE,
  SITES,
  TIME_SERIES,
} from "./data";

export interface DashboardData {
  readonly source: typeof DEMO_SOURCE;
  readonly generatedAt: string;
  readonly sites: readonly Site[];
  readonly kpis: readonly KpiSnapshot[];
  readonly queue: readonly QueueRow[];
  readonly alerts: readonly Alert[];
  readonly timeSeries: readonly TimeSeries[];
  readonly funnel: readonly FunnelStage[];
  readonly gauges: readonly GaugeValue[];
  readonly heatmapSitesRoles: Heatmap;
}

export const DASHBOARD_DATA: DashboardData = Object.freeze({
  source: DEMO_SOURCE,
  generatedAt: DEMO_GENERATED_AT,
  sites: SITES,
  kpis: KPIS,
  queue: QUEUE,
  alerts: ALERTS,
  timeSeries: TIME_SERIES,
  funnel: FUNNEL,
  gauges: GAUGES,
  heatmapSitesRoles: HEATMAP_SITES_ROLES,
});

// Sélecteur public — aucune mutation, aucun effet de bord
export function getDashboardData(): DashboardData {
  return DASHBOARD_DATA;
}
EOF

# ---------------------------------------------------------------------------
# 3. src/mock/__tests__/data.test.ts
# ---------------------------------------------------------------------------

log_step "3/5 — src/mock/__tests__/data.test.ts"

write_file "$LOT_ROOT/src/mock/__tests__/data.test.ts" <<'EOF'
// src/mock/__tests__/data.test.ts
// Vérifie les invariants L6 : no-PII, déterminisme, cohérence croisée.

import { describe, it, expect } from "vitest";
import {
  ALERTS,
  QUEUE,
  SITES,
  KPIS,
  TIME_SERIES,
  FUNNEL,
  GAUGES,
  HEATMAP_SITES_ROLES,
  countByStatus,
  queueForSite,
  alertsForPage,
} from "../data";
import { DASHBOARD_DATA } from "../dashboard-data";

const PII_PATTERNS: readonly RegExp[] = [
  /@/,                              // email
  /\+?\d{6,}/,                      // téléphone / numéro long
  /\b[A-Z][a-z]+\s+[A-Z][a-z]+\b/,  // "Prénom Nom" (heuristique)
];

function assertNoPII(value: unknown, path = "$"): void {
  const str = typeof value === "string" ? value : JSON.stringify(value);
  for (const p of PII_PATTERNS) {
    if (p.test(str)) throw new Error(`PII suspecté en ${path}: ${p} → ${str}`);
  }
}

describe("mock/data — invariants no-PII", () => {
  it("aucune PII dans les sites", () => {
    for (const s of SITES) assertNoPII(s, `site ${s.id}`);
  });
  it("aucune PII dans la file", () => {
    for (const r of QUEUE) assertNoPII(r, `queue ${r.id}`);
  });
  it("aucune PII dans les KPIs", () => {
    for (const k of KPIS) assertNoPII(k, `kpi ${k.id}`);
  });
  it("aucune PII dans les alertes", () => {
    for (const a of ALERTS) assertNoPII(a, `alert ${a.id}`);
  });
  it("IDs candidats pseudonymisés (cand_xxx)", () => {
    for (const r of QUEUE) expect(r.id).toMatch(/^cand_\d{3}$/);
  });
  it("timestamps ISO 8601 stables", () => {
    for (const r of QUEUE) {
      expect(() => new Date(r.updatedAt).toISOString()).not.toThrow();
    }
  });
});

describe("mock/data — cohérence croisée", () => {
  it("chaque site a au moins un KPI", () => {
    for (const s of SITES) expect(s.kpis.length).toBeGreaterThan(0);
  });
  it("chaque QueueRow pointe vers un site connu", () => {
    const siteIds = new Set(SITES.map((s) => s.id));
    for (const r of QUEUE) expect(siteIds.has(r.siteId)).toBe(true);
  });
  it("score ∈ [0,100]", () => {
    for (const r of QUEUE) {
      expect(r.score).toBeGreaterThanOrEqual(0);
      expect(r.score).toBeLessThanOrEqual(100);
    }
  });
  it("cellules heatmap couvrent rows × cols", () => {
    const expected =
      HEATMAP_SITES_ROLES.rows.length * HEATMAP_SITES_ROLES.cols.length;
    expect(HEATMAP_SITES_ROLES.cells).toHaveLength(expected);
  });
  it("jauge value ∈ [0,100]", () => {
    for (const g of GAUGES) {
      expect(g.value).toBeGreaterThanOrEqual(0);
      expect(g.value).toBeLessThanOrEqual(100);
    }
  });
  it("entonnoir strictement décroissant", () => {
    for (let i = 1; i < FUNNEL.length; i++) {
      expect(FUNNEL[i].count).toBeLessThanOrEqual(FUNNEL[i - 1].count);
    }
  });
  it("séries temporelles strictement croissantes en t", () => {
    for (const ts of TIME_SERIES) {
      for (let i = 1; i < ts.points.length; i++) {
        expect(new Date(ts.points[i].t).getTime()).toBeGreaterThan(
          new Date(ts.points[i - 1].t).getTime(),
        );
      }
    }
  });
});

describe("mock/data — sélecteurs purs", () => {
  it("countByStatus somme à QUEUE.length", () => {
    const statuses = ["new", "screening", "shortlist", "rejected", "hold"] as const;
    const total = statuses.reduce((n, s) => n + countByStatus(s), 0);
    expect(total).toBe(QUEUE.length);
  });
  it("queueForSite filtre correctement", () => {
    const paris = queueForSite("site-paris");
    expect(paris.every((r) => r.siteId === "site-paris")).toBe(true);
  });
  it("alertsForPage filtre correctement", () => {
    expect(alertsForPage("dashboard").every((a) => a.page === "dashboard")).toBe(true);
  });
});

describe("mock/dashboard-data — agrégat", () => {
  it("source = demo", () => expect(DASHBOARD_DATA.source).toBe("demo"));
  it("generatedAt ISO", () =>
    expect(() => new Date(DASHBOARD_DATA.generatedAt).toISOString()).not.toThrow());
  it("agrégat est gelé", () =>
    expect(Object.isFrozen(DASHBOARD_DATA)).toBe(true));
  it("agrégat référence bien les fixtures", () => {
    expect(DASHBOARD_DATA.sites).toBe(SITES);
    expect(DASHBOARD_DATA.queue).toBe(QUEUE);
  });
});
EOF

# ---------------------------------------------------------------------------
# 4. docs/spec/mock-data.md
# ---------------------------------------------------------------------------

log_step "4/5 — docs/spec/mock-data.md"

write_file "$LOT_ROOT/docs/spec/mock-data.md" <<'EOF'
# L6 — Contrat des données de démo

## Portée
Fournit les fixtures déterministes consommées par L2, L3, L5.

## Non-portée
- Ne définit aucun type métier → voir `src/api/types.ts` (L1).
- Ne calcule rien au runtime → tout est figé pour la démo.
- N'expose aucune mutation.

## Invariants
1. Aucune PII — test automatisé : `src/mock/__tests__/data.test.ts`.
2. Source tracée (`source: "demo"`, `generatedAt`).
3. Déterminisme total (pas de `Math.random`, pas de `Date.now`).
4. FR-first — libellés via clés i18n, jamais en dur dans les fixtures.

## Surface publique

| Export | Type | Consommateur |
|--------|------|--------------|
| `SITES`, `KPIS` | fixtures | L2, L5 |
| `QUEUE` | fixtures | L2 (QueueTable), L5 |
| `ALERTS` | fixtures | L2 (AlertPanel), L5 |
| `TIME_SERIES`, `FUNNEL`, `GAUGES`, `HEATMAP_SITES_ROLES` | fixtures | L3, L5 |
| `DASHBOARD_DATA` | agrégat | L5 |
| `countByStatus`, `queueForSite`, `alertsForPage` | sélecteurs purs | L2, L5 |

## Dépendances amont

- `src/api/types.ts` (L1) doit exposer : `Site`, `KpiSnapshot`, `Confidence`,
  `QueueRow`, `Alert`, `TimeSeries`, `FunnelStage`, `GaugeValue`, `Heatmap`.
- `src/i18n/fr.json` + `en.json` (L1) doivent contenir les clés :
  `kpi.queueVolume`, `kpi.timeToShortlist`,
  `funnel.{received,screened,interview,shortlist,offer}`,
  `gauge.{fairness,coverage,slaCompliance}`.

## Dépendances aval

- L2 (SmallGroupGuard) lit `ALERTS` avec `code === "SMALL_GROUP"`.
- L2 (QueueTable) lit `QUEUE`, utilise `queueForSite`.
- L3 (TimeSeries, FunnelChart, Gauge, Heatmap) lit les fixtures correspondantes.
- L5 (pages) consomme `DASHBOARD_DATA` via `getDashboardData()`.
EOF

# ---------------------------------------------------------------------------
# 5. docs/invariants/no-pii.md
# ---------------------------------------------------------------------------

log_step "5/5 — docs/invariants/no-pii.md"

write_file "$LOT_ROOT/docs/invariants/no-pii.md" <<'EOF'
# Invariant : aucune PII

## Règle
Aucun nom, email, téléphone, adresse, identifiant national, photo.
Les candidats sont des `cand_\d{3}`.

## Application
- Fixtures : `src/mock/data.ts` — pseudonymisation stricte.
- Server : `server/main.py` — middleware test (L1).
- Tests : `src/mock/__tests__/data.test.ts` — `assertNoPII` sur tous les exports.

## Portée
S'applique à tous les lots L1..L7. Toute violation détectée en CI bloque le merge.

## Non-conformités connues
Aucune à ce jour.
EOF

# ---------------------------------------------------------------------------
# Récapitulatif
# ---------------------------------------------------------------------------

log_step "$LOT_ID — récapitulatif"

FILES=(
  "src/mock/data.ts"
  "src/mock/dashboard-data.ts"
  "src/mock/__tests__/data.test.ts"
  "docs/spec/mock-data.md"
  "docs/invariants/no-pii.md"
)

for f in "${FILES[@]}"; do
  if [[ -f "$LOT_ROOT/$f" ]]; then
    log_success "$f"
  else
    log_warn "manquant: $f"
  fi
done

log_success "$LOT_ID — $LOT_NAME : OK"
log_info "Branche pivot : $LOT_BRANCH"
log_info "Prochaine étape : ./scripts/lots/push-lot.sh --lot $LOT_BRANCH --files \"src/mock/ docs/\" --yes"
