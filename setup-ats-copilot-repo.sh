#!/usr/bin/env bash
# setup-ats-copilot-repo.sh — corrected, hardened
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Args
# ─────────────────────────────────────────────────────────────
TARGET_DIR="ats-copilot-dashboard"
PUSH_URL=""
DO_RESET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --push)  PUSH_URL="${2:-}"; shift 2 ;;
    --reset) DO_RESET=1; shift ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) TARGET_DIR="$1"; shift ;;
  esac
done

# ─────────────────────────────────────────────────────────────
# Logging
# ─────────────────────────────────────────────────────────────
C_RESET="\033[0m"; C_BLUE="\033[1;34m"; C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"; C_RED="\033[1;31m"
log()  { printf "${C_BLUE}[setup]${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_GREEN}[ ok ]${C_RESET} %s\n" "$*"; }
warn() { printf "${C_YELLOW}[warn]${C_RESET} %s\n" "$*"; }
die()  { printf "${C_RED}[fail]${C_RESET} %s\n" "$*" >&2; exit 1; }

# ─────────────────────────────────────────────────────────────
# Pre-flight
# ─────────────────────────────────────────────────────────────
command -v git >/dev/null || die "git is required"
[[ -n "$(git config --global user.name  || true)" ]] || die "set git user.name first"
[[ -n "$(git config --global user.email || true)" ]] || die "set git user.email first"

# ─────────────────────────────────────────────────────────────
# Validate a branch name
# ─────────────────────────────────────────────────────────────
validate_branch() {
  local b="$1"
  [[ "$b" =~ ^(comp|feat|fix|chore|docs|spike)/[a-z0-9-]+/[a-z0-9-]{1,40}$ ]] \
    || die "invalid branch name: '$b'"
}

# ─────────────────────────────────────────────────────────────
# Reset if requested
# ─────────────────────────────────────────────────────────────
if [[ "$DO_RESET" == "1" && -d "$TARGET_DIR" ]]; then
  warn "resetting $TARGET_DIR"
  rm -rf "$TARGET_DIR"
fi

# ─────────────────────────────────────────────────────────────
# Init or reuse
# ─────────────────────────────────────────────────────────────
if [[ -d "$TARGET_DIR/.git" ]]; then
  warn "repo already exists at $TARGET_DIR — reusing it"
else
  mkdir -p "$TARGET_DIR"
  (cd "$TARGET_DIR" && git init -q -b main)
  ok "initialized git repo at $TARGET_DIR"
fi

cd "$TARGET_DIR"
TARGET_ABS="$(pwd)"

log "working directory: $TARGET_ABS"
log "current branch: $(git rev-parse --abbrev-ref HEAD)"

# ─────────────────────────────────────────────────────────────
# Trap: restore branch on error
# ─────────────────────────────────────────────────────────────
ORIG_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
on_error() { warn "error — restoring to $ORIG_BRANCH"; git checkout -q "$ORIG_BRANCH" 2>/dev/null || true; }
trap on_error ERR

# ─────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────
ensure_branch() {
  local branch="$1"
  validate_branch "$branch"
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    warn "branch $branch already exists"
    git checkout -q "$branch"
    return 0
  fi
  if git show-ref --verify --quiet "refs/heads/main" \
     && [[ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]]; then
    git checkout -q -b "$branch" main
  else
    git checkout -q -b "$branch"
  fi
  ok "created branch $branch"
}

commit_if_dirty() {
  local msg="$1"
  if [[ -n "$(git status --porcelain)" ]]; then
    git add -A
    git commit -q -m "$msg"
    ok "committed: $msg"
  else
    warn "nothing to commit on $(git rev-parse --abbrev-ref HEAD)"
  fi
}

back_to_main() {
  git checkout -q main 2>/dev/null || true
}

write() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat > "$path"
}

# ─────────────────────────────────────────────────────────────
# 1. main skeleton
# ─────────────────────────────────────────────────────────────
log "Bootstrapping main branch skeleton"

mkdir -p \
  .github/workflows docs scripts \
  src/app/shell src/pages src/widgets src/api src/auth src/i18n \
  mock/seeds server/routers server/tests public

write .gitignore <<'EOF'
node_modules/
dist/
coverage/
.env
.env.*
!.env.example
*.log
.DS_Store
.vite/
playwright-report/
test-results/
storybook-static/
EOF

write .nvmrc <<'EOF'
20
EOF

write package.json <<'EOF'
{
  "name": "ats-copilot-dashboard",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "lint": "eslint . --max-warnings 0",
    "typecheck": "tsc --noEmit",
    "test": "vitest"
  }
}
EOF

write tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "jsx": "react-jsx",
    "esModuleInterop": true,
    "skipLibCheck": true,
    "resolveJsonModule": true,
    "baseUrl": "src",
    "paths": { "@/*": ["*"] }
  },
  "include": ["src", "mock", "scripts"]
}
EOF

write vite.config.ts <<'EOF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'node:path';
export default defineConfig({
  plugins: [react()],
  resolve: { alias: { '@': path.resolve(__dirname, 'src') } },
  server: { port: 5173 }
});
EOF

write docs/branching.md <<'EOF'
# Branching strategy

`<type>/<scope>/<short-description>`

types: comp | feat | fix | chore | docs | spike
EOF

write src/app/main.tsx <<'EOF'
export const APP_NAME = 'ats-copilot-dashboard';
EOF

for d in src/app/shell src/pages src/widgets src/api src/auth src/i18n \
         mock/seeds server/routers server/tests public; do
  touch "$d/.gitkeep"
done

commit_if_dirty "chore: bootstrap repository skeleton"

# ─────────────────────────────────────────────────────────────
# 2. shell
# ─────────────────────────────────────────────────────────────
log "Creating comp/shell/app-shell"
ensure_branch comp/shell/app-shell

write src/app/shell/AppShell.tsx <<'EOF'
import type { ReactNode } from 'react';
export interface AppShellProps { children: ReactNode }
export function AppShell({ children }: AppShellProps) {
  return <div data-testid="app-shell">{children}</div>;
}
EOF

write src/app/shell/Header.tsx <<'EOF'
export function Header() { return <header data-testid="header" />; }
EOF

write src/app/shell/FilterBar.tsx <<'EOF'
export function FilterBar() { return <div data-testid="filter-bar" />; }
EOF

write src/app/shell/LeftNav.tsx <<'EOF'
export function LeftNav() { return <nav data-testid="left-nav" />; }
EOF

write src/app/shell/VersionBanner.tsx <<'EOF'
export function VersionBanner() { return null; }
EOF

write src/app/shell/index.ts <<'EOF'
export * from './AppShell';
export * from './Header';
export * from './FilterBar';
export * from './LeftNav';
export * from './VersionBanner';
EOF

commit_if_dirty "comp(shell): add app shell"
back_to_main

# ─────────────────────────────────────────────────────────────
# 3. pages — slug|Pascal, newline-delimited, CR-stripped
# ─────────────────────────────────────────────────────────────
log "Creating one branch per page"

PAGES=$(cat <<'EOF'
overview|Overview
pipeline|Pipeline
queue|Queue
quality|Quality
fairness|Fairness
operations|Operations
governance|Governance
rubric|Rubric
EOF
)

while IFS='|' read -r slug pascal; do
  slug="$(echo "$slug" | tr -d '\r' | tr -d ' ')"
  pascal="$(echo "$pascal" | tr -d '\r' | tr -d ' ')"
  [[ -z "$slug" || -z "$pascal" ]] && continue

  branch="comp/${slug}/page"
  log "Creating $branch"
  ensure_branch "$branch"

  write "src/pages/${pascal}.tsx" <<EOF2
export function ${pascal}Page() {
  return <main data-testid="${slug}-page" />;
}
EOF2

  write "src/pages/${pascal}.test.tsx" <<EOF2
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { ${pascal}Page } from './${pascal}';

describe('${pascal}Page', () => {
  it('renders', () => {
    render(<${pascal}Page />);
    expect(screen.getByTestId('${slug}-page')).toBeInTheDocument();
  });
});
EOF2

  commit_if_dirty "comp(${slug}): scaffold ${pascal}Page"
  back_to_main
done <<< "$PAGES"

# ─────────────────────────────────────────────────────────────
# 4. widgets — component|slug, CR-stripped
# ─────────────────────────────────────────────────────────────
log "Creating one branch per widget"

WIDGETS=$(cat <<'EOF'
KpiCard|kpi-card
TimeSeries|time-series
FunnelChart|funnel-chart
QueueTable|queue-table
Heatmap|heatmap
Gauge|gauge
AlertPanel|alert-panel
SmallGroupGuard|small-group-guard
EOF
)

while IFS='|' read -r comp slug; do
  comp="$(echo "$comp" | tr -d '\r' | tr -d ' ')"
  slug="$(echo "$slug" | tr -d '\r' | tr -d ' ')"
  [[ -z "$comp" || -z "$slug" ]] && continue

  branch="comp/widgets/${slug}"
  log "Creating $branch"
  ensure_branch "$branch"

  mkdir -p "src/widgets/${comp}"

  write "src/widgets/${comp}/${comp}.tsx" <<EOF2
export interface ${comp}Props { /* TODO */ }
export function ${comp}(_props: ${comp}Props) {
  return <div data-testid="${slug}" />;
}
EOF2

  write "src/widgets/${comp}/${comp}.test.tsx" <<EOF2
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { ${comp} } from './${comp}';

describe('${comp}', () => {
  it('renders', () => {
    render(<${comp} />);
    expect(screen.getByTestId('${slug}')).toBeInTheDocument();
  });
});
EOF2

  write "src/widgets/${comp}/index.ts" <<EOF2
export * from './${comp}';
EOF2

  commit_if_dirty "comp(widgets): scaffold ${comp}"
  back_to_main
done <<< "$WIDGETS"

# ─────────────────────────────────────────────────────────────
# 5. API contracts
# ─────────────────────────────────────────────────────────────
log "Creating feat/api/contracts"
ensure_branch feat/api/contracts

write src/api/types.ts <<'EOF'
export type Site = 'FR' | 'PT';
export type Confidence = 'low' | 'medium' | 'high';
export interface KpiSnapshot {
  metric_name: string;
  value: number;
  unit: 'seconds'|'hours'|'days'|'count'|'ratio'|'percent';
  period: string;
  site?: Site;
  rubric_version: string;
  baseline?: number;
  target?: number;
  status: 'ok'|'watch'|'alert';
  last_refresh: string;
}
EOF

write src/api/client.ts <<'EOF'
const BASE = '/api';
export async function getJson<T>(path: string): Promise<T> {
  const r = await fetch(`${BASE}${path}`, { credentials: 'include' });
  if (!r.ok) throw new Error(`GET ${path} failed: ${r.status}`);
  return r.json() as Promise<T>;
}
EOF

commit_if_dirty "feat(api): add contracts + client"
back_to_main

# ─────────────────────────────────────────────────────────────
# 6. RBAC
# ─────────────────────────────────────────────────────────────
log "Creating feat/auth/rbac"
ensure_branch feat/auth/rbac

write src/auth/rbac.ts <<'EOF'
export type Role = 'recruiter' | 'hm' | 'hrd' | 'dpo' | 'mco';
export type Page =
  | 'overview' | 'pipeline' | 'queue' | 'quality'
  | 'fairness' | 'operations' | 'governance' | 'rubric';

export const RBAC: Record<Role, Page[]> = {
  recruiter: ['overview', 'queue'],
  hm:        ['overview', 'pipeline', 'queue', 'rubric'],
  hrd:       ['overview', 'pipeline', 'queue', 'quality', 'fairness', 'governance', 'rubric'],
  dpo:       ['overview', 'fairness', 'governance', 'rubric'],
  mco:       ['overview', 'pipeline', 'queue', 'quality', 'operations', 'rubric'],
};

export const canAccess = (role: Role, page: Page) => RBAC[role].includes(page);
EOF

write src/auth/rbac.test.ts <<'EOF'
import { describe, it, expect } from 'vitest';
import { RBAC, canAccess, type Role } from './rbac';

describe('RBAC matrix', () => {
  it('every role has Overview', () => {
    for (const role of Object.keys(RBAC) as Role[]) {
      expect(canAccess(role, 'overview')).toBe(true);
    }
  });
  it('fairness restricted to hrd + dpo', () => {
    for (const role of Object.keys(RBAC) as Role[]) {
      expect(canAccess(role, 'fairness')).toBe(['hrd','dpo'].includes(role));
    }
  });
});
EOF

commit_if_dirty "feat(auth): RBAC matrix + tests"
back_to_main

# ─────────────────────────────────────────────────────────────
# 7. i18n
# ─────────────────────────────────────────────────────────────
log "Creating feat/i18n/fr-en"
ensure_branch feat/i18n/fr-en

write src/i18n/fr.json <<'EOF'
{
  "app.title": "Copilote ATS",
  "kpi.median_handling_time": "Temps de traitement median",
  "common.refresh": "Derniere mise a jour"
}
EOF

write src/i18n/en.json <<'EOF'
{
  "app.title": "ATS Copilot",
  "kpi.median_handling_time": "Median handling time",
  "common.refresh": "Last refresh"
}
EOF

commit_if_dirty "feat(i18n): fr + en catalogs"
back_to_main

# ─────────────────────────────────────────────────────────────
# 8. Server
# ─────────────────────────────────────────────────────────────
log "Creating feat/server/read-only-api"
ensure_branch feat/server/read-only-api

write server/main.py <<'EOF'
from fastapi import FastAPI, Depends, HTTPException

app = FastAPI(title="ATS Copilot Dashboard API", version="0.1.0")

def current_role() -> str:
    return "recruiter"

RBAC = {
    "recruiter": {"overview", "queue"},
    "hm":        {"overview", "pipeline", "queue", "rubric"},
    "hrd":       {"overview", "pipeline", "queue", "quality", "fairness", "governance", "rubric"},
    "dpo":       {"overview", "fairness", "governance", "rubric"},
    "mco":       {"overview", "pipeline", "queue", "quality", "operations", "rubric"},
}

def require(page: str):
    def _inner(role: str = Depends(current_role)):
        if page not in RBAC.get(role, set()):
            raise HTTPException(status_code=403, detail="forbidden")
        return role
    return _inner

@app.get("/dashboard/kpis")
def kpis(_=Depends(require("overview"))): return {"items": []}

@app.get("/dashboard/funnel")
def funnel(_=Depends(require("pipeline"))): return {"items": []}

@app.get("/dashboard/queue")
def queue(_=Depends(require("queue"))): return {"items": []}

@app.get("/dashboard/quality")
def quality(_=Depends(require("quality"))): return {"items": []}

@app.get("/dashboard/fairness")
def fairness(_=Depends(require("fairness"))): return {"items": []}

@app.get("/dashboard/operations")
def operations(_=Depends(require("operations"))): return {"items": []}
EOF

write server/requirements.txt <<'EOF'
fastapi==0.115.0
uvicorn[standard]==0.30.6
pydantic==2.9.2
EOF

commit_if_dirty "feat(server): read-only dashboard API"
back_to_main

# ─────────────────────────────────────────────────────────────
# 9. Push (optional)
# ─────────────────────────────────────────────────────────────
if [[ -n "$PUSH_URL" ]]; then
  log "Pushing all branches to $PUSH_URL"
  if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "$PUSH_URL"
  else
    git remote add origin "$PUSH_URL"
  fi

  git push -u origin main || warn "main already pushed"

  while read -r b; do
    [[ "$b" == "main" ]] && continue
    if git ls-remote --exit-code --heads origin "$b" >/dev/null 2>&1; then
      warn "remote already has $b — skipping"
    else
      git push -u origin "$b" || warn "push failed for $b"
    fi
  done < <(git for-each-ref --format='%(refname:short)' refs/heads)

  ok "push done"
fi

# ─────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────
git checkout -q main 2>/dev/null || true

echo
ok "Repository ready at $TARGET_ABS"
echo
echo "Branches (local):"
git branch --format='  %(refname:short)'
echo
echo "Next:"
echo "  cd $TARGET_ABS"
echo "  git branch -a"
echo "  git checkout comp/widgets/kpi-card"