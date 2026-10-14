#!/usr/bin/env bash
# scripts/setup-pipeline-files.sh
# Crée les fichiers du pipeline enhancement + supprime les obsolètes.
# NE COMMITE PAS — à utiliser avant un commit manuel.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT_DIR"

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_DIM=$'\033[2m';    C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_DIM=""; C_RST=""
fi
log()  { printf '%s[setup]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok   ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn ]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
err()  { printf '%s[err  ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; }

[ -d .git ] || { err "Pas dans un dépôt git"; exit 1; }

log "Répertoire: $ROOT_DIR"

# ─── 1. Suppression des fichiers obsolètes ─────────────────────────────────
log "=== Suppression des fichiers obsolètes ==="

for f in ".github/workflows/frontend.yml" "scripts/sync-all-branches-and-merge.sh.bak"; do
  if [ -e "$f" ]; then
    rm -f "$f"
    ok "supprimé: $f"
  else
    warn "déjà absent: $f"
  fi
done

# ─── 2. Création des workflows ─────────────────────────────────────────────
log "=== Création des workflows ==="

mkdir -p .github/workflows

# a11y-ci.yml
cat > .github/workflows/a11y-ci.yml <<'YAML'
name: A11y CI

on:
  push:
    branches: ['ats-lab/**', 'main']
  pull_request:
    branches: [main]
  workflow_dispatch:

concurrency:
  group: a11y-ci-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

env:
  NODE_VERSION: '22'
  PNPM_VERSION: '9'
  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: 'true'

jobs:
  a11y-check:
    name: A11y check (jest-axe)
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with: { version: ${{ env.PNPM_VERSION }} }
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'pnpm'
      - run: pnpm install --frozen-lockfile=false

      - name: Check test:a11y script exists
        id: check
        run: |
          if node -e "process.exit(require('./package.json').scripts?.['test:a11y']?0:1)"; then
            echo "exists=true" >> "$GITHUB_OUTPUT"
          else
            echo "exists=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Check a11y config exists
        id: config
        run: |
          if [ -f vitest.a11y.config.ts ]; then
            echo "exists=true" >> "$GITHUB_OUTPUT"
          else
            echo "exists=false" >> "$GITHUB_OUTPUT"
            echo "::warning::vitest.a11y.config.ts absent — a11y tests skipped"
          fi

      - name: Run a11y tests
        if: steps.check.outputs.exists == 'true' && steps.config.outputs.exists == 'true'
        run: pnpm test:a11y

      - name: Notice
        if: steps.check.outputs.exists != 'true' || steps.config.outputs.exists != 'true'
        run: echo "A11y tests skipped (config or script missing)"
YAML
ok "créé: .github/workflows/a11y-ci.yml"

# i18n-ci.yml
cat > .github/workflows/i18n-ci.yml <<'YAML'
name: i18n CI

on:
  push:
    branches: ['ats-lab/**', 'main']
  pull_request:
    branches: [main]
  workflow_dispatch:

concurrency:
  group: i18n-ci-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

env:
  NODE_VERSION: '22'
  PNPM_VERSION: '9'
  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: 'true'

jobs:
  i18n-parity:
    name: i18n parity (FR/EN)
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with: { version: ${{ env.PNPM_VERSION }} }
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'pnpm'
      - run: pnpm install --frozen-lockfile=false
      - name: Run i18n parity check
        run: pnpm test:i18n
YAML
ok "créé: .github/workflows/i18n-ci.yml"

# storybook-ci.yml
cat > .github/workflows/storybook-ci.yml <<'YAML'
name: Storybook CI

on:
  push:
    branches: ['ats-lab/**', 'main']
  pull_request:
    branches: [main]
  workflow_dispatch:

concurrency:
  group: storybook-ci-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

env:
  NODE_VERSION: '22'
  PNPM_VERSION: '9'
  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: 'true'

jobs:
  build-storybook:
    name: Build Storybook
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with: { version: ${{ env.PNPM_VERSION }} }
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'pnpm'
      - run: pnpm install --frozen-lockfile=false

      - name: Check build-storybook script exists
        id: check
        run: |
          if node -e "process.exit(require('./package.json').scripts?.['build-storybook']?0:1)"; then
            echo "exists=true" >> "$GITHUB_OUTPUT"
          else
            echo "exists=false" >> "$GITHUB_OUTPUT"
            echo "::notice::build-storybook absent — Storybook not configured yet"
          fi

      - name: Build Storybook
        if: steps.check.outputs.exists == 'true'
        run: pnpm build-storybook

      - name: Upload Storybook artifact
        if: steps.check.outputs.exists == 'true'
        uses: actions/upload-artifact@v4
        with:
          name: storybook-${{ github.ref_name }}
          path: storybook-static/
          if-no-files-found: warn
YAML
ok "créé: .github/workflows/storybook-ci.yml"

# security-ci.yml
cat > .github/workflows/security-ci.yml <<'YAML'
name: Security CI

on:
  push:
    branches: ['ats-lab/**', 'main']
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 6 * * 1'
  workflow_dispatch:

concurrency:
  group: security-ci-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read
  pull-requests: write

env:
  NODE_VERSION: '22'
  PNPM_VERSION: '9'
  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: 'true'

jobs:
  audit:
    name: Dependency audit
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with: { version: ${{ env.PNPM_VERSION }} }
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'pnpm'
      - run: pnpm install --frozen-lockfile=false

      - name: Audit dependencies
        run: pnpm audit --audit-level=high
        continue-on-error: true

      - name: Generate JSON report
        if: always()
        run: pnpm audit --audit-level=high --json > audit-report.json || true

      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: audit-report-${{ github.ref_name }}
          path: audit-report.json
          if-no-files-found: ignore

  dependency-review:
    name: Dependency review (PR only)
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - uses: actions/dependency-review-action@v4
        with:
          fail-on-severity: high
          comment-summary-in-pr: always
YAML
ok "créé: .github/workflows/security-ci.yml"

# ─── 3. Script check-i18n-parity.ts ────────────────────────────────────────
log "=== Création du script i18n ==="

cat > scripts/check-i18n-parity.ts <<'TS'
#!/usr/bin/env tsx
/**
 * scripts/check-i18n-parity.ts
 *
 * Vérifie que les clés i18n sont identiques entre FR et EN.
 * Exit 1 si des clés manquent d'un côté.
 */

import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..');

const LOCALES = ['fr', 'en'] as const;
type Locale = typeof LOCALES[number];

function loadCatalog(locale: Locale): Record<string, string> {
  const path = resolve(ROOT, 'src', 'i18n', `${locale}.json`);
  try {
    return JSON.parse(readFileSync(path, 'utf-8'));
  } catch {
    console.error(`❌ Impossible de lire ${path}`);
    process.exit(1);
  }
}

const catalogs = Object.fromEntries(
  LOCALES.map((l) => [l, loadCatalog(l)])
) as Record<Locale, Record<string, string>>;

const allKeys = new Set<string>();
for (const l of LOCALES) {
  for (const k of Object.keys(catalogs[l])) allKeys.add(k);
}

let hasError = false;
const missing: Record<Locale, string[]> = { fr: [], en: [] };

for (const key of allKeys) {
  for (const l of LOCALES) {
    if (!(key in catalogs[l])) {
      missing[l].push(key);
      hasError = true;
    }
  }
}

if (!hasError) {
  console.log(`✅ i18n parity OK (${allKeys.size} clés, ${LOCALES.length} locales)`);
  process.exit(0);
}

console.error('❌ i18n parity BROKEN');
for (const l of LOCALES) {
  if (missing[l].length > 0) {
    console.error(`\n  Clés manquantes dans ${l}.json :`);
    for (const k of missing[l]) console.error(`    - ${k}`);
  }
}
process.exit(1);
TS
ok "créé: scripts/check-i18n-parity.ts"

# ─── 4. README.md ──────────────────────────────────────────────────────────
log "=== Mise à jour du README ==="

if [ -f README.md ]; then
  cp README.md README.md.bak
  ok "backup: README.md.bak"
fi

cat > README.md <<'MD'
# ATS Copilot Dashboard

[![Dashboard CI](https://github.com/AbirhaouiSalah/FDE_LAB/actions/workflows/dashboard-ci.yml/badge.svg)](https://github.com/AbirhaouiSalah/FDE_LAB/actions/workflows/dashboard-ci.yml)
[![A11y CI](https://github.com/AbirhaouiSalah/FDE_LAB/actions/workflows/a11y-ci.yml/badge.svg)](https://github.com/AbirhaouiSalah/FDE_LAB/actions/workflows/a11y-ci.yml)
[![i18n CI](https://github.com/AbirhaouiSalah/FDE_LAB/actions/workflows/i18n-ci.yml/badge.svg)](https://github.com/AbirhaouiSalah/FDE_LAB/actions/workflows/i18n-ci.yml)
[![Storybook CI](https://github.com/AbirhaouiSalah/FDE_LAB/actions/workflows/storybook-ci.yml/badge.svg)](https://github.com/AbirhaouiSalah/FDE_LAB/actions/workflows/storybook-ci.yml)
[![Security CI](https://github.com/AbirhaouiSalah/FDE_LAB/actions/workflows/security-ci.yml/badge.svg)](https://github.com/AbirhaouiSalah/FDE_LAB/actions/workflows/security-ci.yml)

Copilote IA pour le pré-screening des candidats FDE (France / Porto).

## Contexte

- **Client** : ALTEN — équipe Forward Deployed Engineer (FDE)
- **Use case** : copilote IA pour le pré-screening des candidats FDE
- **Principe cardinal** : l'humain décide toujours. Le dashboard est **read-only**
- **KPI cible** : −50 % sur le temps médian de pré-screening par candidat
- **Conformité** : RGPD, EU AI Act (Annexe III), résidence EU des données

## Prérequis

- Node ≥ 20 (recommandé : 22)
- pnpm ≥ 9 (`corepack enable && corepack prepare pnpm@9.6.0 --activate`)

## Démarrage rapide

```bash
./scripts/run.sh install
./scripts/run.sh dev      # http://localhost:5173
./scripts/run.sh check    # lint + typecheck + test + build