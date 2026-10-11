#!/usr/bin/env bash
# bootstrap-and-publish.sh
# Build ATS Copilot repo skeleton + all branches, then publish to a remote.
#
# Usage:
#   ./bootstrap-and-publish.sh --url git@github.com:USER/REPO.git
#   ./bootstrap-and-publish.sh --url https://github.com/USER/REPO.git
#   ./bootstrap-and-publish.sh --url ... --reset
#   ./bootstrap-and-publish.sh --url ... --dry-run
#   ./bootstrap-and-publish.sh --url ... --no-publish

set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Args
# ─────────────────────────────────────────────────────────────
TARGET_DIR="ats-copilot-dashboard"
REMOTE_URL=""
REMOTE_NAME="origin"
DO_RESET=0
DRY_RUN=0
NO_PUBLISH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)         REMOTE_URL="${2:-}"; shift 2 ;;
    --dir)         TARGET_DIR="${2:-}"; shift 2 ;;
    --remote-name) REMOTE_NAME="${2:-}"; shift 2 ;;
    --reset)       DO_RESET=1; shift ;;
    --dry-run)     DRY_RUN=1; shift ;;
    --no-publish)  NO_PUBLISH=1; shift ;;
    -h|--help)     sed -n '2,12p' "$0"; exit 0 ;;
    *) printf "unexpected argument: %s\n" "$1" >&2; exit 1 ;;
  esac
done

# ─────────────────────────────────────────────────────────────
# Colors + logging
# ─────────────────────────────────────────────────────────────
C_RESET="\033[0m"; C_BLUE="\033[1;34m"; C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"; C_RED="\033[1;31m"; C_DIM="\033[2m"
log()  { printf "${C_BLUE}[setup]${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_GREEN}[  ok ]${C_RESET} %s\n" "$*"; }
warn() { printf "${C_YELLOW}[ warn]${C_RESET} %s\n" "$*"; }
dry()  { printf "${C_DIM}[ dry ]${C_RESET} %s\n" "$*"; }
pub()  { printf "${C_BLUE}[push ]${C_RESET} %s\n" "$*"; }
die()  { printf "${C_RED}[ fail]${C_RESET} %s\n" "$*" >&2; exit 1; }

# Print the first line of a string, in pure bash (no head/sed/awk)
first_line() { printf '%s' "${1%%$'\n'*}"; }

# ─────────────────────────────────────────────────────────────
# Pre-flight
# ─────────────────────────────────────────────────────────────
command -v git >/dev/null || die "git is required"
[[ -n "$(git config --global user.name  || true)" ]] || die "set git user.name first"
[[ -n "$(git config --global user.email || true)" ]] || die "set git user.email first"

if [[ "$(basename "$PWD")" == "$TARGET_DIR" ]]; then
  die "you are already inside $TARGET_DIR — cd .. first"
fi

if [[ -d "$TARGET_DIR/.git" && -d "$TARGET_DIR/$TARGET_DIR" ]]; then
  die "detected nested $TARGET_DIR/$TARGET_DIR — remove it first:
  rm -rf $TARGET_DIR/$TARGET_DIR"
fi

# ─────────────────────────────────────────────────────────────
# Reset
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
  if [[ "$DRY_RUN" == "1" ]]; then
    dry "would create $TARGET_DIR and git init -b main"
  else
    mkdir -p "$TARGET_DIR"
    (cd "$TARGET_DIR" && git init -q -b main)
    ok "initialized git repo at $TARGET_DIR"
  fi
fi

if [[ "$DRY_RUN" != "1" ]]; then
  cd "$TARGET_DIR"
fi
REPO_ABS="$(pwd)"
log "working directory: $REPO_ABS"

if [[ "$DRY_RUN" != "1" ]]; then
  [[ "$(basename "$REPO_ABS")" == "$TARGET_DIR" ]] \
    || die "failed to enter $TARGET_DIR (got $(basename "$REPO_ABS"))"
fi

# ─────────────────────────────────────────────────────────────
# Branch name validation (scope optional)
# ─────────────────────────────────────────────────────────────
validate_branch() {
  local b="$1"
  [[ "$b" =~ ^(comp|feat|fix|chore|docs|spike)/[a-z0-9-]+(/[a-z0-9-]+)?$ ]] \
    || die "invalid branch name: '$b'"
}

# ─────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────
ORIG_BRANCH=""
on_error() {
  if [[ -n "$ORIG_BRANCH" && "$DRY_RUN" != "1" ]]; then
    warn "error — restoring to $ORIG_BRANCH"
    git checkout -q "$ORIG_BRANCH" 2>/dev/null || true
  fi
}
trap on_error ERR

ensure_branch() {
  local branch="$1"
  validate_branch "$branch"
  if [[ "$DRY_RUN" == "1" ]]; then
    dry "would create/checkout $branch"
    return 0
  fi
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
  if [[ "$DRY_RUN" == "1" ]]; then
    dry "would commit: $msg"
    return 0
  fi
  if [[ -n "$(git status --porcelain)" ]]; then
    git add -A
    git commit -q -m "$msg"
    ok "committed: $msg"
  else
    warn "nothing to commit on $(git rev-parse --abbrev-ref HEAD)"
  fi
}

back_to_main() { git checkout -q main 2>/dev/null || true; }

write() {
  local path="$1"
  if [[ "$DRY_RUN" == "1" ]]; then
    dry "would write $path"
    cat >/dev/null
    return 0
  fi
  mkdir -p "$(dirname "$path")"
  cat > "$path"
}

# ─────────────────────────────────────────────────────────────
# SSH check — no external tools
# ─────────────────────────────────────────────────────────────
check_ssh_github() {
  local out rc
  set +e
  out="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1)"
  rc=$?
  set -e

  # Pure-bash regex match, no grep/head
  if [[ "$out" =~ [Ss]uccessfully\ authenticated ]] \
     || [[ "$out" =~ ^Hi\ [A-Za-z0-9_-]+! ]]; then
    ok "SSH auth confirmed: $(first_line "$out")"
    return 0
  fi

  warn "SSH auth inconclusive (rc=$rc): $(first_line "$out")"
  return 1
}

# ─────────────────────────────────────────────────────────────
# Phase A — main skeleton
# ─────────────────────────────────────────────────────────────
log "Phase A — bootstrapping main skeleton"

if [[ "$DRY_RUN" != "1" ]]; then
  mkdir -p \
    .github/workflows scripts docs \
    src/app/shell src/pages src/widgets src/api src/auth src/i18n \
    mock/seeds server/routers server/tests public
fi

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

`<type>/<scope>/<short-description>` or `<type>/<description>`

types: comp | feat | fix | chore | docs | spike
EOF

write src/app/main.tsx <<'EOF'
export const APP_NAME = 'ats-copilot-dashboard';
EOF

if [[ "$DRY_RUN" != "1" ]]; then
  for d in src/app/shell src/pages src/widgets src/api src/auth src/i18n \
           mock/seeds server/routers server/tests public; do
    touch "$d/.gitkeep"
  done
fi

commit_if_dirty "chore: bootstrap repository skeleton"

# ─────────────────────────────────────────────────────────────
# Phase B — CI
# ─────────────────────────────────────────────────────────────
log "Phase B — CI"
ensure_branch chore/ci/frontend-pipeline
write .github/workflows/frontend.yml <<'EOF'
name: Frontend CI
on:
  push:
    branches: ['**']
  pull_request:
    branches: [main]
jobs:
  validate-branch-name:
    if: github.ref != 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - run: |
          B="${GITHUB_REF#refs/heads/}"
          [[ "$B" =~ ^(comp|feat|fix|chore|docs|spike)/[a-z0-9-]+(/[a-z0-9-]+)?$ ]] || exit 1
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "pnpm lint"
  test:
    needs: lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "pnpm test"
EOF
commit_if_dirty "chore(ci): add frontend workflow"
back_to_main

# ─────────────────────────────────────────────────────────────
# Phase C — shell
# ─────────────────────────────────────────────────────────────
log "Phase C — shell"
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
# Phase D — pages
# ─────────────────────────────────────────────────────────────
log "Phase D — pages"
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
  slug="${slug//[[:space:]]/}"
  pascal="${pascal//[[:space:]]/}"
  [[ -z "$slug" || -z "$pascal" ]] && continue
  branch="comp/${slug}/page"
  log "  → $branch"
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
# Phase E — widgets
# ─────────────────────────────────────────────────────────────
log "Phase E — widgets"
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
  comp="${comp//[[:space:]]/}"
  slug="${slug//[[:space:]]/}"
  [[ -z "$comp" || -z "$slug" ]] && continue
  branch="comp/widgets/${slug}"
  log "  → $branch"
  ensure_branch "$branch"
  if [[ "$DRY_RUN" != "1" ]]; then mkdir -p "src/widgets/${comp}"; fi
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
# Phase F — api
# ─────────────────────────────────────────────────────────────
log "Phase F — api"
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
# Phase G — RBAC
# ─────────────────────────────────────────────────────────────
log "Phase G — RBAC"
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
# Phase H — i18n
# ─────────────────────────────────────────────────────────────
log "Phase H — i18n"
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
# Phase I — server
# ─────────────────────────────────────────────────────────────
log "Phase I — server"
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
# Phase J — docs
# ─────────────────────────────────────────────────────────────
log "Phase J — docs"
ensure_branch docs/spec/dashboard
write docs/dashboard-spec.md <<'EOF'
# Follow-up dashboard specification

Eight pages: Overview, Pipeline, Queue, Quality, Fairness, Operations, Governance, Rubric.
EOF
commit_if_dirty "docs(spec): dashboard specification"
back_to_main

# ─────────────────────────────────────────────────────────────
# Phase K — publish
# ─────────────────────────────────────────────────────────────
if [[ "$NO_PUBLISH" == "1" ]]; then
  warn "skipping publish (--no-publish)"
elif [[ -z "$REMOTE_URL" ]]; then
  warn "no --url given — skipping publish phase"
  warn "re-run with: $0 --url git@github.com:USER/REPO.git"
else
  log "Phase K — publishing to $REMOTE_URL"

  if [[ "$DRY_RUN" == "1" ]]; then
    dry "would push all branches to $REMOTE_URL"
  else
    # Clean working tree required
    if [[ -n "$(git status --porcelain)" ]]; then
      warn "working tree dirty:"
      git status --short | sed 's/^/  /'
      die "commit or stash before publishing"
    fi

    # Configure remote
    if git remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
      log "updating remote '$REMOTE_NAME'"
      git remote set-url "$REMOTE_NAME" "$REMOTE_URL"
    else
      log "adding remote '$REMOTE_NAME'"
      git remote add "$REMOTE_NAME" "$REMOTE_URL"
    fi
    git remote -v | sed 's/^/  /'

    # SSH check (only for SSH URLs)
    if [[ "$REMOTE_URL" =~ ^git@github\.com ]]; then
      log "checking SSH auth to github.com"
      check_ssh_github || warn "continuing anyway — push may still work"
    fi

    # Verify remote reachability — print the real git error
    log "verifying remote reachability"
    set +e
    LS_OUT="$(git ls-remote --exit-code "$REMOTE_NAME" 2>&1)"
    LS_RC=$?
    set -e
    if [[ $LS_RC -ne 0 ]]; then
      warn "git ls-remote failed (rc=$LS_RC):"
      printf '%s\n' "$LS_OUT" | sed 's/^/    /'
      die "remote '$REMOTE_NAME' is not reachable at $REMOTE_URL
  common causes:
    - repo does not exist on GitHub (create it: https://github.com/new)
    - wrong owner/name in the URL
    - SSH key not associated with the repo
    - case-sensitive name mismatch"
    fi
    ok "remote reachable"

    # Push main
    pub "main"
    if git ls-remote --exit-code --heads "$REMOTE_NAME" main >/dev/null 2>&1; then
      git push "$REMOTE_NAME" main
    else
      git push -u "$REMOTE_NAME" main
    fi
    ok "main pushed"

    # Push every other branch
    PUSHED=0; SKIPPED=0; FAILED=0
    while read -r branch; do
      [[ "$branch" == "main" ]] && continue
      pub "$branch"
      if git ls-remote --exit-code --heads "$REMOTE_NAME" "$branch" >/dev/null 2>&1; then
        warn "  already on remote — skipping"
        SKIPPED=$((SKIPPED + 1))
        continue
      fi
      if git push -u "$REMOTE_NAME" "$branch" >/dev/null 2>&1; then
        ok "  pushed"
        PUSHED=$((PUSHED + 1))
      else
        printf "${C_RED}  push failed${C_RESET}\n"
        FAILED=$((FAILED + 1))
      fi
    done < <(git for-each-ref --format='%(refname:short)' refs/heads)

    echo
    ok "publish summary"
    printf "  pushed:  %d\n" "$PUSHED"
    printf "  skipped: %d\n" "$SKIPPED"
    printf "  failed:  %d\n" "$FAILED"

    # Pure-bash count of remote branches
    REMOTE_LS="$(git ls-remote --heads "$REMOTE_NAME" 2>/dev/null || true)"
    REMOTE_COUNT=0
    if [[ -n "$REMOTE_LS" ]]; then
      while IFS= read -r _; do REMOTE_COUNT=$((REMOTE_COUNT + 1)); done <<< "$REMOTE_LS"
    fi
    printf "  remote branches: %s\n" "$REMOTE_COUNT"

    [[ "$FAILED" -gt 0 ]] && exit 1
  fi
fi

# ─────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────
echo
ok "bootstrap complete"
log "local branches:"
git branch --format='  %(refname:short)' | sort

echo
log "next:"
printf "  cd %s\n" "$REPO_ABS"
printf "  pnpm install\n"
printf "  pnpm dev\n"