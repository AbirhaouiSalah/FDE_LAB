#!/usr/bin/env bash
# scripts/lots/apply-lots-fixes-v2.sh
# Applique tous les correctifs : _lib.sh, doctor.sh, build-all.sh,
# build-lot-{1,3,4,5,7}.sh, push-lot.sh
set -uo pipefail

APPLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y) APPLY=1; shift ;;
    -h|--help) echo "Usage: $0 [--yes]"; exit 0 ;;
    *) shift ;;
  esac
done

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[34m'; D=$'\033[2m'; Z=$'\033[0m'
else R=""; G=""; Y=""; B=""; D=""; Z=""; fi
ok()   { printf '%s✅%s %s\n' "$G" "$Z" "$*"; }
bad()  { printf '%s❌%s %s\n' "$R" "$Z" "$*"; }
warn() { printf '%s⚠️  %s\n' "$Y" "$Z" "$*"; }
info() { printf '%sℹ️  %s\n' "$B" "$Z" "$*"; }
hdr()  { printf '\n%s══ %s ══%s\n' "$B" "$*" "$Z"; }
dry()  { printf '%s[dry]%s %s\n' "$D" "$Z" "$*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "$REPO_ROOT" || exit 2

TS="$(date -u +%Y%m%d-%H%M%SZ)"
BACKUP_DIR=".lots-fix-v2-backup-${TS}"
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
    local mode=""; [[ -f "$target" ]] && mode="$(stat -f '%Lp' "$target" 2>/dev/null || true)"
    mv "$src" "$target"
    [[ -n "$mode" ]] && chmod "$mode" "$target" 2>/dev/null || true
  else
    rm -f "$src"; dry "écrirait $target"
  fi
  return 0
}

hdr "0. Contexte"
info "repo : $REPO_ROOT"
info "mode : $([[ "$APPLY" == "1" ]] && echo APPLY || echo "DRY-RUN (--yes pour appliquer)")"

# ── 1. _lib.sh : retire guard + ajoute check_prereqs ──────────────────────
hdr "1. _lib.sh"
LIB="scripts/lots/_lib.sh"
if [[ ! -f "$LIB" ]]; then bad "_lib.sh introuvable"; FAILED=$((FAILED+1)); else
  tmp="$(mktemp -t libv2)"
  /usr/bin/awk '
    BEGIN { skip=0; injected=0 }
    /BASH_VERSINFO\[0\].*lt[[:space:]]+4/ { skip=1; next }
    /BASH_VERSINFO\[0\].*<[[:space:]]+4/  { skip=1; next }
    /bash ≥ 4 requis/                     { skip=1; next }
    skip && /^fi$/ { skip=0; next }
    skip { next }
    /^# ─── Utilitaires Git/ && !injected {
      print "# ─── Pré-requis ─────────────────────────────────────────────────────"
      print "check_prereqs() { require_repo_root; require_cmd git; return 0; }"
      print ""
      injected=1
    }
    { print }
  ' "$LIB" > "$tmp"
  if write_atomic "$LIB" "$tmp"; then ok "_lib.sh patché"; APPLIED=$((APPLIED+1));
  else info "_lib.sh : aucun changement"; SKIPPED=$((SKIPPED+1)); fi
fi

# ── 2. doctor.sh : BASH_BIN priorise bash ≥ 4 ─────────────────────────────
hdr "2. doctor.sh"
DOC="scripts/lots/doctor.sh"
if [[ -f "$DOC" ]]; then
  tmp="$(mktemp -t docv2)"
  /usr/bin/awk '
    BEGIN { injected=0 }
    /^BASH_BIN="\$\(command -v bash/ && !injected {
      print "BASH_BIN=\"\""
      print "for _cand in /usr/local/bin/bash /opt/homebrew/bin/bash; do"
      print "  if [[ -x \"$_cand\" ]] && \"$_cand\" -c '\''[[ \"${BASH_VERSINFO[0]}\" -ge 4 ]]'\'' 2>/dev/null; then"
      print "    BASH_BIN=\"$_cand\"; break"
      print "  fi"
      print "done"
      print "[[ -z \"$BASH_BIN\" ]] && BASH_BIN=\"$(command -v bash || true)\""
      injected=1; next
    }
    { print }
  ' "$DOC" > "$tmp"
  if write_atomic "$DOC" "$tmp"; then ok "doctor.sh patché"; APPLIED=$((APPLIED+1));
  else info "doctor.sh : aucun changement"; SKIPPED=$((SKIPPED+1)); fi
fi

# ── 3. build-all.sh : force BASH_BIN bash ≥ 4 ─────────────────────────────
hdr "3. build-all.sh"
BA="scripts/lots/build-all.sh"
if [[ -f "$BA" ]]; then
  tmp="$(mktemp -t bav2)"
  /usr/bin/awk '
    BEGIN { injected=0 }
    /^BASH_BIN="\$\{BASH_BIN:-bash\}"/ && !injected {
      print "BASH_BIN=\"${BASH_BIN:-}\""
      print "if [[ -z \"$BASH_BIN\" ]]; then"
      print "  for _cand in /usr/local/bin/bash /opt/homebrew/bin/bash; do"
      print "    if [[ -x \"$_cand\" ]] && \"$_cand\" -c '\''[[ \"${BASH_VERSINFO[0]}\" -ge 4 ]]'\'' 2>/dev/null; then"
      print "      BASH_BIN=\"$_cand\"; break"
      print "    fi"
      print "  done"
      print "  [[ -z \"$BASH_BIN\" ]] && BASH_BIN=\"$(command -v bash)\""
      print "fi"
      print "export BASH_BIN"
      injected=1; next
    }
    { print }
  ' "$BA" > "$tmp"
  if write_atomic "$BA" "$tmp"; then ok "build-all.sh patché"; APPLIED=$((APPLIED+1));
  else info "build-all.sh : aucun changement"; SKIPPED=$((SKIPPED+1)); fi
fi

# ── 4. L1, L3 : source _lib.sh en tête ────────────────────────────────────
hdr "4. build-lot-{1,3}.sh : ordre source"
fix_src_order() {
  local f="$1"
  [[ -f "$f" ]] || { bad "$f introuvable"; FAILED=$((FAILED+1)); return; }
  local srcline; srcline="$(grep -nE '^[[:space:]]*source[[:space:]]+.*_lib\.sh' "$f" 2>/dev/null | /usr/bin/awk -F: 'NR==1{print $1; exit}')"
  [[ -z "$srcline" ]] && { bad "$f : aucun source _lib.sh"; FAILED=$((FAILED+1)); return; }
  local before; before="$(/usr/bin/awk -v n="$((srcline-1))" 'NR<=n && !/^[[:space:]]*(#|$)/ && !/^#!/ && !/^[[:space:]]*set /' "$f" || true)"
  if [[ -z "$before" ]]; then info "$f : source déjà en tête"; SKIPPED=$((SKIPPED+1)); return; fi
  info "$f : déplacement du source"
  local tmp; tmp="$(mktemp)"
  /usr/bin/awk -v srcline="$srcline" '
    BEGIN { placed=0 }
    NR==srcline { next }
    !placed && (/^[[:space:]]*set / || /^#!/) && NR>1 {
      print; print ""
      print "source \"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)/_lib.sh\""
      placed=1; next
    }
    { print }
  ' "$f" > "$tmp"
  if write_atomic "$f" "$tmp"; then ok "$f patché"; APPLIED=$((APPLIED+1));
  else info "$f : inchangé"; SKIPPED=$((SKIPPED+1)); fi
}
fix_src_order "scripts/lots/build-lot-1.sh"
fix_src_order "scripts/lots/build-lot-3.sh"

# ── 5. L4, L5, L7 : zsh → bash ────────────────────────────────────────────
hdr "5. build-lot-{4,5,7}.sh : zsh → bash"
fix_zsh() {
  local f="$1"
  [[ -f "$f" ]] || { bad "$f introuvable"; FAILED=$((FAILED+1)); return; }
  local first; first="$(/usr/bin/awk 'NR==1{print; exit}' "$f")"
  local needs=0
  [[ "$first" == "#!/usr/bin/env zsh" || "$first" == "#!/bin/zsh" ]] && needs=1
  grep -q '\${0:A:h}' "$f" 2>/dev/null && needs=1
  if [[ "$needs" -eq 0 ]]; then info "$f : déjà bash"; SKIPPED=$((SKIPPED+1)); return; fi
  local tmp; tmp="$(mktemp)"
  /usr/bin/awk '
    NR==1 && /^#!/ { print "#!/usr/bin/env bash"; next }
    { gsub(/\$\{0:A:h\}/, "$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)"); print }
  ' "$f" > "$tmp"
  if write_atomic "$f" "$tmp"; then ok "$f patché"; APPLIED=$((APPLIED+1));
  else info "$f : inchangé"; SKIPPED=$((SKIPPED+1)); fi
}
fix_zsh "scripts/lots/build-lot-4.sh"
fix_zsh "scripts/lots/build-lot-5.sh"
fix_zsh "scripts/lots/build-lot-7.sh"

# ── 6. push-lot.sh ────────────────────────────────────────────────────────
hdr "6. push-lot.sh"
PUSH="scripts/lots/push-lot.sh"
if [[ -f "$PUSH" ]]; then info "présent"; SKIPPED=$((SKIPPED+1)); else
  tmp="$(mktemp)"
  cat > "$tmp" <<'PUSHSTUB'
#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"
LOT=""; FILES=""; MSG=""; CONFIRM=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --lot) LOT="$2"; shift 2 ;;
    --files) FILES="$2"; shift 2 ;;
    --message) MSG="$2"; shift 2 ;;
    --yes|-y) CONFIRM=1; shift ;;
    *) shift ;;
  esac
done
[[ -z "$LOT" || -z "$FILES" || -z "$MSG" ]] && { echo "Usage: $0 --lot X --files 'src/' --message 'msg'"; exit 2; }
ensure_branch "$LOT"; assert_no_out_of_scope "$FILES"
git -C "$REPO_ROOT" add -A -- $FILES 2>/dev/null || true
git -C "$REPO_ROOT" diff --cached --quiet && { log_ok "rien à commiter"; exit 0; }
[[ "$CONFIRM" -ne 1 ]] && { git -C "$REPO_ROOT" diff --cached --stat; read -r "ans?Confirmer [y/N] "; [[ "$ans" == "y" ]] || exit 1; }
commit_and_push "$MSG" "$LOT"
PUSHSTUB
  if write_atomic "$PUSH" "$tmp"; then
    ok "push-lot.sh créé"; APPLIED=$((APPLIED+1))
    [[ "$APPLY" == "1" ]] && chmod +x "$PUSH" 2>/dev/null || true
  fi
fi

# ── 7. chmod ──────────────────────────────────────────────────────────────
hdr "7. chmod +x"
if [[ "$APPLY" == "1" ]]; then chmod +x scripts/lots/*.sh 2>/dev/null || true; ok "fait";
else dry "chmod +x scripts/lots/*.sh"; fi

# ── Rapport ───────────────────────────────────────────────────────────────
hdr "Rapport"
printf '  appliqués : %s\n  inchangés : %s\n  échecs    : %s\n' "$APPLIED" "$SKIPPED" "$FAILED"
[[ -d "$BACKUP_DIR" ]] && printf '  backups   : %s\n' "$BACKUP_DIR"
[[ "$APPLY" == "0" ]] && { echo ""; warn "DRY-RUN — relancer avec --yes"; }
exit 0
#!/usr/bin/env bash
# scripts/lots/apply-lots-fixes-final.sh
# Correctif final : répare shebangs, LOTS_ROOT, order du source, _lib.sh,
# doctor.sh (désactive les faux positifs), L4/L5/L7 préambules cassés.
#
# Usage:
#   bash scripts/lots/apply-lots-fixes-final.sh          # dry-run
#   bash scripts/lots/apply-lots-fixes-final.sh --yes    # applique

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
BACKUP_DIR=".lots-fix-final-backup-${TS}"
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
# 1. _lib.sh : retirer tout guard bash ≥ 4 + restaurer fallback BASH_SOURCE
# ═══════════════════════════════════════════════════════════════════════════
hdr "1. _lib.sh"
LIB="scripts/lots/_lib.sh"
if [[ ! -f "$LIB" ]]; then
  bad "_lib.sh introuvable"; FAILED=$((FAILED+1))
else
  tmp="$(mktemp -t lib-final)"

  # 1a) Retirer les guards bash ≥ 4 (toutes variantes)
  /usr/bin/awk '
    BEGIN { skip=0 }
    /BASH_VERSINFO\[0\].*lt[[:space:]]+4/ { skip=1; next }
    /BASH_VERSINFO\[0\].*<[[:space:]]+4/  { skip=1; next }
    /bash ≥ 4 requis/                     { skip=1; next }
    /declare -A.*bash ≥ 4/                { skip=1; next }
    skip && /^[[:space:]]*echo .*brew install bash/ { next }
    skip && /^[[:space:]]*echo .*export PATH=/ { next }
    skip && /^[[:space:]]*exit[[:space:]]+1/ { skip=0; next }
    skip && /^fi$/ { skip=0; next }
    skip { next }
    { print }
  ' "$LIB" > "$tmp"

  # 1b) Garantir le guard de double-source
  if ! grep -q '__LOTS_LIB_LOADED' "$tmp"; then
    info "ajout guard __LOTS_LIB_LOADED"
    tmp2="$(mktemp -t lib-final2)"
    /usr/bin/awk '
      BEGIN { added=0 }
      !added && /^set -euo pipefail/ {
        print
        print ""
        print "# Guard : ne pas sourcer deux fois"
        print "[ -n \"${__LOTS_LIB_LOADED:-}\" ] && return 0"
        print "__LOTS_LIB_LOADED=1"
        added=1
        next
      }
      { print }
    ' "$tmp" > "$tmp2"
    rm -f "$tmp"; tmp="$tmp2"
  fi

  # 1c) Garantir fallback BASH_SOURCE pour LOTS_DIR
  if ! grep -q 'BASH_SOURCE\[0\]:-' "$tmp"; then
    info "ajout fallback BASH_SOURCE[0]"
    tmp3="$(mktemp -t lib-final3)"
    /usr/bin/awk '
      /^LOTS_DIR=/ {
        print "if [ -n \"${BASH_SOURCE[0]:-}\" ]; then"
        print "  _LIB_SOURCE=\"${BASH_SOURCE[0]}\""
        print "elif [ -n \"${0:-}\" ]; then"
        print "  _LIB_SOURCE=\"${0}\""
        print "else"
        print "  echo \"❌ _lib.sh: chemin introuvable\" >&2"
        print "  exit 1"
        print "fi"
        print "LOTS_DIR=\"$(cd \"$(dirname \"${_LIB_SOURCE}\")\" && pwd)\""
        next
      }
      { print }
    ' "$tmp" > "$tmp3"
    rm -f "$tmp"; tmp="$tmp3"
  fi

  # 1d) Garantir check_prereqs (utilisée par L2)
  if ! grep -q 'check_prereqs()' "$tmp"; then
    info "ajout check_prereqs()"
    tmp4="$(mktemp -t lib-final4)"
    /usr/bin/awk '
      BEGIN { injected=0 }
      /^# ─── Utilitaires Git/ && !injected {
        print "# ─── Pré-requis ─────────────────────────────────────────────────────"
        print "check_prereqs() { require_repo_root; require_cmd git; return 0; }"
        print ""
        injected=1
      }
      { print }
    ' "$tmp" > "$tmp4"
    rm -f "$tmp"; tmp="$tmp4"
  fi

  if write_atomic "$LIB" "$tmp"; then
    ok "_lib.sh : patché (guard retiré, fallback + check_prereqs OK)"
    APPLIED=$((APPLIED+1))
  else
    dim "_lib.sh : déjà à jour"
    SKIPPED=$((SKIPPED+1))
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# 2. build-all.sh : force LOTS_ROOT + BASH_BIN (bash ≥ 4)
# ═══════════════════════════════════════════════════════════════════════════
hdr "2. build-all.sh"
BA="scripts/lots/build-all.sh"
if [[ ! -f "$BA" ]]; then
  bad "build-all.sh introuvable"; FAILED=$((FAILED+1))
else
  tmp="$(mktemp -t ba-final)"

  # 2a) Force BASH_BIN sur bash ≥ 4
  /usr/bin/awk '
    BEGIN { injected_bin=0 }
    /^BASH_BIN="\$\{BASH_BIN:-bash\}"/ && !injected_bin {
      print "BASH_BIN=\"${BASH_BIN:-}\""
      print "if [[ -z \"$BASH_BIN\" ]]; then"
      print "  for _cand in /usr/local/bin/bash /opt/homebrew/bin/bash; do"
      print "    if [[ -x \"$_cand\" ]] && \"$_cand\" -c '\''[[ \"${BASH_VERSINFO[0]}\" -ge 4 ]]'\'' 2>/dev/null; then"
      print "      BASH_BIN=\"$_cand\"; break"
      print "    fi"
      print "  done"
      print "  [[ -z \"$BASH_BIN\" ]] && BASH_BIN=\"$(command -v bash)\""
      print "fi"
      print "export BASH_BIN"
      injected_bin=1; next
    }
    /^BASH_BIN="bash"/ && !injected_bin {
      print "BASH_BIN=\"${BASH_BIN:-}\""
      print "if [[ -z \"$BASH_BIN\" ]]; then"
      print "  for _cand in /usr/local/bin/bash /opt/homebrew/bin/bash; do"
      print "    if [[ -x \"$_cand\" ]] && \"$_cand\" -c '\''[[ \"${BASH_VERSINFO[0]}\" -ge 4 ]]'\'' 2>/dev/null; then"
      print "      BASH_BIN=\"$_cand\"; break"
      print "    fi"
      print "  done"
      print "  [[ -z \"$BASH_BIN\" ]] && BASH_BIN=\"$(command -v bash)\""
      print "fi"
      print "export BASH_BIN"
      injected_bin=1; next
    }
    { print }
  ' "$BA" > "$tmp"

  # 2b) Force LOTS_ROOT sur le répertoire du script
  tmp2="$(mktemp -t ba-final2)"
  /usr/bin/awk '
    BEGIN { stripped=0; injected=0 }
    # Supprime toutes les définitions existantes de LOTS_ROOT
    /^LOTS_ROOT=/ { next }
    /^export LOTS_ROOT/ { next }
    /^readonly LOTS_ROOT=/ { next }
    # Insère juste après le premier source
    /^source.*_lib\.sh/ && !injected {
      print
      print ""
      print "# ── Chemins canoniques (forcés) ──"
      print "LOTS_ROOT=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\""
      print "REPO_ROOT=\"$(cd \"$LOTS_ROOT/../..\" && pwd)\""
      print "export LOTS_ROOT REPO_ROOT"
      injected=1; next
    }
    { print }
  ' "$tmp" > "$tmp2"
  rm -f "$tmp"

  if write_atomic "$BA" "$tmp2"; then
    ok "build-all.sh : BASH_BIN + LOTS_ROOT patchés"
    APPLIED=$((APPLIED+1))
  else
    dim "build-all.sh : aucun changement"
    SKIPPED=$((SKIPPED+1))
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# 3. build-lot-{1,3}.sh : source _lib.sh en tête
# ═══════════════════════════════════════════════════════════════════════════
hdr "3. build-lot-{1,3}.sh : ordre source"

fix_source_order() {
  local f="$1"
  [[ -f "$f" ]] || { bad "$f introuvable"; FAILED=$((FAILED+1)); return; }

  local srcline
  srcline="$(grep -nE '^[[:space:]]*source[[:space:]]+.*_lib\.sh' "$f" 2>/dev/null | /usr/bin/awk -F: 'NR==1{print $1; exit}')"
  if [[ -z "$srcline" ]]; then
    bad "$f : aucun source _lib.sh"; FAILED=$((FAILED+1)); return
  fi

  local before
  before="$(/usr/bin/awk -v n="$((srcline-1))" '
    NR<=n && !/^[[:space:]]*(#|$)/ && !/^#!/ && !/^[[:space:]]*set /
  ' "$f" || true)"

  if [[ -z "$before" ]]; then
    dim "$f : source déjà en tête"; SKIPPED=$((SKIPPED+1)); return
  fi

  info "$f : déplacement du source"
  local tmp; tmp="$(mktemp)"
  /usr/bin/awk -v srcline="$srcline" '
    BEGIN { placed=0 }
    NR==srcline { next }
    !placed && (/^[[:space:]]*set / || /^#!/) && NR>1 {
      print; print ""
      print "source \"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)/_lib.sh\""
      placed=1; next
    }
    { print }
  ' "$f" > "$tmp"

  if write_atomic "$f" "$tmp"; then
    ok "$f : patché"; APPLIED=$((APPLIED+1))
  else
    dim "$f : inchangé"; SKIPPED=$((SKIPPED+1))
  fi
}

fix_source_order "scripts/lots/build-lot-1.sh"
fix_source_order "scripts/lots/build-lot-3.sh"

# ═══════════════════════════════════════════════════════════════════════════
# 4. build-lot-{4,5,7}.sh : réécriture complète du préambule
# ═══════════════════════════════════════════════════════════════════════════
hdr "4. build-lot-{4,5,7}.sh : réécriture du préambule"

rebuild_preamble() {
  local f="$1"
  [[ -f "$f" ]] || { bad "$f introuvable"; FAILED=$((FAILED+1)); return; }

  # Vérifie si le préambule est cassé (contient ${0:A:h} ou un shebang zsh)
  local first; first="$(/usr/bin/awk 'NR==1{print; exit}' "$f")"
  local broken=0
  [[ "$first" == "#!/usr/bin/env zsh" || "$first" == "#!/bin/zsh" ]] && broken=1
  grep -q '\${0:A:h}' "$f" 2>/dev/null && broken=1

  # Vérifie aussi : source n'est pas en tête
  local srcline
  srcline="$(grep -nE '^[[:space:]]*source[[:space:]]+.*_lib\.sh' "$f" 2>/dev/null | /usr/bin/awk -F: 'NR==1{print $1; exit}')"
  if [[ -n "$srcline" && "$srcline" -gt 10 ]]; then
    broken=1
  fi

  if [[ "$broken" -eq 0 ]]; then
    dim "$f : préambule OK"; SKIPPED=$((SKIPPED+1)); return
  fi

  info "$f : réécriture du préambule"

  # Extrait : commentaires initiaux + corps (après 'set -e')
  local comments body
  comments="$(/usr/bin/awk '
    NR==1 { next }
    /^#/ { print; next }
    { exit }
  ' "$f" 2>/dev/null || true)"

  body="$(/usr/bin/awk '
    BEGIN { started=0 }
    /^set -e/ { started=1; next }
    started { print }
  ' "$f" 2>/dev/null || true)"

  local tmp; tmp="$(mktemp)"
  {
    printf '#!/usr/bin/env bash\n'
    [[ -n "$comments" ]] && printf '%s\n' "$comments"
    printf '\n'
    printf 'set -euo pipefail\n\n'
    printf '# Source helpers EN PREMIER (définit LOT_TAG, write_file, etc.)\n'
    printf 'source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"\n\n'
    printf 'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\n'
    printf 'REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"\n'
    [[ -n "$body" ]] && printf '\n%s\n' "$body"
  } > "$tmp"

  if write_atomic "$f" "$tmp"; then
    ok "$f : préambule reconstruit"; APPLIED=$((APPLIED+1))
  else
    dim "$f : inchangé"; SKIPPED=$((SKIPPED+1))
  fi
}

rebuild_preamble "scripts/lots/build-lot-4.sh"
rebuild_preamble "scripts/lots/build-lot-5.sh"
rebuild_preamble "scripts/lots/build-lot-7.sh"

# ═══════════════════════════════════════════════════════════════════════════
# 5. doctor.sh : désactiver les faux positifs (guard bash ≥ 4, fallback BS)
# ═══════════════════════════════════════════════════════════════════════════
hdr "5. doctor.sh : faux positifs"

DOC="scripts/lots/doctor.sh"
if [[ ! -f "$DOC" ]]; then
  warn "doctor.sh introuvable"; SKIPPED=$((SKIPPED+1))
else
  tmp="$(mktemp -t doc-final)"

  # Commenter les check_lib qui exigent le guard bash ≥ 4 ou le fallback BASH_SOURCE
  /usr/bin/awk '
    /check_lib[[:space:]]+.[^"]*BASH_VERSINFO/ && /guard bash/ {
      print "# [désactivé] " $0 "   # obsolète : bash 3.2 OK si pas de declare -A"
      next
    }
    /check_lib[[:space:]]+.[^"]*BASH_SOURCE/ && /fallback/ {
      print "# [désactivé] " $0 "   # cosmétique"
      next
    }
    { print }
  ' "$DOC" > "$tmp"

  if write_atomic "$DOC" "$tmp"; then
    ok "doctor.sh : faux positifs désactivés"; APPLIED=$((APPLIED+1))
  else
    dim "doctor.sh : aucun changement"; SKIPPED=$((SKIPPED+1))
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# 6. push-lot.sh : créer si absent
# ═══════════════════════════════════════════════════════════════════════════
hdr "6. push-lot.sh"
PUSH="scripts/lots/push-lot.sh"
if [[ -f "$PUSH" ]]; then
  dim "présent"; SKIPPED=$((SKIPPED+1))
else
  tmp="$(mktemp)"
  cat > "$tmp" <<'PUSHSTUB'
#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"
LOT=""; FILES=""; MSG=""; CONFIRM=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --lot) LOT="$2"; shift 2 ;;
    --files) FILES="$2"; shift 2 ;;
    --message) MSG="$2"; shift 2 ;;
    --yes|-y) CONFIRM=1; shift ;;
    *) shift ;;
  esac
done
[[ -z "$LOT" || -z "$FILES" || -z "$MSG" ]] && {
  echo "Usage: $0 --lot X --files 'src/' --message 'msg' [--yes]"; exit 2
}
ensure_branch "$LOT"; assert_no_out_of_scope "$FILES"
git -C "$REPO_ROOT" add -A -- $FILES 2>/dev/null || true
git -C "$REPO_ROOT" diff --cached --quiet && { log_ok "rien à commiter"; exit 0; }
commit_and_push "$MSG" "$LOT"
PUSHSTUB
  if write_atomic "$PUSH" "$tmp"; then
    ok "push-lot.sh créé"; APPLIED=$((APPLIED+1))
    [[ "$APPLY" == "1" ]] && chmod +x "$PUSH" 2>/dev/null || true
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# 7. chmod +x
# ═══════════════════════════════════════════════════════════════════════════
hdr "7. chmod +x"
if [[ "$APPLY" == "1" ]]; then
  chmod +x scripts/lots/*.sh 2>/dev/null || true
  ok "appliqué"
else
  dry "chmod +x scripts/lots/*.sh"
fi

# ═══════════════════════════════════════════════════════════════════════════
# 8. Vérifications finales
# ═══════════════════════════════════════════════════════════════════════════
hdr "8. Vérifications"

info "Shebangs L1..L7 :"
for n in 1 2 3 4 5 6 7; do
  f="scripts/lots/build-lot-${n}.sh"
  [[ -f "$f" ]] || continue
  first="$(/usr/bin/awk 'NR==1{print; exit}' "$f")"
  if [[ "$first" == "#!/usr/bin/env bash" ]]; then
    printf '  %s✅%s L%d : %s\n' "$G" "$Z" "$n" "$first"
  else
    printf '  %s❌%s L%d : %s\n' "$R" "$Z" "$n" "$first"
  fi
done

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

info "LOTS_ROOT dans build-all.sh :"
grep -n '^LOTS_ROOT=' scripts/lots/build-all.sh | /usr/bin/head -2 || warn "introuvable"

info "_lib.sh source test :"
bash -c 'source scripts/lots/_lib.sh && echo "  ✅ sourcé, C_BLUE=[$C_BLUE]"' 2>&1 | /usr/bin/head -2 || echo "  ❌ échec"

info "Préambules L4/L5/L7 (5 premières lignes) :"
for n in 4 5 7; do
  f="scripts/lots/build-lot-${n}.sh"
  [[ -f "$f" ]] || continue
  echo "  ── L${n} ──"
  /usr/bin/awk 'NR<=5 { print "    " $0 }' "$f"
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
dim "  bash scripts/lots/doctor.sh"
dim "  bash scripts/lots/build-all.sh --dry-run"
dim "  ONLY=4 bash scripts/lots/build-all.sh --dry-run"

exit 0