#!/usr/bin/env bash
# scripts/lots/build-lot-1.sh
# L1 — Fondations : api contracts + rbac + i18n + server
#
# Usage:
#   ./scripts/lots/build-lot-1.sh [--dry-run] [--no-push] [--no-propagate]
#                                  [--no-tests] [--yes]
#
# Pivot : ats-lab/feat/api/contracts
# Siblings : ats-lab/feat/auth/rbac  ats-lab/feat/i18n/fr-en
#            ats-lab/feat/server/read-only-api

set -euo pipefail

LOT_TAG="L1"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
# shellcheck source=./_lib.sh
source "$DIR/_lib.sh"

# ─────────────────────────────────────────────────────────────
# Config du lot
# ─────────────────────────────────────────────────────────────
PIVOT_BRANCH="ats-lab/feat/api/contracts"
SIBLING_BRANCHES=(
  "ats-lab/feat/auth/rbac"
  "ats-lab/feat/i18n/fr-en"
  "ats-lab/feat/server/read-only-api"
)
LOT_FILES="src/api/ src/auth/ src/i18n/ server/ scripts/quality/check-i18n-parity.ts"
COMMIT_MSG="feat(L1): foundations — api contracts + rbac + i18n + server"
LOT_NAME="Fondations"

cd "$ROOT"

# ─────────────────────────────────────────────────────────────
# Args
# ─────────────────────────────────────────────────────────────
if ! parse_common_args "$@"; then
  sed -n '2,12p' "$0"
  exit 0
fi

log "$LOT_NAME"
log "pivot:   $PIVOT_BRANCH"
log "siblings: ${SIBLING_BRANCHES[*]}"
log "files:   $LOT_FILES"

# ─────────────────────────────────────────────────────────────
# Pre-flight
# ─────────────────────────────────────────────────────────────
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not a git repo"
ensure_clean_tree

# ─────────────────────────────────────────────────────────────
# STEP 1 — checkout pivot
# ─────────────────────────────────────────────────────────────
log "STEP 1 — checkout pivot"
checkout_or_create "$PIVOT_BRANCH" main

# ─────────────────────────────────────────────────────────────
# STEP 2 — génération des artefacts
# ─────────────────────────────────────────────────────────────
log "STEP 2 — generate L1 artifacts"

# ─── src/api/types.ts ────────────────────────────────────────
write src/api/types.ts <<'EOF'
// Contrats de données — ATS Copilot Dashboard.
export type Site = 'FR' | 'PT';
export type Confidence = 'low' | 'medium' | 'high';
export type KpiStatus = 'ok' | 'watch' | 'alert';

export interface KpiSnapshot {
  metric_name: string;
  value: number;
  unit: 'seconds' | 'hours' | 'days' | 'count' | 'ratio' | 'percent';
  period: string;
  site?: Site;
  rubric_version: string;
  baseline?: number;
  target?: number;
  status: KpiStatus;
  last_refresh: string;
}

export interface QueueRow {
  anon_candidate_id: string;
  job_id: string;
  site: Site;
  overall_score: number;
  confidence: Confidence;
  flags: string[];
  age_hours: number;
  owner?: string;
}

export interface FairnessResult {
  rubric_version: string;
  attribute_tested: string;
  adverse_impact_ratio: number;
  status: 'pass' | 'review' | 'blocked';
  sample_size: number;
}

export interface AuditRow {
  event_id: string;
  actor_role: string;
  action: string;
  versions_hash: string;
  occurred_at: string;
}

export interface ApiError {
  status: number;
  message: string;
  detail?: unknown;
}
EOF

# ─── src/api/client.ts ───────────────────────────────────────
write src/api/client.ts <<'EOF'
// Client API read-only — ATS Copilot.
import type { ApiError } from './types';

const BASE = '/api';
const DEFAULT_TIMEOUT_MS = 10_000;

export class HttpError extends Error {
  readonly status: number;
  readonly detail?: unknown;
  constructor(status: number, message: string, detail?: unknown) {
    super(message);
    this.name = 'HttpError';
    this.status = status;
    this.detail = detail;
  }
}

export interface GetJsonOptions {
  timeoutMs?: number;
  signal?: AbortSignal;
}

export async function getJson<T>(path: string, opts: GetJsonOptions = {}): Promise<T> {
  const timeoutMs = opts.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  if (opts.signal) opts.signal.addEventListener('abort', () => controller.abort(), { once: true });
  try {
    const res = await fetch(`${BASE}${path}`, {
      method: 'GET',
      credentials: 'include',
      headers: { Accept: 'application/json' },
      signal: controller.signal
    });
    if (!res.ok) {
      let detail: unknown;
      try { detail = await res.json(); } catch { /* non-JSON body */ }
      throw new HttpError(res.status, `GET ${path} failed: ${res.status}`, detail);
    }
    return (await res.json()) as T;
  } catch (err) {
    if (err instanceof HttpError) throw err;
    if (err instanceof Error && err.name === 'AbortError') {
      throw new HttpError(0, `GET ${path} timed out after ${timeoutMs}ms`);
    }
    throw err;
  } finally {
    clearTimeout(timer);
  }
}

export const api = {
  kpis: (site?: string, rubric?: string) =>
    getJson<{ items: unknown[] }>(`/dashboard/kpis${buildQuery({ site, rubric_version: rubric })}`),
  queue: (limit = 50) => getJson<{ items: unknown[] }>(`/dashboard/queue?limit=${limit}`)
};

function buildQuery(params: Record<string, string | undefined>): string {
  const qs = Object.entries(params)
    .filter(([, v]) => v !== undefined && v !== '')
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v as string)}`)
    .join('&');
  return qs ? `?${qs}` : '';
}
EOF

# ─── src/api/client.test.ts ─────────────────────────────────
write src/api/client.test.ts <<'EOF'
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { getJson, HttpError } from './client';

const originalFetch = globalThis.fetch;
const okJson = (b: unknown): Response => ({ ok: true, status: 200, json: async () => b } as Response);
const errJson = (s: number, b: unknown = {}): Response => ({ ok: false, status: s, json: async () => b } as Response);
const mockFetch = (impl: (u: string, i?: RequestInit) => Promise<Response>) => {
  globalThis.fetch = vi.fn(impl) as unknown as typeof fetch;
};

describe('api/client — getJson', () => {
  beforeEach(() => vi.restoreAllMocks());
  afterEach(() => { globalThis.fetch = originalFetch; });

  it('returns parsed JSON on success', async () => {
    mockFetch(async () => okJson({ value: 42 }));
    expect(await getJson<{ value: number }>('/test')).toEqual({ value: 42 });
  });
  it('sends GET + credentials:include', async () => {
    const spy = vi.fn(async () => okJson({}));
    globalThis.fetch = spy as unknown as typeof fetch;
    await getJson('/x');
    expect(spy).toHaveBeenCalledWith(
      expect.stringContaining('/x'),
      expect.objectContaining({ method: 'GET', credentials: 'include' })
    );
  });
  it('prefixes /api', async () => {
    const spy = vi.fn(async () => okJson({}));
    globalThis.fetch = spy as unknown as typeof fetch;
    await getJson('/kpis');
    expect(String(spy.mock.calls[0]![0])).toMatch(/\/api\/kpis$/);
  });
  it('throws HttpError(403)', async () => {
    mockFetch(async () => errJson(403, { detail: 'forbidden' }));
    await expect(getJson('/x')).rejects.toMatchObject({ name: 'HttpError', status: 403 });
  });
  it('throws HttpError(500)', async () => {
    mockFetch(async () => errJson(500));
    await expect(getJson('/x')).rejects.toBeInstanceOf(HttpError);
  });
  it('propagates network errors', async () => {
    mockFetch(async () => { throw new Error('network'); });
    await expect(getJson('/x')).rejects.toThrow('network');
  });
  it('aborts after timeout', async () => {
    mockFetch((_u, i) => new Promise<Response>((_, rej) => {
      i?.signal?.addEventListener('abort', () => {
        const e = new Error('aborted'); e.name = 'AbortError'; rej(e);
      });
    }));
    await expect(getJson('/slow', { timeoutMs: 50 })).rejects.toMatchObject({ status: 0 });
  });
  it('tolerates non-JSON error bodies', async () => {
    mockFetch(async () => ({ ok: false, status: 500, json: async () => { throw new Error('not json'); } } as unknown as Response));
    await expect(getJson('/x')).rejects.toMatchObject({ status: 500 });
  });
});
EOF

# ─── src/auth/rbac.ts ────────────────────────────────────────
write src/auth/rbac.ts <<'EOF'
export type Role = 'recruiter' | 'hm' | 'hrd' | 'dpo' | 'mco';
export type Page =
  | 'overview' | 'pipeline' | 'queue' | 'quality'
  | 'fairness' | 'operations' | 'governance' | 'rubric';

export const ALL_ROLES: Role[] = ['recruiter', 'hm', 'hrd', 'dpo', 'mco'];
export const ALL_PAGES: Page[] = [
  'overview', 'pipeline', 'queue', 'quality',
  'fairness', 'operations', 'governance', 'rubric'
];

export const RBAC: Record<Role, Page[]> = {
  recruiter: ['overview', 'queue'],
  hm:        ['overview', 'pipeline', 'queue', 'rubric'],
  hrd:       ['overview', 'pipeline', 'queue', 'quality', 'fairness', 'governance', 'rubric'],
  dpo:       ['overview', 'fairness', 'governance', 'rubric'],
  mco:       ['overview', 'pipeline', 'queue', 'quality', 'operations', 'rubric']
};

export const canAccess = (role: Role, page: Page): boolean =>
  RBAC[role]?.includes(page) ?? false;
EOF

# ─── src/auth/rbac.test.ts ───────────────────────────────────
write src/auth/rbac.test.ts <<'EOF'
import { describe, it, expect } from 'vitest';
import { RBAC, canAccess, ALL_ROLES, ALL_PAGES, type Role, type Page } from './rbac';

describe('RBAC — matrice exhaustive (40 cas)', () => {
  for (const role of ALL_ROLES) {
    describe(`role: ${role}`, () => {
      for (const page of ALL_PAGES) {
        const expected = RBAC[role].includes(page);
        it(`${expected ? 'CAN' : 'CANNOT'} access ${page}`, () => {
          expect(canAccess(role, page)).toBe(expected);
        });
      }
    });
  }
});

describe('RBAC — invariants', () => {
  it('chaque rôle a Overview', () => {
    for (const role of ALL_ROLES) expect(canAccess(role, 'overview')).toBe(true);
  });
  it('fairness réservé à hrd + dpo', () => {
    for (const role of ALL_ROLES) expect(canAccess(role, 'fairness')).toBe(['hrd','dpo'].includes(role));
  });
  it('operations réservé à mco', () => {
    for (const role of ALL_ROLES) expect(canAccess(role, 'operations')).toBe(role === 'mco');
  });
  it('hrd voit tout sauf operations', () => {
    const expected = ALL_PAGES.filter(p => p !== 'operations').sort();
    expect([...RBAC.hrd].sort()).toEqual(expected);
  });
  it('matrice ne contient que des rôles/pages déclarés', () => {
    for (const role of Object.keys(RBAC) as Role[]) {
      expect(ALL_ROLES).toContain(role);
      for (const p of RBAC[role]) expect(ALL_PAGES).toContain(p as Page);
    }
  });
  it('canAccess ne throw pas pour rôle inconnu', () => {
    expect(canAccess('unknown' as Role, 'overview')).toBe(false);
  });
});
EOF

# ─── src/i18n/fr.json ────────────────────────────────────────
write src/i18n/fr.json <<'EOF'
{
  "app.title": "Copilote ATS",
  "nav.overview": "Vue d'ensemble",
  "nav.pipeline": "Pipeline",
  "nav.queue": "File d'attente",
  "nav.quality": "Qualité",
  "nav.fairness": "Équité",
  "nav.operations": "Opérations",
  "nav.governance": "Gouvernance",
  "nav.rubric": "Référentiel",
  "kpi.median_handling_time": "Temps de traitement médian",
  "kpi.time_saved": "Temps économisé",
  "kpi.volume": "Volume reçu",
  "kpi.time_to_first_interview": "Délai jusqu'au premier entretien",
  "common.refresh": "Dernière mise à jour",
  "common.version": "Version du référentiel",
  "common.baseline": "Référence",
  "common.target": "Objectif",
  "status.ok": "Conforme",
  "status.watch": "À surveiller",
  "status.alert": "Alerte",
  "rgpd.small_group": "Agrégat masqué (n<5)",
  "error.network": "Erreur réseau",
  "error.forbidden": "Accès refusé",
  "error.server": "Erreur serveur"
}
EOF

# ─── src/i18n/en.json ────────────────────────────────────────
write src/i18n/en.json <<'EOF'
{
  "app.title": "ATS Copilot",
  "nav.overview": "Overview",
  "nav.pipeline": "Pipeline",
  "nav.queue": "Queue",
  "nav.quality": "Quality",
  "nav.fairness": "Fairness",
  "nav.operations": "Operations",
  "nav.governance": "Governance",
  "nav.rubric": "Rubric",
  "kpi.median_handling_time": "Median handling time",
  "kpi.time_saved": "Time saved",
  "kpi.volume": "Volume received",
  "kpi.time_to_first_interview": "Time to first interview",
  "common.refresh": "Last refresh",
  "common.version": "Rubric version",
  "common.baseline": "Baseline",
  "common.target": "Target",
  "status.ok": "On track",
  "status.watch": "Watch",
  "status.alert": "Alert",
  "rgpd.small_group": "Aggregate hidden (n<5)",
  "error.network": "Network error",
  "error.forbidden": "Access denied",
  "error.server": "Server error"
}
EOF

# ─── scripts/quality/check-i18n-parity.ts ────────────────────
write scripts/quality/check-i18n-parity.ts <<'EOF'
#!/usr/bin/env tsx
import fr from '../../src/i18n/fr.json' with { type: 'json' };
import en from '../../src/i18n/en.json' with { type: 'json' };

const kFr = Object.keys(fr).sort();
const kEn = Object.keys(en).sort();
const missingInEn = kFr.filter(k => !(k in en));
const missingInFr = kEn.filter(k => !(k in fr));
const emptyFr = Object.entries(fr).filter(([, v]) => !v).map(([k]) => k);
const emptyEn = Object.entries(en).filter(([, v]) => !v).map(([k]) => k);

if (missingInEn.length === 0 && missingInFr.length === 0 && emptyFr.length === 0 && emptyEn.length === 0) {
  console.log(`i18n parity OK (${kFr.length} keys)`);
  process.exit(0);
}
console.error('i18n parity FAILED');
if (missingInEn.length) console.error('  missing in EN:', missingInEn);
if (missingInFr.length) console.error('  missing in FR:', missingInFr);
if (emptyFr.length)     console.error('  empty in FR:', emptyFr);
if (emptyEn.length)     console.error('  empty in EN:', emptyEn);
process.exit(1);
EOF

# ─── server/main.py ──────────────────────────────────────────
write server/main.py <<'EOF'
"""ATS Copilot — API read-only. RBAC enforced. Aucune PII."""
from __future__ import annotations
from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.responses import JSONResponse

app = FastAPI(title="ATS Copilot Dashboard API", version="0.1.0", docs_url=None, redoc_url=None)

ROLES: set[str] = {"recruiter", "hm", "hrd", "dpo", "mco"}
RBAC: dict[str, set[str]] = {
    "recruiter": {"overview", "queue"},
    "hm":        {"overview", "pipeline", "queue", "rubric"},
    "hrd":       {"overview", "pipeline", "queue", "quality", "fairness", "governance", "rubric"},
    "dpo":       {"overview", "fairness", "governance", "rubric"},
    "mco":       {"overview", "pipeline", "queue", "quality", "operations", "rubric"}
}

def current_role(request: Request) -> str:
    role = request.headers.get("X-Role", "recruiter")
    if role not in ROLES:
        raise HTTPException(status_code=401, detail="unknown role")
    return role

def require(page: str):
    def _inner(role: str = Depends(current_role)) -> str:
        if page not in RBAC.get(role, set()):
            raise HTTPException(status_code=403, detail="forbidden")
        return role
    return _inner

@app.get("/healthz")
def healthz() -> dict[str, str]: return {"status": "ok"}

@app.get("/api/dashboard/kpis")
def kpis(_: str = Depends(require("overview"))) -> dict[str, list]: return {"items": []}

@app.get("/api/dashboard/funnel")
def funnel(_: str = Depends(require("pipeline"))) -> dict[str, list]: return {"items": []}

@app.get("/api/dashboard/queue")
def queue(limit: int = 50, _: str = Depends(require("queue"))) -> dict[str, list]:
    return {"items": [], "limit": limit}

@app.get("/api/dashboard/quality")
def quality(_: str = Depends(require("quality"))) -> dict[str, list]: return {"items": []}

@app.get("/api/dashboard/fairness")
def fairness(_: str = Depends(require("fairness"))) -> dict[str, list]: return {"items": []}

@app.get("/api/dashboard/operations")
def operations(_: str = Depends(require("operations"))) -> dict[str, list]: return {"items": []}

@app.get("/api/dashboard/governance")
def governance(_: str = Depends(require("governance"))) -> dict[str, list]: return {"items": []}

@app.get("/api/dashboard/rubric")
def rubric(_: str = Depends(require("rubric"))) -> dict[str, list]: return {"items": []}

WRITE_METHODS = {"POST", "PUT", "PATCH", "DELETE"}

@app.middleware("http")
async def reject_write_methods(request: Request, call_next):
    if request.method in WRITE_METHODS:
        return JSONResponse(status_code=405, content={"detail": "read-only API"})
    return await call_next(request)
EOF

# ─── server/requirements.txt ─────────────────────────────────
write server/requirements.txt <<'EOF'
fastapi==0.115.0
uvicorn[standard]==0.30.6
pydantic==2.9.2
httpx==0.27.2
pytest==8.3.2
EOF

# ─── server/tests/test_rbac.py ──────────────────────────────
write server/tests/test_rbac.py <<'EOF'
from fastapi.testclient import TestClient
from server.main import app, RBAC, ROLES

client = TestClient(app)
as_role = lambda r: {"X-Role": r}

def test_healthz_no_auth():
    assert client.get("/healthz").json() == {"status": "ok"}

def test_kpis_unknown_role_401():
    assert client.get("/api/dashboard/kpis", headers=as_role("unknown")).status_code == 401

def test_kpis_recruiter_200():
    assert client.get("/api/dashboard/kpis", headers=as_role("recruiter")).status_code == 200

def test_fairness_recruiter_403():
    assert client.get("/api/dashboard/fairness", headers=as_role("recruiter")).status_code == 403

def test_fairness_hrd_200():
    assert client.get("/api/dashboard/fairness", headers=as_role("hrd")).status_code == 200

def test_fairness_dpo_200():
    assert client.get("/api/dashboard/fairness", headers=as_role("dpo")).status_code == 200

def test_operations_only_mco():
    for role in ROLES:
        r = client.get("/api/dashboard/operations", headers=as_role(role))
        expected = 200 if role == "mco" else 403
        assert r.status_code == expected

ENDPOINTS = {
    "overview": "/api/dashboard/kpis", "pipeline": "/api/dashboard/funnel",
    "queue": "/api/dashboard/queue", "quality": "/api/dashboard/quality",
    "fairness": "/api/dashboard/fairness", "operations": "/api/dashboard/operations",
    "governance": "/api/dashboard/governance", "rubric": "/api/dashboard/rubric"
}

def test_rbac_matrix_full():
    for role in ROLES:
        for page, url in ENDPOINTS.items():
            r = client.get(url, headers=as_role(role))
            expected = 200 if page in RBAC[role] else 403
            assert r.status_code == expected, f"{role} × {page} -> {r.status_code}"

def test_post_405():
    assert client.post("/api/dashboard/kpis", headers=as_role("hrd")).status_code == 405

def test_put_405():
    assert client.put("/api/dashboard/kpis", headers=as_role("hrd")).status_code == 405

def test_delete_405():
    assert client.delete("/api/dashboard/kpis", headers=as_role("hrd")).status_code == 405

FORBIDDEN = ["name", "email", "photo", "age", "nationality", "firstname", "lastname", "birthdate"]

def test_no_pii_in_kpis():
    r = client.get("/api/dashboard/kpis", headers=as_role("hrd"))
    body = r.text.lower()
    for p in FORBIDDEN: assert p not in body, f"PII leak: {p}"

def test_no_pii_in_queue():
    r = client.get("/api/dashboard/queue", headers=as_role("recruiter"))
    body = r.text.lower()
    for p in FORBIDDEN: assert p not in body, f"PII leak: {p}"
EOF

# Chmod pour le script tsx
[[ "${DRY_RUN:-0}" != "1" ]] && chmod +x scripts/quality/check-i18n-parity.ts 2>/dev/null || true

# ─────────────────────────────────────────────────────────────
# STEP 3 — Consolidation depuis les branches sœurs
# ─────────────────────────────────────────────────────────────
log "STEP 3 — consolidate sibling branches"
for sb in "${SIBLING_BRANCHES[@]}"; do
  log "  processing $sb"
  case "$sb" in
    ats-lab/feat/auth/rbac)
      copy_from_branch "$sb" "src/auth/rbac.ts" "src/auth/rbac.ts" || true
      copy_from_branch "$sb" "src/auth/rbac.test.ts" "src/auth/rbac.test.ts" || true
      ;;
    ats-lab/feat/i18n/fr-en)
      copy_from_branch "$sb" "src/i18n/fr.json" "src/i18n/fr.json" || true
      copy_from_branch "$sb" "src/i18n/en.json" "src/i18n/en.json" || true
      ;;
    ats-lab/feat/server/read-only-api)
      copy_from_branch "$sb" "server/main.py" "server/main.py" || true
      copy_from_branch "$sb" "server/requirements.txt" "server/requirements.txt" || true
      ;;
  esac
done

# ─────────────────────────────────────────────────────────────
# STEP 4 — Tests locaux
# ─────────────────────────────────────────────────────────────
log "STEP 4 — local validation"
run_tests

# ─────────────────────────────────────────────────────────────
# STEP 5 — Commit + push pivot
# ─────────────────────────────────────────────────────────────
log "STEP 5 — commit & push pivot"
commit_and_push "$COMMIT_MSG" "$LOT_FILES"

# ─────────────────────────────────────────────────────────────
# STEP 6 — Propagation vers les sœurs
# ─────────────────────────────────────────────────────────────
log "STEP 6 — propagate to siblings"
propagate_to "$LOT_FILES" "$COMMIT_MSG"

# ─────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────
echo
ok "$LOT_TAG — $LOT_NAME — complete"
log "next: verify CI at https://github.com/AbirhaouiSalah/FDE_LAB/actions"