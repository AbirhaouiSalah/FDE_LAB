#!/usr/bin/env bash
# scripts/lots/apply-lots-fixes-v3.sh
# Corrige le bug `ensure_clean_tree` + ajoute les alias de compatibilité.
# Scanne aussi les 7 lots pour détecter d'autres fonctions manquantes.
#
# Usage:
#   bash scripts/lots/apply-lots-fixes-v3.sh           # dry-run
#   bash scripts/lots/apply-lots-fixes-v3.sh --yes     # applique

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
BACKUP_DIR=".lots-fix-v3-backup-${TS}"
APPLIED=0; SKIPPED=0; FAILED=0

backup() {
  local f="$1"; [[ -f "$f" ]] || return 0
  mkdir -p "$BACKUP_DIR"
  cp "$f" "${BACKUP_DIR}/$(echo "$f" | tr '/' '_')"
}

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
# 1. _lib.sh : ajouter les alias de compatibilité (sans doublon)
# ═══════════════════════════════════════════════════════════════════════════
hdr "1. _lib.sh : alias de compatibilité"
LIB="scripts/lots/_lib.sh"
if [[ ! -f "$LIB" ]]; then
  bad "_lib.sh introuvable"; FAILED=$((FAILED+1))
else
  tmp="$(mktemp -t libv3)"

  /usr/bin/awk '
    BEGIN { injected=0 }

    # Marqueur unique pour éviter les doublons
    /^# === ALIAS-COMPAT-V3 ===/ { injected=1 }

    # Insère le bloc juste avant "# ─── Exécution sécurisée"
    /^# ─── Exécution sécurisée/ && !injected {
      print "# === ALIAS-COMPAT-V3 ==="
      print "# Alias de compatibilité : anciennes API utilisées par certains lots."
      print "# NE PAS SUPPRIMER — même si certains semblent inutilisés aujourd'"'"'hui."
      print ""
      print "ensure_clean_tree() { require_clean_tree \"$@\"; }"
      print "ensure_clean()      { require_clean_tree \"$@\"; }"
      print "check_prereqs()     { require_repo_root; require_cmd git; return 0; }"
      print "log_info()          { info \"$@\"; }"
      print "log_error()         { err \"$@\"; }"
      print "log_success()       { ok \"$@\"; }"
      print "log_debug()         { log_dim \"$@\"; }"
      print "log_fatal()         { die \"$@\"; }"
      print "assert_clean()      { require_clean_tree \"$@\"; }"
      print "abort()             { die \"$@\"; }"
      print "fatal()             { die \"$@\"; }"
      print ""
      injected=1
    }
    { print }
  ' "$LIB" > "$tmp"

  if write_atomic "$LIB" "$tmp"; then
    ok "_lib.sh : alias compat ajoutés"
    APPLIED=$((APPLIED+1))
  else
    dim "_lib.sh : alias déjà présents"
    SKIPPED=$((SKIPPED+1))
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# 2. build-lot-1.sh : corriger ensure_clean_tree → require_clean_tree
# ═══════════════════════════════════════════════════════════════════════════
hdr "2. build-lot-1.sh : appels directs"
L1="scripts/lots/build-lot-1.sh"
if [[ -f "$L1" ]]; then
  tmp="$(mktemp -t l1v3)"
  # Remplace uniquement quand c'est utilisé comme commande (début de ligne ou après ; ou &&)
  /bin/sed -E 's/^([[:space:]]*)ensure_clean_tree([[:space:]]|$)/\1require_clean_tree\2/; s/([;&|][[:space:]]*)ensure_clean_tree([[:space:]]|$)/\1require_clean_tree\2/' "$L1" > "$tmp"

  if write_atomic "$L1" "$tmp"; then
    ok "build-lot-1.sh : ensure_clean_tree → require_clean_tree"
    APPLIED=$((APPLIED+1))
  else
    dim "build-lot-1.sh : rien à changer"
    SKIPPED=$((SKIPPED+1))
  fi
else
  bad "build-lot-1.sh introuvable"; FAILED=$((FAILED+1))
fi

# ═══════════════════════════════════════════════════════════════════════════
# 3. Scanner : détecter les fonctions manquantes dans les 7 lots
# ═══════════════════════════════════════════════════════════════════════════
hdr "3. Scanner des fonctions appelées mais non définies"

if [[ ! -f "$LIB" ]]; then
  warn "_lib.sh absent, scan impossible"
else
  # Fonctions définies dans _lib.sh
  lib_funcs="$(grep -oE '^[a-z_][a-z0-9_]*\(\)' "$LIB" | tr -d '()' | sort -u)"

  # Builtins bash + commandes système courantes (whitelist élargie)
  whitelist="echo printf read cd source set shift exit return test true false grep sed awk cat wc tr head tail sort uniq xargs find chmod mkdir cp mv rm rmdir ln touch dirname basename env export unset local declare readarray mapfile command type hash pwd pushd popd dirs alias unalias history jobs fg bg wait kill trap eval exec time sleep date mktemp realpath git bash sh zsh python python3 node pnpm npm yarn npx tsx tsc vitest jest eslint prettier curl wget jq yq tee cut paste join split install break continue"

  # Bruit : mots du vocabulaire projet / noms de dossiers
  project_words="src lib server tests docs app widgets pages mock styles auth i18n api assets components hooks utils types constants config dist build coverage node_modules scripts lots reports backup cache tmp temp logs"

  total_missing=0
  report_lines=""

  for n in 1 2 3 4 5 6 7; do
    f="scripts/lots/build-lot-${n}.sh"
    [[ -f "$f" ]] || continue

    # Fonctions définies DANS ce fichier
    own_funcs="$(grep -oE '^[a-z_][a-z0-9_]*\(\)' "$f" | tr -d '()' | sort -u)"

    # Identifiants en position de commande :
    # - début de ligne : mot (
    # - après && ou || ou ; : mot
    # - après $( : mot
    candidates="$(
      {
        grep -oE '^[[:space:]]*[a-z_][a-z0-9_]{2,}' "$f"
        grep -oE '[&|;][[:space:]]*[a-z_][a-z0-9_]{2,}' "$f" | /bin/sed -E 's/^[&|;][[:space:]]*//'
      } | /bin/sed -E 's/^[[:space:]]+//' | sort -u
    )"

    missing=""
    for fn in $candidates; do
      # Whitelist ?
      if echo " $whitelist " | grep -q " $fn "; then continue; fi
      # Mots du projet ?
      if echo " $project_words " | grep -q " $fn "; then continue; fi
      # Défini dans _lib.sh ?
      if echo "$lib_funcs" | grep -qx "$fn"; then continue; fi
      # Défini dans le fichier lui-même ?
      if echo "$own_funcs" | grep -qx "$fn"; then continue; fi
      # Contient un slash ou un tiret (chemin, pas fonction) ?
      case "$fn" in */*|*-*) continue ;; esac
      # Trop court ?
      [[ "${#fn}" -lt 3 ]] && continue

      missing="$missing $fn"
    done

    if [[ -n "$missing" ]]; then
      total_missing=$((total_missing+1))
      printf '%sL%d%s :' "$Y" "$n" "$Z"
      for m in $missing; do printf ' %s' "$m"; done
      printf '\n'
      report_lines="${report_lines}L${n} :${missing}\n"
    fi
  done

  if [[ "$total_missing" -eq 0 ]]; then
    ok "aucune fonction manquante détectée"
  else
    warn "$total_missing lot(s) référencent des fonctions non définies"
    info "Pour chaque fonction listée : soit elle est dans _lib.sh (ajout à faire),"
    info "soit c'est un faux positif du scanner (nom de variable, mot-clé oublié)."
  fi

  # Sauvegarde du rapport
  if [[ "$APPLY" == "1" ]] && [[ -n "$report_lines" ]]; then
    report_file="scripts/lots/FONCTIONS-MANQUANTES.txt"
    {
      echo "# Fonctions potentiellement manquantes — $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
      echo "# Ces fonctions sont référencées dans les build-lot-N.sh"
      echo "# mais non définies dans _lib.sh ni dans le fichier lui-même."
      echo "# À vérifier manuellement."
      echo ""
      printf '%b' "$report_lines"
    } > "$report_file"
    info "rapport écrit : $report_file"
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# 4. Vérifications
# ═══════════════════════════════════════════════════════════════════════════
hdr "4. Vérifications"

info "Alias dans _lib.sh :"
for fn in ensure_clean_tree check_prereqs log_info log_error abort; do
  if grep -qE "^${fn}\(\)" "$LIB" 2>/dev/null; then
    printf '  %s✅%s %s\n' "$G" "$Z" "$fn"
  else
    printf '  %s❌%s %s (manquant)\n' "$R" "$Z" "$fn"
  fi
done

info "Appels à ensure_clean_tree dans build-lot-1.sh :"
if grep -q 'ensure_clean_tree' "$L1" 2>/dev/null; then
  grep -n 'ensure_clean_tree' "$L1" | /bin/sed 's/^/  /'
else
  ok "aucun (remplacé par require_clean_tree)"
fi

info "_lib.sh peut être sourcé ?"
if bash -c 'source scripts/lots/_lib.sh 2>/dev/null && echo "OK"' >/dev/null 2>&1; then
  ok "source OK"
else
  bad "source échoue"
fi

info "Syntaxe bash des 7 lots :"
for n in 1 2 3 4 5 6 7; do
  f="scripts/lots/build-lot-${n}.sh"
  [[ -f "$f" ]] || continue
  if /bin/bash -n "$f" 2>/dev/null; then
    printf '  %s✅%s L%d\n' "$G" "$Z" "$n"
  else
    printf '  %s❌%s L%d : ' "$R" "$Z" "$n"
    /bin/bash -n "$f" 2>&1 | /usr/bin/head -1
  fi
done

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
dim "  bash scripts/lots/build-lot-1.sh --dry-run"
dim "  bash scripts/lots/build-all.sh --dry-run"

exit 0