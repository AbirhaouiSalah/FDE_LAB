# MY MODIF
#!/usr/bin/env bash
# scripts/run.sh — Point d'entrée unique pour le dev workflow
# Usage: ./scripts/run.sh <commande> [args]
# Voir --help pour la liste complète.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

# Couleurs (désactivées si pas de TTY)
if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_DIM=$'\033[2m';    C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_DIM=""; C_RST=""
fi

log()  { printf '%s[run]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
die()  { printf '%s[err ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; exit 1; }

detect_pm() {
  if [ -f pnpm-lock.yaml ]; then echo "pnpm"
  elif [ -f yarn.lock ];      then echo "yarn"
  elif [ -f package-lock.json ]; then echo "npm"
  elif [ -f bun.lockb ];      then echo "bun"
  else
    command -v pnpm >/dev/null 2>&1 && echo "pnpm" && return
    command -v yarn >/dev/null 2>&1 && echo "yarn" && return
    command -v bun  >/dev/null 2>&1 && echo "bun"  && return
    command -v npm  >/dev/null 2>&1 && echo "npm"  && return
    die "Aucun package manager détecté (pnpm/yarn/npm/bun)."
  fi
}

PM="$(detect_pm)"
case "$PM" in
  pnpm) PM_RUN="pnpm run";  PM_EXEC="pnpm exec"; PM_INSTALL="pnpm install" ;;
  yarn) PM_RUN="yarn";      PM_EXEC="yarn";      PM_INSTALL="yarn install" ;;
  bun)  PM_RUN="bun run";   PM_EXEC="bunx";      PM_INSTALL="bun install"  ;;
  npm)  PM_RUN="npm run";   PM_EXEC="npx";       PM_INSTALL="npm install"  ;;
  *)    die "PM inconnu: $PM" ;;
esac

require_node() {
  command -v node >/dev/null 2>&1 || die "node introuvable"
  local major
  major="$(node -p 'process.versions.node.split(".")[0]')"
  [ "$major" -ge 20 ] || die "Node >= 20 requis (actuel: $(node -v))"
}

require_deps() {
  if [ ! -d node_modules ]; then
    warn "node_modules absent — lancement de '$PM_INSTALL'"
    $PM_INSTALL
  fi
}

has_script() {
  node -e "process.exit(require('./package.json').scripts?.[process.argv[1]]?0:1)" "$1" 2>/dev/null
}

cmd_install()   { require_node; log "Installation via $PM…"; $PM_INSTALL; ok "Dépendances installées"; }
cmd_dev()       { require_node; require_deps; log "Démarrage Vite (Ctrl+C pour quitter)…"; $PM_RUN dev; }
cmd_build()     { require_node; require_deps; log "Build de production…"; $PM_RUN build; ok "Build terminé → dist/"; }

cmd_test() {
  require_node; require_deps
  local pattern="${1:-}"
  if [ -t 1 ] && [ -z "${CI:-}" ]; then
    log "Vitest (watch)${pattern:+ — pattern: $pattern}"
    if [ -n "$pattern" ]; then $PM_EXEC vitest "$pattern"; else $PM_EXEC vitest; fi
  else
    log "Vitest (run once)${pattern:+ — pattern: $pattern}"
    if [ -n "$pattern" ]; then $PM_EXEC vitest run "$pattern"; else $PM_EXEC vitest run; fi
  fi
}

cmd_lint()      { require_node; require_deps; log "ESLint…";      $PM_RUN lint; }
cmd_typecheck() { require_node; require_deps; log "tsc --noEmit…"; $PM_RUN typecheck; }
cmd_coverage()  { require_node; require_deps; log "Coverage…";    $PM_RUN coverage; }

cmd_a11y() {
  require_node; require_deps
  if ! has_script test:a11y; then
    warn "test:a11y absent — skip"
    return 0
  fi
  if [ ! -f vitest.a11y.config.ts ]; then
    warn "vitest.a11y.config.ts absent — skip (sera créé en T01)"
    return 0
  fi
  log "A11y tests…"; $PM_RUN test:a11y
}

cmd_i18n() {
  require_node; require_deps
  if ! has_script test:i18n; then
    warn "test:i18n absent — skip"
    return 0
  fi
  if [ ! -f scripts/check-i18n-parity.ts ]; then
    warn "scripts/check-i18n-parity.ts absent — skip"
    return 0
  fi
  log "i18n parity…"; $PM_RUN test:i18n
}

cmd_check() {
  log "=== check: lint ==="      ; cmd_lint
  log "=== check: typecheck ===" ; cmd_typecheck
  log "=== check: test ==="      ; CI=1 cmd_test
  log "=== check: build ==="     ; cmd_build
  log "=== check: a11y ==="      ; cmd_a11y
  log "=== check: i18n ==="      ; cmd_i18n
  ok "Tous les checks sont passés ✅"
}

cmd_clean() {
  log "Nettoyage…"
  rm -rf node_modules dist coverage .vite .turbo
  ok "Nettoyé (node_modules, dist, coverage)"
}

cmd_help() {
  cat <<EOF
${C_BLU}ATS Copilot Dashboard — run.sh${C_RST}

Usage: ./scripts/run.sh <commande> [args]

Commandes:
  install              Installe les dépendances ($PM)
  dev                  Démarre Vite sur http://localhost:5173
  build                Build de production → dist/
  test [pattern]       Vitest (watch en TTY, run sinon)
  lint                 ESLint
  typecheck            tsc --noEmit
  coverage             Vitest + coverage
  a11y                 Tests a11y (skip si script absent)
  i18n                 Parité i18n (skip si script absent)
  check                lint + typecheck + test + build + a11y + i18n
  clean                Supprime node_modules, dist, coverage

Package manager détecté: ${C_GRN}$PM${C_RST}
Node: $(node -v 2>/dev/null || echo 'absent')
EOF
}

main() {
  local cmd="${1:-help}"; shift || true
  case "$cmd" in
    install)   cmd_install "$@" ;;
    dev)       cmd_dev "$@" ;;
    build)     cmd_build "$@" ;;
    test)      cmd_test "$@" ;;
    lint)      cmd_lint "$@" ;;
    typecheck) cmd_typecheck "$@" ;;
    coverage)  cmd_coverage "$@" ;;
    a11y)      cmd_a11y "$@" ;;
    i18n)      cmd_i18n "$@" ;;
    check)     cmd_check "$@" ;;
    clean)     cmd_clean "$@" ;;
    help|-h|--help) cmd_help ;;
    *) die "Commande inconnue: '$cmd' (essaie: ./scripts/run.sh --help)" ;;
  esac
}

main "$@"
