#!/usr/bin/env bash
# setup-test-infra.sh
# Bootstrap de l'infrastructure de test pour ATS Copilot Dashboard.
# Idempotent, dry-run supporté, sauvegarde avant écrasement.
#
# Usage:
#   ./setup-test-infra.sh                    # applique tout
#   ./setup-test-infra.sh --dry-run          # preview
#   ./setup-test-infra.sh --no-install       # skip pnpm install / playwright install
#   ./setup-test-infra.sh --branch <name>    # crée la branche avant d'appliquer

set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Config
# ─────────────────────────────────────────────────────────────
BRANCH_NAME="ats-lab/chore/tests/setup"
CREATE_BRANCH=0
DO_INSTALL=1
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch)     BRANCH_NAME="${2:-}"; CREATE_BRANCH=1; shift 2 ;;
    --no-install) DO_INSTALL=0; shift ;;
    --dry-run)    DRY_RUN=1; shift ;;
    -h|--help)
      sed -n '2,12p' "$0"; exit 0 ;;
    *) printf 'unexpected arg: %s\n' "$1" >&2; exit 1 ;;
  esac
done

# ─────────────────────────────────────────────────────────────
# Couleurs + log
# ─────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_DIM=$'\033[2m';    C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_DIM=""; C_RST=""
fi

log()  { printf '%s[infra]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ ok  ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn ]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
dry()  { printf '%s[ dry ]%s %s\n' "$C_DIM" "$C_RST" "$*"; }
die()  { printf '%s[fail ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; exit 1; }

# ─────────────────────────────────────────────────────────────
# Pre-flight
# ─────────────────────────────────────────────────────────────
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repo"

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
log "repo: $REPO_ROOT"

# Refuse to run on a dirty tree unless --dry-run
if [[ "$DRY_RUN" != "1" ]] && [[ -n "$(git status --porcelain)" ]]; then
  warn "working tree has uncommitted changes:"
  git status --short | sed 's/^/    /'
  die "commit or stash before running"
fi

# ─────────────────────────────────────────────────────────────
# Optional branch creation
# ─────────────────────────────────────────────────────────────
if [[ "$CREATE_BRANCH" == "1" ]]; then
  log "creating branch: $BRANCH_NAME"
  if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    warn "branch $BRANCH_NAME already exists — checking out"
    [[ "$DRY_RUN" == "1" ]] || git checkout "$BRANCH_NAME"
  else
    [[ "$DRY_RUN" == "1" ]] || git checkout -b "$BRANCH_NAME"
    ok "branch $BRANCH_NAME created"
  fi
fi

# ─────────────────────────────────────────────────────────────
# Backup helper
# ─────────────────────────────────────────────────────────────
BACKUP_DIR=".setup-backup-$(date +%Y%m%d-%H%M%S)"
backup() {
  local f="$1"
  [[ ! -f "$f" ]] && return 0
  [[ "$DRY_RUN" == "1" ]] && return 0
  mkdir -p "$BACKUP_DIR/$(dirname "$f")"
  cp "$f" "$BACKUP_DIR/$f"
  log "backed up $f → $BACKUP_DIR/$f"
}

# write helper
write() {
  local path="$1"
  if [[ "$DRY_RUN" == "1" ]]; then
    dry "would write $path"
    cat >/dev/null
    return 0
  fi
  mkdir -p "$(dirname "$path")"
  cat > "$path"
  ok "wrote $path"
}

# ensure line in file
ensure_line() {
  local file="$1" line="$2"
  [[ "$DRY_RUN" == "1" ]] && { dry "would ensure '$line' in $file"; return 0; }
  touch "$file"
  if ! grep -qxF "$line" "$file"; then
    printf '%s\n' "$line" >> "$file"
    ok "appended '$line' to $file"
  fi
}

# ─────────────────────────────────────────────────────────────
# 1. package.json
# ─────────────────────────────────────────────────────────────
log "1/11 — package.json"
backup package.json
write package.json <<'EOF'
{
  "name": "ats-copilot-dashboard",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "packageManager": "pnpm@9.6.0",
  "engines": { "node": ">=20 <23" },
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "lint": "eslint . --max-warnings 0",
    "typecheck": "tsc --noEmit",
    "test": "vitest",
    "test:a11y": "vitest run --config vitest.a11y.config.ts",
    "test:rbac": "vitest run src/auth/rbac.test.ts",
    "test:i18n": "tsx scripts/check-i18n-parity.ts",
    "test:e2e": "playwright test",
    "test:e2e:ui": "playwright test --ui",
    "test:e2e:install": "playwright install --with-deps chromium",
    "coverage": "vitest run --coverage"
  },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": {
    "@playwright/test": "^1.45.3",
    "@testing-library/jest-dom": "^6.4.6",
    "@testing-library/react": "^16.0.0",
    "@testing-library/user-event": "^14.5.2",
    "@types/jest-axe": "^3.5.9",
    "@types/react": "^18.3.3",
    "@types/react-dom": "^18.3.0",
    "@vitejs/plugin-react": "^4.3.1",
    "@vitest/coverage-v8": "^2.0.2",
    "eslint": "^8.57.0",
    "jest-axe": "^9.0.0",
    "jsdom": "^24.1.0",
    "tsx": "^4.16.2",
    "typescript": "^5.5.3",
    "vite": "^5.3.3",
    "vitest": "^2.0.2"
  }
}
EOF

# ─────────────────────────────────────────────────────────────
# 2. vitest.a11y.config.ts
# ─────────────────────────────────────────────────────────────
log "2/11 — vitest.a11y.config.ts"
write vitest.a11y.config.ts <<'EOF'
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    name: 'a11y',
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./vitest.a11y.setup.ts'],
    include: ['src/**/*.a11y.test.{ts,tsx}'],
    exclude: ['node_modules', 'dist', 'coverage'],
    reporters: ['default'],
    testTimeout: 10000
  }
});
EOF

# ─────────────────────────────────────────────────────────────
# 3. vitest.a11y.setup.ts
# ─────────────────────────────────────────────────────────────
log "3/11 — vitest.a11y.setup.ts"
write vitest.a11y.setup.ts <<'EOF'
import '@testing-library/jest-dom/vitest';
import { expect } from 'vitest';
import { toHaveNoViolations } from 'jest-axe';

expect.extend(toHaveNoViolations);

if (typeof window !== 'undefined' && !window.matchMedia) {
  window.matchMedia = (query: string) =>
    ({
      matches: false,
      media: query,
      onchange: null,
      addListener: () => void 0,
      removeListener: () => void 0,
      addEventListener: () => void 0,
      removeEventListener: () => void 0,
      dispatchEvent: () => false
    }) as MediaQueryList;
}
EOF

# ─────────────────────────────────────────────────────────────
# 4. playwright.config.ts
# ─────────────────────────────────────────────────────────────
log "4/11 — playwright.config.ts"
write playwright.config.ts <<'EOF'
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 2 : undefined,
  reporter: process.env.CI
    ? [['html', { open: 'never' }], ['github']]
    : [['list'], ['html', { open: 'never' }]],
  timeout: 30_000,
  expect: { timeout: 5_000 },
  use: {
    baseURL: process.env.E2E_BASE_URL ?? 'http://localhost:5173',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure'
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: process.env.E2E_BASE_URL
    ? undefined
    : {
        command: 'pnpm dev',
        url: 'http://localhost:5173',
        reuseExistingServer: !process.env.CI,
        timeout: 60_000
      }
});
EOF

# ─────────────────────────────────────────────────────────────
# 5. e2e/smoke.spec.ts
# ─────────────────────────────────────────────────────────────
log "5/11 — e2e/smoke.spec.ts"
write e2e/smoke.spec.ts <<'EOF'
import { test, expect } from '@playwright/test';

test.describe('Smoke — app loads', () => {
  test('root page renders without crashing', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('body')).toBeVisible();
  });

  test('has no console errors on load', async ({ page }) => {
    const errors: string[] = [];
    page.on('pageerror', (err) => errors.push(err.message));
    page.on('console', (msg) => {
      if (msg.type() === 'error') errors.push(msg.text());
    });
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    expect(errors).toEqual([]);
  });
});
EOF

# ─────────────────────────────────────────────────────────────
# 6. e2e/README.md
# ─────────────────────────────────────────────────────────────
log "6/11 — e2e/README.md"
write e2e/README.md <<'EOF'
# E2E tests — Playwright

## Setup (une seule fois)

```bash
pnpm test:e2e:install
