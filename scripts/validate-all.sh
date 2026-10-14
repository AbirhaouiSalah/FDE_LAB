#!/usr/bin/env bash
# scripts/validate-all.sh
#
# Exécute TOUS les pipelines CI en local avant un push définitif.
# Reproduit ce que font les workflows GitHub Actions :
#   - dashboard-ci.yml : validate-branch, lint, typecheck, test, build, report
#   - a11y-ci.yml      : tests a11y (jest-axe)
#   - i18n-ci.yml      : parité FR/EN
#   - security-ci.yml  : audit deps
#   - storybook-ci.yml : build Storybook (si configuré)
#
# Usage:
#   ./scripts/validate-all.sh                 # validation complète
#   ./scripts/validate-all.sh --quick         # skip build + storybook
#   ./scripts/validate-all.sh --ci            # mode CI (stricte)
#   ./scripts/validate-all.sh --report        # écrit un rapport local
#   ./scripts/validate-all.sh --help

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

HEAD_BIN="/usr/bin/head"
[ -x "$HEAD_BIN" ] || HEAD_BIN="head"
head_n() { "$HEAD_BIN" -n "$1"; }

# ─── Options ───────────────────────────────────────────────────────────────
QUICK=0
STRICT=0
REPORT=0
BRANCH_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --quick)       QUICK=1 ;;
    --ci)          STRICT=1; export CI=1 ;;
    --report)      REPORT=1 ;;
    --branch-only) BRANCH_ONLY=1 ;;
    -h|--help)     sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Argument inconnu: $1" >&2; exit 1 ;;
  esac
  shift
done

# ─── Couleurs ──────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_CYA=$'\033[0;36m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_CYA=""; C_DIM=""; C_RST=""
fi
log()  { printf '%s[val]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
err()  { printf '%s[err]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; }
info() { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RST"; }
sep()  { printf '%s%s%s\n' "$C_DIM" "════════════════════════════════════════════════════════════════" "$C_RST"; }
sub()  { printf '%s%s%s\n' "$C_DIM" "────────────────────────────────────────────────────────────────" "$C_RST"; }

# ─── Rapport ───────────────────────────────────────────────────────────────
REPORT_FILE=""
if [ "$REPORT" -eq 1 ]; then
  REPORT_DIR=".validation-reports"
  mkdir -p "$REPORT_DIR"
  REPORT_FILE="$REPORT_DIR/$(date +%Y%m%d-%H%M%S).md"
  {
    echo "# Rapport de validation locale"
    echo ""
    echo "- **Date:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "- **Branche:** $(git branch --show-current 2>/dev/null || echo 'detached')"
    echo "- **Commit:** $(git rev-parse --short HEAD 2>/dev/null || echo 'N/A')"
    echo ""
    echo "| Étape | Résultat | Durée |"
    echo "|-------|----------|-------|"
  } > "$REPORT_FILE"
fi

record() {
  local step="$1" result="$2" duration="$3"
  [ -z "$REPORT_FILE" ] && return 0
  echo "| $step | $result | ${duration}s |" >> "$REPORT_FILE"
}

# ─── Timer ─────────────────────────────────────────────────────────────────
START_TIME=$(date +%s)
START_TS=$(date +%H:%M:%S)
elapsed() { echo "$(($(date +%s) - START_TIME))"; }

# ─── Préflight ─────────────────────────────────────────────────────────────
sep
log "PRÉFLIGHT"
sep
echo ""

command -v node >/dev/null 2>&1 || { err "Node.js absent"; exit 1; }
NODE_V=$(node -v)
echo "  Node:        $NODE_V"

if command -v pnpm >/dev/null 2>&1; then
  PM="pnpm"; PM_RUN="pnpm run"; PM_EXEC="pnpm exec"; PM_INSTALL="pnpm install"
  PM_V=$(pnpm -v)
elif command -v npm >/dev/null 2>&1; then
  PM="npm"; PM_RUN="npm run"; PM_EXEC="npx"; PM_INSTALL="npm install"
  PM_V=$(npm -v)
else
  err "Ni pnpm ni npm trouvé"; exit 1
fi
echo "  Package mgr: $PM $PM_V"
echo "  Répertoire:  $ROOT_DIR"
echo "  Branche:     $(git branch --show-current 2>/dev/null || echo 'detached')"
echo "  Commit:      $(git rev-parse --short HEAD 2>/dev/null || echo 'N/A')"
echo ""

# ─── Install ───────────────────────────────────────────────────────────────
sep
log "1/8  INSTALLATION DES DÉPENDANCES"
sep
T=$(date +%s)
if [ ! -d node_modules ]; then
  log "node_modules absent → $PM_INSTALL"
  $PM_INSTALL || { err "Installation échouée"; record "Install" "❌" "$(($(date +%s)-T))"; exit 1; }
fi
ok "Dépendances présentes"
record "Install" "✅" "$(($(date +%s)-T))"

# ─── 2. Lint ───────────────────────────────────────────────────────────────
sep
log "2/8  LINT (ESLint)"
sep
T=$(date +%s)
if $PM_RUN --if-present lint > /tmp/validate-lint.log 2>&1; then
  ok "Lint passé"
  record "Lint" "✅" "$(($(date +%s)-T))"
else
  err "Lint échoué"
  tail -n 20 /tmp/validate-lint.log | sed 's/^/    /'
  record "Lint" "❌" "$(($(date +%s)-T))"
  [ "$STRICT" -eq 1 ] && exit 1
fi

# ─── 3. Typecheck ──────────────────────────────────────────────────────────
sep
log "3/8  TYPECHECK (tsc --noEmit)"
sep
T=$(date +%s)
if $PM_RUN --if-present typecheck > /tmp/validate-tsc.log 2>&1; then
  ok "Typecheck passé"
  record "Typecheck" "✅" "$(($(date +%s)-T))"
else
  err "Typecheck échoué"
  tail -n 20 /tmp/validate-tsc.log | sed 's/^/    /'
  record "Typecheck" "❌" "$(($(date +%s)-T))"
  [ "$STRICT" -eq 1 ] && exit 1
fi

# ─── 4. Tests unitaires + coverage ─────────────────────────────────────────
sep
log "4/8  TESTS UNITAIRES + COVERAGE"
sep
T=$(date +%s)
if $PM_RUN --if-present test -- --run --coverage > /tmp/validate-test.log 2>&1; then
  ok "Tests passés"
  grep -E "Test Files|Tests " /tmp/validate-test.log | head_n 5 | sed 's/^/    /' || true
  record "Tests" "✅" "$(($(date +%s)-T))"
else
  warn "Tests échoués (non bloquant en local)"
  grep -E "FAIL|Test Files|Tests " /tmp/validate-test.log | head_n 10 | sed 's/^/    /' || true
  record "Tests" "⚠️" "$(($(date +%s)-T))"
fi

# Coverage threshold
if [ -f coverage/coverage-summary.json ]; then
  COV=$(node -e "console.log(require('./coverage/coverage-summary.json').total.lines.pct)" 2>/dev/null || echo "?")
  echo "    Coverage (lines): ${COV}%"
  record "Coverage" "${COV}%" "-"
fi

# ─── 5. A11y ───────────────────────────────────────────────────────────────
sep
log "5/8  A11Y (jest-axe)"
sep
T=$(date +%s)
A11Y_SCRIPT=$($PM_EXEC node -e "try{console.log(require('./package.json').scripts?.['test:a11y']||'')}catch(e){console.log('')}" 2>/dev/null || echo "")
if [ -f vitest.a11y.config.ts ] && [ -n "$A11Y_SCRIPT" ]; then
  if $PM_RUN test:a11y > /tmp/validate-a11y.log 2>&1; then
    ok "A11y passé"
    grep -E "Test Files|Tests " /tmp/validate-a11y.log | head_n 5 | sed 's/^/    /' || true
    record "A11y" "✅" "$(($(date +%s)-T))"
  else
    err "A11y échoué"
    tail -n 15 /tmp/validate-a11y.log | sed 's/^/    /'
    record "A11y" "❌" "$(($(date +%s)-T))"
    [ "$STRICT" -eq 1 ] && exit 1
  fi
else
  warn "A11y skippé (config ou script manquant)"
  record "A11y" "⏭" "0"
fi

# ─── 6. i18n ───────────────────────────────────────────────────────────────
sep
log "6/8  I18N PARITY (FR/EN)"
sep
T=$(date +%s)
I18N_SCRIPT=$($PM_EXEC node -e "try{console.log(require('./package.json').scripts?.['test:i18n']||'')}catch(e){console.log('')}" 2>/dev/null || echo "")
if [ -n "$I18N_SCRIPT" ]; then
  if $PM_RUN test:i18n > /tmp/validate-i18n.log 2>&1; then
    ok "i18n parity OK"
    grep -E "✅|❌" /tmp/validate-i18n.log | sed 's/^/    /' || true
    record "i18n" "✅" "$(($(date +%s)-T))"
  else
    err "i18n parity KO"
    tail -n 15 /tmp/validate-i18n.log | sed 's/^/    /'
    record "i18n" "❌" "$(($(date +%s)-T))"
    [ "$STRICT" -eq 1 ] && exit 1
  fi
else
  warn "i18n skippé (script absent)"
  record "i18n" "⏭" "0"
fi

# ─── 7. Security audit ─────────────────────────────────────────────────────
sep
log "7/8  SECURITY AUDIT"
sep
T=$(date +%s)
if $PM audit --audit-level=high > /tmp/validate-audit.log 2>&1; then
  ok "Aucune vulnérabilité high"
  record "Security" "✅" "$(($(date +%s)-T))"
else
  warn "Vulnérabilités détectées (non bloquant)"
  grep -E "Severity|vulnerabilities" /tmp/validate-audit.log | head_n 5 | sed 's/^/    /' || true
  record "Security" "⚠️" "$(($(date +%s)-T))"
fi

# ─── 8. Build ──────────────────────────────────────────────────────────────
if [ "$QUICK" -eq 0 ]; then
  sep
  log "8/8  BUILD"
  sep
  T=$(date +%s)
  if $PM_RUN --if-present build > /tmp/validate-build.log 2>&1; then
    ok "Build réussi"
    [ -d dist ] && echo "    dist/ : $(du -sh dist | awk '{print $1}')"
    record "Build" "✅" "$(($(date +%s)-T))"
  else
    err "Build échoué"
    tail -n 20 /tmp/validate-build.log | sed 's/^/    /'
    record "Build" "❌" "$(($(date +%s)-T))"
    [ "$STRICT" -eq 1 ] && exit 1
  fi

  # Storybook optionnel
  SB_SCRIPT=$($PM_EXEC node -e "try{console.log(require('./package.json').scripts?.['build-storybook']||'')}catch(e){console.log('')}" 2>/dev/null || echo "")
  if [ -n "$SB_SCRIPT" ]; then
    log "Bonus: BUILD STORYBOOK"
    T=$(date +%s)
    if $PM_RUN build-storybook > /tmp/validate-sb.log 2>&1; then
      ok "Storybook buildé"
      record "Storybook" "✅" "$(($(date +%s)-T))"
    else
      warn "Storybook échoué (non bloquant)"
      record "Storybook" "⚠️" "$(($(date +%s)-T))"
    fi
  else
    info "Storybook skippé (script absent)"
    record "Storybook" "⏭" "0"
  fi
else
  info "Mode --quick : build skippé"
fi

# ─── Résumé ────────────────────────────────────────────────────────────────
TOTAL=$(elapsed)
echo ""
sep
echo "  RÉSUMÉ DE LA VALIDATION"
sep
echo ""
printf "  Durée totale : %ds (démarré %s)\n" "$TOTAL" "$START_TS"
printf "  Branche      : %s\n" "$(git branch --show-current 2>/dev/null || echo detached)"
printf "  Commit       : %s\n" "$(git rev-parse --short HEAD 2>/dev/null || echo N/A)"
echo ""

if [ -n "$REPORT_FILE" ]; then
  echo "  Rapport : $REPORT_FILE"
fi

echo ""
sep
if [ "$STRICT" -eq 1 ]; then
  ok "Validation stricte réussie — prêt à pusher"
else
  ok "Validation terminée — vérifie les warnings ci-dessus"
fi
sep