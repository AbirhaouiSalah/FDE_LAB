#!/usr/bin/env bash
# scripts/fix-pnpm-version.sh
#
# Retire le bloc "with: version: ..." des workflows pour éviter le conflit
# avec package.json#packageManager.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

HEAD_BIN="/usr/bin/head"
[ -x "$HEAD_BIN" ] || HEAD_BIN="head"
head_n() { "$HEAD_BIN" -n "$1"; }

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_DIM=$'\033[2m';    C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_DIM=""; C_RST=""
fi
log()  { printf '%s[fix]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
err()  { printf '%s[err]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; }
info() { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RST"; }
sep()  { printf '%s%s%s\n' "$C_DIM" "════════════════════════════════════════════════════════════════" "$C_RST"; }

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

WORKFLOWS_DIR=".github/workflows"
[ -d "$WORKFLOWS_DIR" ] || { err "Pas de $WORKFLOWS_DIR"; exit 1; }

sep
log "Fix pnpm version — Mode: $([ $DRY_RUN -eq 1 ] && echo DRY-RUN || echo APPLY)"
sep
echo ""

FIXED=0
TOTAL=0

for f in "$WORKFLOWS_DIR"/*.yml; do
  [ -f "$f" ] || continue
  TOTAL=$((TOTAL+1))
  BASENAME=$(basename "$f")

  # Détecter la présence du bloc à retirer
  if grep -q "pnpm/action-setup@v4" "$f" 2>/dev/null && \
     grep -q "version: \${{ env.PNPM_VERSION }}" "$f" 2>/dev/null; then

    log "▶ $BASENAME — bloc à retirer"

    if [ "$DRY_RUN" -eq 1 ]; then
      info "  [dry-run] retirerait 'with: version: ...' après pnpm/action-setup@v4"
      FIXED=$((FIXED+1))
      continue
    fi

    cp "$f" "$f.bak"

    # Retirer le bloc "with:\n  version: {{ env.PNPM_VERSION }}" qui suit
    # la ligne "uses: pnpm/action-setup@v4"
    perl -0pi -e 's{(- uses: pnpm/action-setup\@v4\s*\n)\s*with:\s*\n\s*version: \$\{\{ env\.PNPM_VERSION \}\}\s*\n}{$1}g' "$f"

    if grep -q "version: \${{ env.PNPM_VERSION }}" "$f" 2>/dev/null; then
      warn "  remplacement incomplet — restauration"
      mv "$f.bak" "$f"
    else
      ok "  corrigé"
      FIXED=$((FIXED+1))
      rm -f "$f.bak"
    fi
  else
    info "▶ $BASENAME — rien à faire"
  fi
done

echo ""
sep

if [ "$DRY_RUN" -eq 1 ]; then
  warn "$FIXED / $TOTAL workflow(s) à corriger"
  info ""
  info "Pour appliquer : ./scripts/fix-pnpm-version.sh"
  exit 0
fi

if [ "$FIXED" -gt 0 ]; then
  ok "$FIXED / $TOTAL workflow(s) corrigé(s)"
  info ""
  info "Vérification :"
  info "  grep -B1 -A2 'pnpm/action-setup' .github/workflows/dashboard-ci.yml"
  info ""
  info "Commit :"
  info "  git add .github/workflows/"
  info "  git commit -m 'fix(ci): remove duplicate pnpm version declaration'"
  info "  git push origin main"
else
  ok "Aucun workflow à corriger"
fi
sep