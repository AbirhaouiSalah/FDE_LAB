#!/usr/bin/env bash
# scripts/lots/apply-lots-fixes-v6.sh
# Correctifs finaux :
#   1. L4/L5/L7 : supprime la ligne 19 cassée contenant ${0:A:h}${0:A:h}
#   2. L6       : remplace $LOT_ROOT par $REPO_ROOT (partout)
#   3. _lib.sh  : corrige C_BLUE?: → C_BLUE:= (et tout autre C_*?:)
#   4. Vérifie  : syntaxe bash + source _lib.sh + dry-run des 4 lots
#
# Usage:
#   bash scripts/lots/apply-lots-fixes-v6.sh           # dry-run
#   bash scripts/lots/apply-lots-fixes-v6.sh --yes     # applique

set -uo pipefail

APPLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y) APPLY=1; shift ;;
    -h|--help) echo "Usage: $0 [--yes]"; exit 0 ;;
    *) echo "option inconnue: $1" >&2; exit 2 ;;
  esac
done

# ─── Couleurs ──────────────────────────────────────────────────────────────
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[34m'; D=$'\033[2m'; Z=$'\033[0m'
else R=""; G=""; Y=""; B=""; D=""; Z=""; fi
ok()   { printf '%s✅%s %s\n' "$G" "$Z" "$*"; }
bad()  { printf '%s❌%s %s\n' "$R" "$Z" "$*"; }
warn() { printf '%s⚠️  %s\n' "$Y" "$Z" "$*"; }
info() { printf '%sℹ️  %s\n' "$B" "$Z" "$*"; }
dim()  { printf '%s   %s%s\n' "$D" "$*" "$Z"; }
hdr()  { printf '\n%s══ %s ══%s\n' "$B" "$*" "$Z"; }
dry()  { printf '%s[dry]%s %s\n' "$D" "$Z" "$*"; }

# ─── Localisation ──────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "$REPO_ROOT" || { echo "❌ cd failed"; exit 2; }

TS="$(date -u +%Y%m%d-%H%M%SZ)"
BACKUP_DIR=".lots-fix-v6-backup-${TS}"
APPLIED=0; SKIPPED=0; FAILED=0

backup() {
  local f="$1"; [[ -f "$f" ]] || return 0
  mkdir -p "$BACKUP_DIR"
  cp "$f" "${BACKUP_DIR}/$(echo "$f" | tr '/' '_')"
}

# Remplace le contenu d'un fichier de façon atomique.
# Préserve le mode. Ne fait rien si contenu identique.
write_atomic() {
  local target="$1" src="$2"
  if [[ -f "$target" ]] && cmp -s "$src" "$target"; then rm -f "$src"; return 1; fi
  if [[ "$APPLY" == "1" ]]; then
    backup "$target"
    mkdir -p "$(dirname "$target")"
    local mode=""
    [[ -f "$target" ]] && mode="$(stat -f '%Lp' "$target" 2>/dev/null || true)"
    mv "$src" "$target"
    [[ -n "$mode" ]] && chmod "$mode" "$target" 2>/dev/null || true
  else
    rm -f "$src"; dry "écrirait $target"
  fi
  return 0
}

# ─── 0. Contexte ───────────────────────────────────────────────────────────
hdr "0. Contexte"
info "repo : $REPO_ROOT"
info "mode : $([[ "$APPLY" == "1" ]] && echo APPLY || echo "DRY-RUN (--yes pour appliquer)")"

# ═══════════════════════════════════════════════════════════════════════════
# 1. L4, L5, L7 — supprimer la ligne 19 cassée (${0:A:h}${0:A:h})
# ═══════════════════════════════════════════════════════════════════════════
hdr "1. L4/L5/L7 : suppression de la ligne 19 cassée"

for n in 4 5 7; do
  f="scripts/lots/build-lot-${n}.sh"
  if [[ ! -f "$f" ]]; then
    bad "L$n : $f introuvable"
    FAILED=$((FAILED+1))
    continue
  fi

  # Vérifie que la ligne 19 contient bien le motif cassé
  line19="$(/bin/sed -n '19p' "$f" 2>/dev/null || echo '')"
  if [[ "$line19" == *'${0:A:h}'* ]]; then
    info "L$n : ligne 19 contient \${0:A:h} → suppression"

    tmp="$(mktemp -t l${n}-fix)"
    /bin/sed '19d' "$f" > "$tmp"

    if write_atomic "$f" "$tmp"; then
      ok "L$n : ligne 19 supprimée"
      APPLIED=$((APPLIED+1))
    else
      dim "L$n : aucun changement"
      SKIPPED=$((SKIPPED+1))
    fi
  else
    # Fallback : cherche toute ligne avec ${0:A:h} ou A:h}
    if grep -q '\${0:A:h}\|\${0:h}' "$f" 2>/dev/null; then
      info "L$n : motif \${0:A:h} trouvé ailleurs → suppression de toutes les occurrences"
      tmp="$(mktemp -t l${n}-fix)"
      /bin/sed -E '/\$\{0:A:h\}|\$\{0:h\}/d' "$f" > "$tmp"
      if write_atomic "$f" "$tmp"; then
        ok "L$n : lignes supprimées"
        APPLIED=$((APPLIED+1))
      else
        dim "L$n : inchangé"
        SKIPPED=$((SKIPPED+1))
      fi
    else
      dim "L$n : déjà propre (ligne 19 = $line19)"
      SKIPPED=$((SKIPPED+1))
    fi
  fi
done

# ═══════════════════════════════════════════════════════════════════════════
# 2. L6 — remplacer $LOT_ROOT par $REPO_ROOT
# ═══════════════════════════════════════════════════════════════════════════
hdr "2. L6 : \$LOT_ROOT → \$REPO_ROOT"

L6="scripts/lots/build-lot-6.sh"
if [[ ! -f "$L6" ]]; then
  bad "L6 : $L6 introuvable"
  FAILED=$((FAILED+1))
else
  if grep -q 'LOT_ROOT' "$L6" 2>/dev/null; then
    count="$(grep -c 'LOT_ROOT' "$L6" 2>/dev/null || echo 0)"
    info "L6 : $count occurrence(s) de LOT_ROOT → remplacement"

    tmp="$(mktemp -t l6-fix)"
    # Ordre : d'abord ${LOT_ROOT:-default}, puis $LOT_ROOT simple, puis LOT_ROOT nu
    /bin/sed -E \
      -e 's|\$\{LOT_ROOT:-\?[^}]*\}|${REPO_ROOT}|g' \
      -e 's|\$LOT_ROOT\b|$REPO_ROOT|g' \
      -e 's|\bLOT_ROOT\b|REPO_ROOT|g' \
      "$L6" > "$tmp"

    if write_atomic "$L6" "$tmp"; then
      ok "L6 : LOT_ROOT remplacé par REPO_ROOT"
      APPLIED=$((APPLIED+1))
    else
      dim "L6 : aucun changement"
      SKIPPED=$((SKIPPED+1))
    fi
  else
    dim "L6 : déjà propre"
    SKIPPED=$((SKIPPED+1))
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# 3. _lib.sh — corriger C_*?: → C_*:=
# ═══════════════════════════════════════════════════════════════════════════
hdr "3. _lib.sh : C_*?: → C_*:="

LIB="scripts/lots/_lib.sh"
if [[ ! -f "$LIB" ]]; then
  bad "_lib.sh introuvable"
  FAILED=$((FAILED+1))
else
  if grep -qE 'C_[A-Z_]+\?:' "$LIB" 2>/dev/null; then
    info "_lib.sh : lignes avec C_*?: trouvées → correction"

    tmp="$(mktemp -t libfix)"
    /bin/sed -E 's/(C_[A-Z_]+)\?:/\1:=/g' "$LIB" > "$tmp"

    if write_atomic "$LIB" "$tmp"; then
      ok "_lib.sh : C_*?: corrigés"
      APPLIED=$((APPLIED+1))
    else
      dim "_lib.sh : aucun changement"
      SKIPPED=$((SKIPPED+1))
    fi
  else
    dim "_lib.sh : déjà propre"
    SKIPPED=$((SKIPPED+1))
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# 4. Vérifications
# ═══════════════════════════════════════════════════════════════════════════
hdr "4. Vérifications"

info "Ligne 19 de L4/L5/L7 (doit être sans \${0:A:h}) :"
for n in 4 5 7; do
  f="scripts/lots/build-lot-${n}.sh"
  [[ -f "$f" ]] || continue
  line19="$(/bin/sed -n '19p' "$f" 2>/dev/null | /usr/bin/head -c 80)"
  printf '  L%d : %s\n' "$n" "$line19"
done

info "LOT_ROOT dans L6 (doit être vide) :"
if grep -q 'LOT_ROOT' "$L6" 2>/dev/null; then
  bad "LOT_ROOT encore présent :"
  grep -n 'LOT_ROOT' "$L6" | /bin/sed 's/^/    /'
else
  ok "aucun LOT_ROOT"
fi

info "_lib.sh : ligne 106 actuelle :"
/bin/sed -n '106p' "$LIB" 2>/dev/null | /usr/bin/head -c 100
echo ""

info "Syntaxe bash des 7 lots :"
for n in 1 2 3 4 5 6 7; do
  f="scripts/lots/build-lot-${n}.sh"
  [[ -f "$f" ]] || continue
  if /bin/bash -n "$f" 2>/dev/null; then
    printf '  %s✅%s L%d\n' "$G" "$Z" "$n"
  else
    printf '  %s❌%s L%d : ' "$R" "$Z" "$n"
    /bin/bash -n "$f" 2>&1 | /usr/bin/head -1 | /bin/sed 's/^/     /'
  fi
done

info "_lib.sh peut être sourcé ?"
if /bin/bash -c 'source scripts/lots/_lib.sh 2>/dev/null' >/dev/null 2>&1; then
  ok "source OK"
else
  bad "source échoue :"
  /bin/bash -c 'source scripts/lots/_lib.sh' 2>&1 | /usr/bin/head -2 | /bin/sed 's/^/    /'
fi

# ═══════════════════════════════════════════════════════════════════════════
# 5. Dry-run ciblé sur L4, L5, L6, L7
# ═══════════════════════════════════════════════════════════════════════════
if [[ "$APPLY" == "1" ]]; then
  hdr "5. Dry-run L4/L5/L6/L7"
  for n in 4 5 6 7; do
    f="scripts/lots/build-lot-${n}.sh"
    [[ -f "$f" ]] || continue
    echo ""
    echo "── L$n ──"
    if /bin/bash "$f" --dry-run >/tmp/l${n}-dry.log 2>&1; then
      ok "L$n : dry-run OK"
      /usr/bin/head -8 /tmp/l${n}-dry.log | /bin/sed 's/^/    /'
    else
      bad "L$n : dry-run échoue (rc=$?)"
      /usr/bin/tail -10 /tmp/l${n}-dry.log | /bin/sed 's/^/    /'
      FAILED=$((FAILED+1))
    fi
  done
fi

# ═══════════════════════════════════════════════════════════════════════════
# Rapport
# ═══════════════════════════════════════════════════════════════════════════
hdr "Rapport"
printf '  %-14s %s\n' "appliqués" "$APPLIED"
printf '  %-14s %s\n' "inchangés" "$SKIPPED"
printf '  %-14s %s\n' "échecs"    "$FAILED"
[[ -d "$BACKUP_DIR" ]] && printf '  %-14s %s\n' "backups" "$BACKUP_DIR"

if [[ "$APPLY" == "0" ]]; then
  echo ""
  warn "Mode DRY-RUN — relancer avec --yes pour appliquer"
fi

echo ""
info "Étape suivante :"
dim "  bash scripts/lots/build-all.sh --yes"
dim "  bash scripts/lots/build-all.sh --dry-run"

exit 0