#!/usr/bin/env bash
# scripts/fix-workflows-yaml.sh
#
# Corrige la syntaxe YAML inline invalide dans les workflows GitHub Actions.
# Remplace : with: { version: X }
# Par :      with:\n    version: X

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

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

WORKFLOWS_DIR=".github/workflows"
[ -d "$WORKFLOWS_DIR" ] || { err "Pas de $WORKFLOWS_DIR"; exit 1; }

sep
log "Correction des workflows YAML"
sep
echo ""

FIXED=0
TOTAL=0

for f in "$WORKFLOWS_DIR"/*.yml; do
  [ -f "$f" ] || continue
  TOTAL=$((TOTAL+1))
  BASENAME=$(basename "$f")

  # Détecter la syntaxe inline
  if grep -q "with: { version:" "$f" 2>/dev/null; then
    log "▶ $BASENAME — bug détecté"
    COUNT=$(grep -c "with: { version:" "$f" 2>/dev/null || echo 0)
    info "  $COUNT occurrence(s)"

    # Backup
    cp "$f" "$f.bak"

    # Remplacement : "with: { version: X }" → "with:\n    version: X"
    # Utilisation de perl pour gérer correctement le remplacement multi-ligne
    perl -i -pe 's/^(\s*)with: \{ version: (.*?) \}\s*$/$1with:\n$1  version: $2\n/g' "$f"

    # Vérification
    if grep -q "with: { version:" "$f" 2>/dev/null; then
      warn "  remplacement incomplet"
    else
      ok "  corrigé"
      FIXED=$((FIXED+1))
      rm -f "$f.bak"
    fi
  else
    info "▶ $BASENAME — OK"
  fi
done

echo ""
sep

# Vérification syntaxe YAML basique
log "Vérification syntaxique des fichiers YAML"
echo ""

for f in "$WORKFLOWS_DIR"/*.yml; do
  [ -f "$f" ] || continue
  BASENAME=$(basename "$f")

  # Utiliser python yaml si disponible
  if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import yaml, sys; yaml.safe_load(open('$f'))" 2>/dev/null; then
      ok "  $BASENAME — YAML valide"
    else
      err "  $BASENAME — YAML invalide"
      python3 -c "import yaml; yaml.safe_load(open('$f'))" 2>&1 | head_n 5 | sed 's/^/    /'
    fi
  else
    info "  $BASENAME (python3 absent, skip validation)"
  fi
done

echo ""
sep

if [ "$FIXED" -gt 0 ]; then
  ok "$FIXED / $TOTAL workflow(s) corrigé(s)"
  info ""
  info "Prochaine étape :"
  info "  git add .github/workflows/"
  info "  git commit -m 'fix(ci): correct inline YAML syntax in workflows'"
  info "  git push origin main"
else
  ok "Aucun workflow à corriger"
fi

sep