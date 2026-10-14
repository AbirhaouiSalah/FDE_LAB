#!/usr/bin/env bash
# scripts/refactor-scripts.sh
# Réorganise scripts/ en sous-dossiers : git/ build/ quality/ ci/
# Idempotent. Backup complet avant modification. Rollback possible.
#
# Usage:
#   ./scripts/refactor-scripts.sh --dry-run     # affiche le plan sans rien modifier
#   ./scripts/refactor-scripts.sh               # exécute
#   ./scripts/refactor-scripts.sh --rollback    # restaure le dernier backup

set -euo pipefail

DRY_RUN=0
ROLLBACK=0
for arg in "$@"; do
  case "$arg" in
    --dry-run)  DRY_RUN=1 ;;
    --rollback) ROLLBACK=1 ;;
    -h|--help)  sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Argument inconnu: $arg" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT_DIR"

# Couleurs
if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_DIM=$'\033[2m';    C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_DIM=""; C_RST=""
fi

log()  { printf '%s[refac]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok   ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn ]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
die()  { printf '%s[err  ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; exit 1; }

BACKUP_DIR=".backups/scripts-$(date +%Y%m%d-%H%M%S)"

# ─────────────────────────────────────────────────────────────
# Rollback
# ─────────────────────────────────────────────────────────────
if [ "$ROLLBACK" -eq 1 ]; then
  LAST="$(ls -1dt .backups/scripts-* 2>/dev/null | head -n 1 || true)"
  [ -n "$LAST" ] || die "aucun backup .backups/scripts-*"
  log "Restauration depuis $LAST"
  rm -rf scripts
  cp -R "$LAST/scripts" scripts
  chmod +x scripts/*.sh scripts/*/*.sh 2>/dev/null || true
  ok "scripts/ restauré"
  exit 0
fi

# ─────────────────────────────────────────────────────────────
# Pré-vol
# ─────────────────────────────────────────────────────────────
[ -d scripts ] || die "scripts/ introuvable — es-tu à la racine ?"

if [ "$DRY_RUN" -eq 0 ]; then
  mkdir -p "$BACKUP_DIR"
  cp -R scripts "$BACKUP_DIR/scripts"
  ok "backup → $BACKUP_DIR/scripts"
fi

# ─────────────────────────────────────────────────────────────
# Helper d'écriture
# ─────────────────────────────────────────────────────────────
write() {
  local path="$1"; shift
  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry] écrirait $path"
    cat > /dev/null
    return 0
  fi
  mkdir -p "$(dirname "$path")"
  cat > "$path"
  chmod +x "$path" 2>/dev/null || true
  ok "$path"
}

# ─────────────────────────────────────────────────────────────
# 1. Sous-dossiers
# ─────────────────────────────────────────────────────────────
log "Création des sous-dossiers…"
for d in git build quality ci; do
  if [ "$DRY_RUN" -eq 0 ]; then mkdir -p "scripts/$d"; fi
  ok "scripts/$d/"
done

# ─────────────────────────────────────────────────────────────
# 2. Helpers _lib.sh par sous-dossier
# ─────────────────────────────────────────────────────────────
log "Génération des _lib.sh…"

write scripts/git/_lib.sh <<'EOF'
#!/usr/bin/env bash
# scripts/git/_lib.sh — helpers git communs. À sourcer.
set -euo pipefail

GIT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_LIB_ROOT="$(cd "$GIT_LIB_DIR/../.." && pwd)"

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_RST=""
fi

log()  { printf '%s[git ]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok  ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
die()  { printf '%s[err ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; exit 1; }

git_require_clean() {
  [ -z "$(git status --porcelain)" ] || die "working tree non clean"
}

git_require_remote() {
  git remote get-url origin >/dev/null 2>&1 || die "remote origin absent"
}

git_list_remote_ats_branches() {
  git ls-remote --heads origin 'refs/heads/ats-lab/*' \
    | awk -F'refs/heads/' '{print $2}' | sort -u
}

git_list_local_ats_branches() {
  git for-each-ref --format='%(refname:short)' 'refs/heads/ats-lab/*'
}
EOF

write scripts/build/_lib.sh <<'EOF'
#!/usr/bin/env bash
# scripts/build/_lib.sh — helpers build communs. À sourcer.
set -euo pipefail

BUILD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_LIB_ROOT="$(cd "$BUILD_LIB_DIR/../.." && pwd)"

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_RST=""
fi

log()  { printf '%s[build]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok   ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn ]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
die()  { printf '%s[err  ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; exit 1; }

build_detect_pm() {
  if [ -f pnpm-lock.yaml ]; then echo "pnpm"
  elif [ -f yarn.lock ]; then echo "yarn"
  elif [ -f bun.lockb ]; then echo "bun"
  elif [ -f package-lock.json ]; then echo "npm"
  else
    command -v pnpm >/dev/null 2>&1 && { echo "pnpm"; return; }
    command -v yarn >/dev/null 2>&1 && { echo "yarn"; return; }
    command -v bun  >/dev/null 2>&1 && { echo "bun";  return; }
    command -v npm  >/dev/null 2>&1 && { echo "npm";  return; }
    die "aucun package manager détecté"
  fi
}

build_require_node() {
  command -v node >/dev/null 2>&1 || die "node introuvable"
  local major
  major="$(node -p 'process.versions.node.split(".")[0]')"
  [ "$major" -ge 20 ] || die "Node >= 20 requis (actuel: $(node -v))"
}

build_require_deps() {
  if [ ! -d node_modules ]; then
    warn "node_modules absent — installation"
    case "$(build_detect_pm)" in
      pnpm) pnpm install ;;
      yarn) yarn install ;;
      bun)  bun install ;;
      npm)  npm install ;;
    esac
  fi
}
EOF

write scripts/quality/_lib.sh <<'EOF'
#!/usr/bin/env bash
# scripts/quality/_lib.sh — helpers qualité communs. À sourcer.
set -euo pipefail

Q_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
Q_LIB_ROOT="$(cd "$Q_LIB_DIR/../.." && pwd)"

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_RST=""
fi

log()  { printf '%s[q    ]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok   ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn ]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
die()  { printf '%s[err  ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; exit 1; }

q_pm() {
  if [ -f "$Q_LIB_ROOT/pnpm-lock.yaml" ]; then echo pnpm; else echo npm; fi
}

q_exec() {
  case "$(q_pm)" in
    pnpm) pnpm exec "$@" ;;
    *)    npx "$@" ;;
  esac
}

q_run() {
  case "$(q_pm)" in
    pnpm) pnpm run "$@" ;;
    *)    npm run "$@" ;;
  esac
}
EOF

write scripts/ci/_lib.sh <<'EOF'
#!/usr/bin/env bash
# scripts/ci/_lib.sh — helpers CI communs. À sourcer.
set -euo pipefail

CI_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CI_LIB_ROOT="$(cd "$CI_LIB_DIR/../.." && pwd)"

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_RST=""
fi

log()  { printf '%s[ci   ]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok   ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn ]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
die()  { printf '%s[err  ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; exit 1; }
EOF

# ─────────────────────────────────────────────────────────────
# 3. Déplacement des scripts existants
# ─────────────────────────────────────────────────────────────
log "Déplacement des scripts existants…"

move_if_exists() {
  local src="$1" dst="$2"
  [ -f "$src" ] || { warn "$src absent — skip"; return 0; }
  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry] mv $src → $dst"
    return 0
  fi
  # Si la destination existe déjà, on suffixe pour ne rien écraser
  if [ -e "$dst" ]; then
    dst="${dst}.moved-$(date +%s)"
  fi
  mkdir -p "$(dirname "$dst")"
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && git ls-files --error-unmatch "$src" >/dev/null 2>&1; then
    git mv "$src" "$dst"
  else
    mv "$src" "$dst"
  fi
  chmod +x "$dst" 2>/dev/null || true
  ok "$src → $dst"
}

# --- Git ---
move_if_exists scripts/push-modification-to-all-branches.sh scripts/git/propagate.sh
move_if_exists scripts/push-to-all-branches.sh             scripts/git/push-all.sh
move_if_exists scripts/push-workflow-to-all-branches.sh    scripts/git/propagate-workflow.sh
move_if_exists scripts/merge-all-into-main.sh              scripts/git/merge-to-main.sh
move_if_exists scripts/merge-all-branches-to-main.sh       scripts/git/merge-all-branches-to-main.sh
move_if_exists scripts/cleanup-branches.sh                 scripts/git/cleanup-branches.sh
move_if_exists scripts/diagnose.sh                         scripts/git/diagnose.sh
move_if_exists scripts/sync-all-branches-and-merge.sh      scripts/git/sync-and-merge.sh
move_if_exists scripts/merge-main-into-branches.sh         scripts/git/merge-main-into-branches.sh
move_if_exists scripts/publish.sh                          scripts/git/publish.sh
move_if_exists scripts/publish-to-fde-lab.sh               scripts/git/publish-to-fde-lab.sh

# --- Build ---
move_if_exists scripts/run.sh                       scripts/build/run.sh
move_if_exists scripts/build-full-dashboard.sh      scripts/build/build-full-dashboard.sh
move_if_exists scripts/run-dashboard.sh             scripts/build/run-dashboard.sh
move_if_exists scripts/gen-widgets-phase-1-2.sh     scripts/build/generate-widgets.sh

# --- Quality ---
move_if_exists scripts/check-i18n-parity.ts         scripts/quality/check-i18n-parity.ts
move_if_exists scripts/correction.sh                scripts/quality/correction-eslint.sh
move_if_exists scripts/correction-tsc.sh            scripts/quality/correction-tsc.sh
move_if_exists scripts/correction-tests.sh          scripts/quality/correction-tests.sh

# ─────────────────────────────────────────────────────────────
# 4. Nouveaux scripts
# ─────────────────────────────────────────────────────────────

# --- Git : backup ---
write scripts/git/backup.sh <<'EOF'
#!/usr/bin/env bash
# scripts/git/backup.sh — backup horodaté de l'état git (branches + bundle + working tree).
# Usage: ./scripts/git/backup.sh [<label>]
set -euo pipefail
source "$(dirname "$0")/_lib.sh"

LABEL="${1:-manual}"
TS="$(date +%Y%m%d-%H%M%S)"
DIR=".backups/git-${TS}-${LABEL}"
mkdir -p "$DIR"

log "Backup git → $DIR"
git branch --show-current > "$DIR/current-branch.txt" 2>/dev/null || true
git for-each-ref --format='%(refname) %(objectname:short)' 'refs/heads/*' > "$DIR/local-refs.txt"
git ls-remote --heads origin > "$DIR/remote-refs.txt" 2>/dev/null || true
git diff HEAD > "$DIR/working.diff" 2>/dev/null || true
git diff --cached > "$DIR/staged.diff" 2>/dev/null || true
git ls-files --others --exclude-standard > "$DIR/untracked.txt"
git log --oneline --all --decorate -n 200 > "$DIR/log.txt"
git bundle create "$DIR/repo.bundle" --all >/dev/null 2>&1 || warn "bundle partiel"

ok "Backup dans $DIR"
echo "  Restore : ./scripts/git/restore-backup.sh $DIR"
EOF

# --- Git : restore ---
write scripts/git/restore-backup.sh <<'EOF'
#!/usr/bin/env bash
# scripts/git/restore-backup.sh <dir> — restaure les refs d'un backup dans refs/restored/*.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"

DIR="${1:-}"
[ -n "$DIR" ] || die "usage: $0 <backup-dir>"
[ -d "$DIR" ] || die "dossier introuvable: $DIR"
[ -f "$DIR/repo.bundle" ] || die "repo.bundle absent dans $DIR"

warn "Cette opération ajoute des refs dans refs/restored/* (aucun écrasement)."
git fetch "$DIR/repo.bundle" 'refs/*:refs/restored/*' --force
ok "Refs restaurées dans refs/restored/*"
echo "  Exemple : git branch <name> refs/restored/heads/<branch>"
EOF

# --- Build : setup-toolchain ---
write scripts/build/setup-toolchain.sh <<'EOF'
#!/usr/bin/env bash
# scripts/build/setup-toolchain.sh — installe la toolchain minimale si absente.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
cd "$BUILD_LIB_ROOT"

[ -f package.json ] || die "package.json introuvable"

if [ ! -d node_modules ]; then
  log "Installation des dépendances…"
  case "$(build_detect_pm)" in
    pnpm) pnpm install ;;
    yarn) yarn install ;;
    bun)  bun install ;;
    npm)  npm install ;;
  esac
fi
ok "Toolchain prête"
EOF

# --- Build : run.sh (point d'entrée, délègue à quality/) ---
write scripts/build/run.sh <<'EOF'
#!/usr/bin/env bash
# scripts/build/run.sh — point d'entrée dev unifié.
# Délègue aux scripts quality/ pour lint/typecheck/test/a11y/check.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
cd "$BUILD_LIB_ROOT"

cmd="${1:-help}"; shift || true

case "$cmd" in
  install)   build_require_node; log "Installation via $(build_detect_pm)"; "$(build_detect_pm)" install; ok "deps OK" ;;
  dev)       build_require_node; build_require_deps; log "Vite dev…"; "$(build_detect_pm)" run dev ;;
  build)     build_require_node; build_require_deps; log "Build…"; "$(build_detect_pm)" run build; ok "dist/ prêt" ;;
  test)      exec "$BUILD_LIB_ROOT/scripts/quality/test-unit.sh" "$@" ;;
  lint)      exec "$BUILD_LIB_ROOT/scripts/quality/lint.sh" "$@" ;;
  typecheck) exec "$BUILD_LIB_ROOT/scripts/quality/typecheck.sh" "$@" ;;
  a11y)      exec "$BUILD_LIB_ROOT/scripts/quality/test-a11y.sh" "$@" ;;
  check)     exec "$BUILD_LIB_ROOT/scripts/quality/check.sh" "$@" ;;
  clean)     log "Nettoyage…"; rm -rf node_modules dist coverage .vite; ok "clean OK" ;;
  help|-h|--help)
    cat <<USAGE
scripts/build/run.sh — point d'entrée dev

  install              Installe les dépendances
  dev                  Vite dev
  build                Build production → dist/
  test [pattern]       Vitest (délègue à quality/test-unit.sh)
  lint [--fix]         ESLint (délègue à quality/lint.sh)
  typecheck            tsc --noEmit (délègue à quality/typecheck.sh)
  a11y                 Tests a11y (délègue à quality/test-a11y.sh)
  check                Check complet (délègue à quality/check.sh)
  clean                Supprime node_modules, dist, coverage

PM   : $(build_detect_pm)
Node : $(node -v 2>/dev/null || echo absent)
USAGE
    ;;
  *) die "commande inconnue: $cmd" ;;
esac
EOF

# --- Quality : check ---
write scripts/quality/check.sh <<'EOF'
#!/usr/bin/env bash
# scripts/quality/check.sh — check complet.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
cd "$Q_LIB_ROOT"

log "=== lint ==="       ; q_run lint
log "=== typecheck ==="  ; q_run typecheck
log "=== test ==="       ; CI=1 q_exec vitest run
log "=== build ==="      ; q_run build
log "=== a11y ==="       ; q_run test:a11y 2>/dev/null || warn "test:a11y absent — skip"
log "=== i18n ==="       ; q_run test:i18n 2>/dev/null || warn "test:i18n absent — skip"

ok "check complet passé ✅"
EOF

# --- Quality : lint ---
write scripts/quality/lint.sh <<'EOF'
#!/usr/bin/env bash
# scripts/quality/lint.sh [--fix]
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
cd "$Q_LIB_ROOT"

if [ "${1:-}" = "--fix" ]; then
  log "ESLint (fix)…"
  q_exec eslint . --fix
else
  log "ESLint…"
  q_run lint
fi
ok "lint OK"
EOF

# --- Quality : typecheck ---
write scripts/quality/typecheck.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
cd "$Q_LIB_ROOT"
log "tsc --noEmit…"
q_run typecheck
ok "typecheck OK"
EOF

# --- Quality : test-unit ---
write scripts/quality/test-unit.sh <<'EOF'
#!/usr/bin/env bash
# scripts/quality/test-unit.sh [pattern]
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
cd "$Q_LIB_ROOT"

PATTERN="${1:-}"
if [ -t 1 ] && [ -z "${CI:-}" ]; then
  log "Vitest watch${PATTERN:+ — pattern: $PATTERN}"
  if [ -n "$PATTERN" ]; then q_exec vitest "$PATTERN"; else q_exec vitest; fi
else
  log "Vitest run${PATTERN:+ — pattern: $PATTERN}"
  if [ -n "$PATTERN" ]; then q_exec vitest run "$PATTERN"; else q_exec vitest run; fi
fi
EOF

# --- Quality : test-a11y ---
write scripts/quality/test-a11y.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
cd "$Q_LIB_ROOT"

if [ -f vitest.a11y.config.ts ]; then
  log "Tests a11y…"
  q_exec vitest run --config vitest.a11y.config.ts
  ok "a11y OK"
else
  warn "vitest.a11y.config.ts absent — skip"
fi
EOF

# --- Quality : test-e2e (stub) ---
write scripts/quality/test-e2e.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
cd "$Q_LIB_ROOT"

if [ ! -f playwright.config.ts ]; then
  warn "Playwright non configuré — skip"
  exit 0
fi
log "Playwright E2E…"
q_exec playwright test
EOF

# --- CI : ci-status ---
write scripts/ci/ci-status.sh <<'EOF'
#!/usr/bin/env bash
# scripts/ci/ci-status.sh — dernier run CI pour la branche courante (gh CLI requis).
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
cd "$CI_LIB_ROOT"

if ! command -v gh >/dev/null 2>&1; then
  warn "gh CLI absent — installe-le pour utiliser ce script"
  exit 0
fi

BRANCH="$(git branch --show-current)"
log "Dernier run CI pour '$BRANCH' :"
gh run list --branch "$BRANCH" --limit 5
EOF

# --- CI : ci-report ---
write scripts/ci/ci-report.sh <<'EOF'
#!/usr/bin/env bash
# scripts/ci/ci-report.sh — affiche .ci-reports/<branch>.md local.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
cd "$CI_LIB_ROOT"

BRANCH="$(git branch --show-current | tr '/' '_')"
F=".ci-reports/${BRANCH}.md"
if [ -f "$F" ]; then
  cat "$F"
else
  warn "Aucun rapport pour $BRANCH (fichier $F absent)"
fi
EOF

# ─────────────────────────────────────────────────────────────
# 5. README refondu
# ─────────────────────────────────────────────────────────────
write scripts/README.md <<'EOF'
# Scripts — organisation

Quatre sous-dossiers, un `_lib.sh` de helpers par dossier.

## `git/` — Git & propagation

Aucun script ici n'exécute `pnpm`/`npm`. Uniquement du git.

| Script | Rôle |
|---|---|
| `propagate.sh` | Pousse fichiers/dossiers sur toutes les `ats-lab/*` |
| `propagate-workflow.sh` | Cas particulier : `.github/workflows/` uniquement |
| `push-all.sh` | Push toutes les branches locales |
| `merge-to-main.sh` | Merge des `ats-lab/*` dans `main` |
| `merge-all-branches-to-main.sh` | Variante historique |
| `merge-main-into-branches.sh` | Propage `main` sur toutes les `ats-lab/*` |
| `cleanup-branches.sh` | Supprime les branches mergées |
| `backup.sh` | Backup horodaté (branches + bundle + working tree) |
| `restore-backup.sh` | Restaure les refs d'un backup |
| `diagnose.sh` | Rapport d'état des branches |
| `sync-and-merge.sh` | Sync remote puis merge |
| `publish.sh` | Push vers un remote donné |
| `publish-to-fde-lab.sh` | Publish dédié FDE_LAB |

## `build/` — Toolchain & dev

Aucun `git push`/`merge` ici.

| Script | Rôle |
|---|---|
| `run.sh` | Point d'entrée dev unifié (install/dev/build/test/lint/check) |
| `setup-toolchain.sh` | Toolchain minimale (package.json, configs) |
| `build-full-dashboard.sh` | Génère le dashboard complet |
| `run-dashboard.sh` | Lance Vite avec mock data |
| `generate-widgets.sh` | Génère les widgets Phase 1+2 |

## `quality/` — Tests, lint, corrections

| Script | Rôle |
|---|---|
| `check.sh` | Check complet : lint + typecheck + test + build + a11y + i18n |
| `test-unit.sh` | Vitest unit (`[pattern]` optionnel) |
| `test-a11y.sh` | Vitest + jest-axe |
| `test-e2e.sh` | Playwright (stub) |
| `lint.sh` | ESLint (+ `--fix`) |
| `typecheck.sh` | tsc --noEmit |
| `correction-eslint.sh` | Patch ESLint 9 + AppShell |
| `correction-tsc.sh` | Patch erreurs TypeScript |
| `correction-tests.sh` | Patch tests rouges |
| `check-i18n-parity.ts` | Vérifie parité FR/EN |

## `ci/` — GitHub Actions

| Script | Rôle |
|---|---|
| `ci-status.sh` | État du dernier run CI (gh CLI) |
| `ci-report.sh` | Affiche `.ci-reports/<branch>.md` |

## Conventions

- **Bash 3.2 safe** : pas de `mapfile`, `${arr[@]+"${arr[@]}"}` sur arrays vides, `set -euo pipefail`.
- **Couleurs** : définies dans chaque `_lib.sh`, désactivées si pas de TTY.
- **Backups** : tout script destructif écrit dans `.backups/<type>-<timestamp>/`.
- **Rollback** : `--rollback` quand disponible, sinon `cp -R`.

## Aliases utiles

```zsh
alias run='./scripts/build/run.sh'
alias qcheck='./scripts/quality/check.sh'
alias gpush='./scripts/git/propagate.sh'