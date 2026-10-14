#!/usr/bin/env bash
# scripts/lots/apply-lots-fixes-v7.sh
# Correctifs ciblés L4/L5/L6/L7 — version safe (n'écrase JAMAIS _lib.sh).
#
# Ce script NE TOUCHE PAS _lib.sh. Il ne corrige QUE les build-lot-N.sh.
#
# Usage:
#   bash scripts/lots/apply-lots-fixes-v7.sh           # dry-run
#   bash scripts/lots/apply-lots-fixes-v7.sh --yes     # applique

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
BACKUP_DIR=".lots-fix-v7-backup-${TS}"
APPLIED=0; SKIPPED=0; FAILED=0

# sed GNU-safe : macOS = /usr/bin/sed, Linux = /usr/bin/sed aussi (mais BSD vs GNU)
# On utilise /usr/bin/sed pour être portable macOS.
SED="/usr/bin/sed"
[ -x "$SED" ] || SED="sed"

backup() {
  local f="$1"; [[ -f "$f" ]] || return 0
  mkdir -p "$BACKUP_DIR"
  cp "$f" "${BACKUP_DIR}/$(echo "$f" | tr '/' '_')"
}

# Sanity : un fichier doit avoir du contenu (>100 octets) avant d'être modifié
assert_nonempty() {
  local f="$1"
  [[ -f "$f" ]] || { bad "$f introuvable"; return 1; }
  local size
  size="$(wc -c < "$f" | tr -d ' ')"
  if [[ "$size" -lt 100 ]]; then
    bad "$f : trop petit ($size octets) — refus de modifier"
    return 1
  fi
  return 0
}

# ─── 0. Contexte ───────────────────────────────────────────────────────────
hdr "0. Contexte"
info "repo : $REPO_ROOT"
info "mode : $([[ "$APPLY" == "1" ]] && echo APPLY || echo "DRY-RUN (--yes pour appliquer)")"
info "sed  : $SED"

# Sanity globale : _lib.sh doit être non vide
if ! assert_nonempty "scripts/lots/_lib.sh"; then
  bad "❌ _lib.sh est vide ou trop petit — restaure-le avant de lancer ce script."
  exit 2
fi

# ═══════════════════════════════════════════════════════════════════════════
# 1. L4, L5, L7 — supprimer TOUTE ligne contenant ${0:A:h}
# ═══════════════════════════════════════════════════════════════════════════
hdr "1. L4/L5/L7 : suppression des lignes \${0:A:h}"

for n in 4 5 7; do
  f="scripts/lots/build-lot-${n}.sh"
  if ! assert_nonempty "$f"; then
    FAILED=$((FAILED+1))
    continue
  fi

  # Combien d'occurrences ?
  count="$("$SED" -n '/\${0:A:h}/p' "$f" | wc -l | tr -d ' ')"
  if [[ "$count" -eq 0 ]]; then
    dim "L$n : déjà propre (aucun \${0:A:h})"
    SKIPPED=$((SKIPPED+1))
    continue
  fi

  info "L$n : $count ligne(s) avec \${0:A:h} → suppression"

  if [[ "$APPLY" == "0" ]]; then
    dry "supprimerait $count ligne(s) dans $f"
    APPLIED=$((APPLIED+1))
    continue
  fi

  backup "$f"
  tmp="$(mktemp -t l${n}-v7)"
  "$SED" '/\${0:A:h}/d' "$f" > "$tmp"

  # Vérifie que le résultat n'est pas vide
  if [[ ! -s "$tmp" ]]; then
    bad "L$n : résultat vide — restauration"
    rm -f "$tmp"
    FAILED=$((FAILED+1))
    continue
  fi

  # Vérifie que la taille n'a pas chuté de plus de 50%
  orig_size="$(wc -c < "$f" | tr -d ' ')"
  new_size="$(wc -c < "$tmp" | tr -d ' ')"
  if [[ "$new_size" -lt $((orig_size / 2)) ]]; then
    bad "L$n : taille -50% ($orig_size → $new_size) — annulation par sécurité"
    rm -f "$tmp"
    FAILED=$((FAILED+1))
    continue
  fi

  mv "$tmp" "$f"
  chmod +x "$f"
  ok "L$n : $count ligne(s) supprimée(s)"
  APPLIED=$((APPLIED+1))
done

# ═══════════════════════════════════════════════════════════════════════════
# 2. L6 — remplacer $LOT_ROOT par $REPO_ROOT
# ═══════════════════════════════════════════════════════════════════════════
hdr "2. L6 : \$LOT_ROOT → \$REPO_ROOT"

L6="scripts/lots/build-lot-6.sh"
if ! assert_nonempty "$L6"; then
  FAILED=$((FAILED+1))
else
  count="$(grep -c 'LOT_ROOT' "$L6" 2>/dev/null || echo 0)"
  if [[ "$count" -eq 0 ]]; then
    dim "L6 : déjà propre"
    SKIPPED=$((SKIPPED+1))
  else
    info "L6 : $count occurrence(s) de LOT_ROOT → remplacement"

    if [[ "$APPLY" == "0" ]]; then
      dry "remplacerait $count occurrence(s) dans $L6"
      APPLIED=$((APPLIED+1))
    else
      backup "$L6"
      tmp="$(mktemp -t l6-v7)"
      "$SED" \
        -e 's|\$LOT_ROOT\b|$REPO_ROOT|g' \
        -e 's|\${LOT_ROOT:-\?[^}]*\}|${REPO_ROOT}|g' \
        -e 's|\bLOT_ROOT\b|REPO_ROOT|g' \
        "$L6" > "$tmp"

      if [[ ! -s "$tmp" ]]; then
        bad "L6 : résultat vide — annulation"
        rm -f "$tmp"
        FAILED=$((FAILED+1))
      else
        mv "$tmp" "$L6"
        chmod +x "$L6"
        ok "L6 : LOT_ROOT remplacé par REPO_ROOT"
        APPLIED=$((APPLIED+1))
      fi
    fi
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# 3. Vérifications
# ═══════════════════════════════════════════════════════════════════════════
hdr "3. Vérifications"

info "\${0:A:h} restants :"
found=0
for n in 4 5 7; do
  f="scripts/lots/build-lot-${n}.sh"
  [[ -f "$f" ]] || continue
  if grep -q '\${0:A:h}' "$f" 2>/dev/null; then
    bad "  L$n : encore présent"
    grep -n '\${0:A:h}' "$f" | /bin/sed 's/^/    /'
    found=1
  fi
done
[[ "$found" -eq 0 ]] && ok "aucun \${0:A:h} restant"

info "LOT_ROOT restants dans L6 :"
if [[ -f "$L6" ]] && grep -q 'LOT_ROOT' "$L6" 2>/dev/null; then
  bad "  encore présent"
  grep -n 'LOT_ROOT' "$L6" | /bin/sed 's/^/    /'
else
  ok "aucun LOT_ROOT"
fi

info "_lib.sh intact ?"
if [[ -f "scripts/lots/_lib.sh" ]]; then
  size="$(wc -c < scripts/lots/_lib.sh | tr -d ' ')"
  lines="$(wc -l < scripts/lots/_lib.sh | tr -d ' ')"
  if [[ "$size" -gt 1000 ]]; then
    ok "_lib.sh : $lines lignes, $size octets"
  else
    bad "_lib.sh : seulement $lines lignes — VIDE ou corrompu !"
    FAILED=$((FAILED+1))
  fi
fi

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
if /bin/bash -c 'source scripts/lots/_lib.sh 2>/dev/null && type -t write_file >/dev/null' >/dev/null 2>&1; then
  ok "source OK, write_file défini"
else
  bad "source échoue ou write_file manquant"
  /bin/bash -c 'source scripts/lots/_lib.sh 2>&1' | /usr/bin/head -2 | /bin/sed 's/^/    /'
  FAILED=$((FAILED+1))
fi

# ═══════════════════════════════════════════════════════════════════════════
# 4. Dry-run des 4 lots
# ═══════════════════════════════════════════════════════════════════════════
if [[ "$APPLY" == "1" ]]; then
  hdr "4. Dry-run L4/L5/L6/L7"
  for n in 4 5 6 7; do
    f="scripts/lots/build-lot-${n}.sh"
    [[ -f "$f" ]] || continue
    echo ""
    echo "── L$n ──"
    if /bin/bash "$f" --dry-run > /tmp/l${n}-dry-v7.log 2>&1; then
      ok "L$n : dry-run OK"
      /usr/bin/head -6 /tmp/l${n}-dry-v7.log | /bin/sed 's/^/    /'
    else
      bad "L$n : dry-run échoue (rc=$?)"
      /usr/bin/tail -12 /tmp/l${n}-dry-v7.log | /bin/sed 's/^/    /'
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

exit 0