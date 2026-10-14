#!/usr/bin/env bash
# scripts/lots/doctor.sh — Diagnostic de l'infra scripts/lots.
# Vérifie : bash, shebangs, exécutabilité, sourcing, symétrie L1..L7.

set -uo pipefail

# ─── Helpers ───────────────────────────────────────────────────────────────
first_line() { /usr/bin/awk 'NR==1{print; exit}' "$1" 2>/dev/null || true; }
safe_int()   { [[ "${1:-}" =~ ^[0-9]+$ ]] && echo "$1" || echo 0; }

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[34m'; D=$'\033[2m'; Z=$'\033[0m'
else R=""; G=""; Y=""; B=""; D=""; Z=""; fi
ok()   { printf '%s✅%s %s\n' "$G" "$Z" "$*"; }
bad()  { printf '%s❌%s %s\n' "$R" "$Z" "$*"; }
warn() { printf '%s⚠️  %s\n' "$Y" "$Z" "$*"; }
info() { printf '%sℹ️  %s\n' "$B" "$Z" "$*"; }
dim()  { printf '%s   %s%s\n' "$D" "$*" "$Z"; }
hdr()  { printf '\n%s── %s ──%s\n' "$B" "$*" "$Z"; }

ISSUES=0
FIXES=()
add_issue() { ISSUES=$((ISSUES+1)); }
add_fix()   { FIXES+=("$1"); }

# ─── Localisation ──────────────────────────────────────────────────────────
DOCTOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${DOCTOR_DIR}/../.." && pwd)"
cd "$REPO_ROOT"

# ─── 0. Contexte ───────────────────────────────────────────────────────────
hdr "0. Contexte"
info "repo : $REPO_ROOT"

# ─── 1. Version bash ───────────────────────────────────────────────────────
hdr "1. Version bash"
BASH_BIN=""
for cand in /usr/local/bin/bash /opt/homebrew/bin/bash; do
  if [[ -x "$cand" ]] && "$cand" -c '[[ "${BASH_VERSINFO[0]}" -ge 4 ]]' 2>/dev/null; then
    BASH_BIN="$cand"; break
  fi
done
[[ -z "$BASH_BIN" ]] && BASH_BIN="$(command -v bash || true)"

if [[ -z "$BASH_BIN" ]]; then
  bad "bash introuvable dans le PATH"
  add_issue
else
  BV="$("$BASH_BIN" --version 2>/dev/null | /usr/bin/awk 'NR==1{print; exit}' || true)"
  BV_MAJOR="$("$BASH_BIN" -c 'echo "${BASH_VERSINFO[0]}"' 2>/dev/null || echo 0)"
  info "bash  : $BASH_BIN"
  info "ver.  : ${BV:-<inconnue>}"

  if [[ "$(safe_int "$BV_MAJOR")" -ge 4 ]]; then
    ok "bash $BV_MAJOR ≥ 4"
  else
    warn "bash $BV_MAJOR < 4 — OK si aucun 'declare -A' dans scripts/lots/"
    declare_a=0
    for f in scripts/lots/*.sh; do
      [[ -f "$f" ]] || continue
      if grep -q 'declare -A' "$f" 2>/dev/null; then
        bad "$(basename "$f") utilise 'declare -A' (bash ≥ 4 requis)"
        add_issue
        declare_a=$((declare_a+1))
      fi
    done
    [[ "$declare_a" -eq 0 ]] && ok "aucun declare -A → bash 3.2 pleinement supporté"
  fi
fi

# ─── 2. Fichiers attendus ──────────────────────────────────────────────────
hdr "2. Fichiers attendus"
EXPECTED=(
  _lib.sh build-all.sh doctor.sh push-lot.sh README.md
  build-lot-1.sh build-lot-2.sh build-lot-3.sh build-lot-4.sh
  build-lot-5.sh build-lot-6.sh build-lot-7.sh
)
for f in "${EXPECTED[@]}"; do
  if [[ -f "scripts/lots/$f" ]]; then
    ok "présent   : scripts/lots/$f"
  else
    bad "manquant  : scripts/lots/$f"
    add_issue
  fi
done

# ─── 3. Shebangs ───────────────────────────────────────────────────────────
hdr "3. Shebangs (#!/usr/bin/env bash attendu)"
for f in scripts/lots/*.sh; do
  [[ -f "$f" ]] || continue
  first="$(first_line "$f")"
  # BOM ?
  first3="$(/usr/bin/head -c 3 "$f" 2>/dev/null | /usr/bin/od -An -tx1 | tr -d ' ')"
  if [[ "$first3" == "efbbbf" ]]; then
    bad "$(basename "$f") : BOM UTF-8"
    add_issue
    add_fix "sed -i '' '1s/^\\xEF\\xBB\\xBF//' $f"
    continue
  fi
  case "$first" in
    '#!/usr/bin/env bash') ok "$(basename "$f")" ;;
    '#!/bin/bash')         warn "$(basename "$f") : '#!/bin/bash' au lieu de '#!/usr/bin/env bash'" ;;
    '#!'*)                 bad "$(basename "$f") : '$first'" ; add_issue ;;
    '')                    bad "$(basename "$f") : fichier vide" ; add_issue ;;
    *)                     bad "$(basename "$f") : pas de shebang" ; add_issue ;;
  esac
done

# ─── 4. Permissions ────────────────────────────────────────────────────────
hdr "4. Permissions exécutables"
for f in scripts/lots/*.sh; do
  [[ -f "$f" ]] || continue
  if [[ -x "$f" ]]; then ok "$(basename "$f")"
  else warn "non exécutable : $(basename "$f")" ; add_fix "chmod +x $f" ; fi
done

# ─── 5. Sourcing _lib.sh ───────────────────────────────────────────────────
hdr "5. Sourcing _lib.sh en tête des build-lot-N.sh"
for n in 1 2 3 4 5 6 7; do
  f="scripts/lots/build-lot-${n}.sh"
  [[ -f "$f" ]] || { warn "L$n : absent"; continue; }

  src_line_raw="$(grep -nE '^[[:space:]]*source[[:space:]]+.*_lib\.sh' "$f" 2>/dev/null | /usr/bin/awk -F: 'NR==1{print $1; exit}')"
  if [[ -z "$src_line_raw" ]]; then
    bad "L$n : aucun source _lib.sh"
    add_issue
    continue
  fi
  src_line="$(safe_int "$src_line_raw")"
  if [[ "$src_line" -le 1 ]]; then
    warn "L$n : source ligne $src_line"
    add_issue
    continue
  fi

  before="$(/usr/bin/awk -v n="$((src_line-1))" '
    NR<=n && !/^[[:space:]]*(#|$)/ && !/^#!/ && !/^[[:space:]]*set /
  ' "$f" || true)"

  if [[ -z "$before" ]]; then
    ok "L$n : source ligne $src_line — rien avant"
  else
    warn "L$n : code avant le source (ligne $src_line)"
    printf '%s\n' "$before" | /bin/sed 's/^/      /'
    add_issue
    add_fix "déplacer 'source .../_lib.sh' en tête de $f"
  fi
done

# ─── 6. _lib.sh : sanity (PAS de dogme bash ≥ 4) ───────────────────────────
hdr "6. _lib.sh — sanity"
LIB="scripts/lots/_lib.sh"
if [[ -f "$LIB" ]]; then
  if grep -qE 'check_prereqs\(\)|check_prereqs[[:space:]]*\(\)' "$LIB"; then
    ok "check_prereqs() présent"
  else
    warn "check_prereqs() absent (utilisé par L2)"
    add_fix "ajouter check_prereqs() à _lib.sh"
  fi
  if grep -q 'write_file()' "$LIB"; then ok "write_file() présent"
  else bad "write_file() absent"; add_issue; fi
  if grep -q 'commit_and_push()' "$LIB"; then ok "commit_and_push() présent"
  else warn "commit_and_push() absent"; fi
else
  bad "_lib.sh introuvable"; add_issue
fi

# ─── 7. build-all.sh : LOTS_ROOT + BASH_BIN ────────────────────────────────
hdr "7. build-all.sh — LOTS_ROOT & BASH_BIN"
BA="scripts/lots/build-all.sh"
if [[ -f "$BA" ]]; then
  if grep -qE '^LOTS_ROOT=' "$BA"; then
    val="$(grep -E '^LOTS_ROOT=' "$BA" | /usr/bin/head -1)"
    ok "LOTS_ROOT défini : $val"
  else
    warn "LOTS_ROOT non défini explicitement (hérite de _lib.sh)"
  fi
  if grep -qE 'BASH_BIN.*(/usr/local|/opt/homebrew)' "$BA"; then
    ok "BASH_BIN priorise bash ≥ 4"
  elif grep -qE 'BASH_BIN=' "$BA"; then
    info "BASH_BIN présent (peut être bash 3.2)"
  fi
  if grep -qE '"\$BASH_BIN"[[:space:]]+"\$\{?script' "$BA"; then
    ok "invocation via \$BASH_BIN"
  else
    warn "invocation directe '\"\${script}\"'"
    add_fix "utiliser \"\$BASH_BIN\" \"\${script}\" dans $BA"
  fi
else
  bad "build-all.sh introuvable"; add_issue
fi

# ─── 8. Outils externes ────────────────────────────────────────────────────
hdr "8. Outils externes"
for tool in git mktemp awk; do
  if command -v "$tool" >/dev/null 2>&1; then
    ok "$tool : $(command -v "$tool")"
  else
    bad "$tool introuvable"; add_issue
  fi
done
for pm in bun pnpm yarn npm; do
  if command -v "$pm" >/dev/null 2>&1; then
    ver="$("$pm" --version 2>/dev/null | /usr/bin/awk 'NR==1{print; exit}' || true)"
    ok "pm optionnel : $pm (${ver:-?})"
  fi
done

# ─── 9. Git ────────────────────────────────────────────────────────────────
hdr "9. Git"
if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  branch="$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo detached)"
  ok "branche : $branch"
  dirty="$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null | /usr/bin/wc -l | tr -d ' ')"
  if [[ "$dirty" -eq 0 ]]; then ok "working tree propre"
  else warn "working tree : $dirty fichier(s) modifié(s)"; fi
else
  bad "pas de dépôt git"; add_issue
fi

# ─── 10. Smoke test syntaxique ─────────────────────────────────────────────
hdr "10. Smoke test — bash -n sur chaque build-lot-N.sh"
SMOKE_BIN="${BASH_BIN:-/bin/bash}"
for n in 1 2 3 4 5 6 7; do
  f="scripts/lots/build-lot-${n}.sh"
  [[ -f "$f" ]] || continue
  if "$SMOKE_BIN" -n "$f" 2>/dev/null; then
    ok "L$n : syntaxe OK"
  else
    bad "L$n : erreur de syntaxe"
    "$SMOKE_BIN" -n "$f" 2>&1 | /bin/sed 's/^/      /'
    add_issue
  fi
done

# ─── Synthèse ──────────────────────────────────────────────────────────────
hdr "Synthèse"
if [[ "$ISSUES" -eq 0 ]]; then
  printf '%s✅ Aucun problème détecté.%s\n' "$G" "$Z"
  exit 0
fi
printf '%s❌ %d problème(s) détecté(s).%s\n\n' "$R" "$ISSUES" "$Z"

if [[ ${#FIXES[@]} -gt 0 ]]; then
  printf '%s── Correctifs suggérés ──%s\n' "$B" "$Z"
  printf '%s\n' "${FIXES[@]}" | /usr/bin/awk '!seen[$0]++' | while IFS= read -r line; do
    printf '  %s→%s %s\n' "$Y" "$Z" "$line"
  done
fi
exit 1
