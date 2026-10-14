#!/usr/bin/env bash
# scripts/lots/_lib.sh — Helpers partagés et unifiés pour tous les scripts de lots.
# À sourcer : source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
#
# ─── Guards (AVANT tout) ──────────────────────────────────────────────────
# 1) Doit être exécuté par bash, pas sh/dash.
if [ -z "${BASH_VERSION:-}" ]; then
  echo "❌ _lib.sh doit être sourcé depuis bash (pas sh/dash)." >&2
  echo "   Lancez: bash scripts/lots/build-lot-N.sh" >&2
  exit 1
fi
if [ -n "${BASH_SOURCE[0]:-}" ]; then
  _LIB_SOURCE="${BASH_SOURCE[0]}"
elif [ -n "${0:-}" ]; then
  _LIB_SOURCE="${0}"
else
  echo "❌ _lib.sh: chemin introuvable" >&2
  exit 1
fi
LOTS_DIR="$(cd "$(dirname "${_LIB_SOURCE}")" && pwd)"
REPO_ROOT="$(cd "${LOTS_DIR}/../.." && pwd)"
LOTS_ROOT="$LOTS_DIR"
LOG_ROOT="${LOTS_DIR}/.logs"

export LOTS_DIR REPO_ROOT LOTS_ROOT LOG_ROOT

# Détection du gestionnaire de paquets (bun, pnpm, yarn, npm)
detect_pm() {
  if [[ -f "$REPO_ROOT/bun.lockb" ]] && command -v bun >/dev/null 2>&1; then echo bun
  elif [[ -f "$REPO_ROOT/pnpm-lock.yaml" ]] && command -v pnpm >/dev/null 2>&1; then echo pnpm
  elif [[ -f "$REPO_ROOT/yarn.lock" ]] && command -v yarn >/dev/null 2>&1; then echo yarn
  elif [[ -f "$REPO_ROOT/package.json" ]]; then echo npm
  else echo "pnpm"; fi
}

: "${PKG_MGR:=$(detect_pm)}"
export PKG_MGR

# ─── Compatibilité BSD / macOS (head & tail) ──────────────────────────────
HEAD_BIN="/usr/bin/head"
[ -x "$HEAD_BIN" ] || HEAD_BIN="head"
head_n() { "$HEAD_BIN" -n "$1"; }

TAIL_BIN="/usr/bin/tail"
[ -x "$TAIL_BIN" ] || TAIL_BIN="tail"
tail_n() { "$TAIL_BIN" -n "$1"; }

# ─── Flags globaux & Options par défaut ────────────────────────────────────
: "${DRY_RUN:=1}"
: "${SKIP_TESTS:=0}"
: "${SKIP_BUILD:=0}"
: "${SKIP_PUSH:=0}"
: "${NO_PUSH:=0}"
: "${NO_PROPAGATE:=0}"
: "${NO_TESTS:=0}"
: "${NO_BUILD:=0}"
: "${VERBOSE:=0}"
: "${FORCE:=0}"
: "${ASSUME_YES:=0}"
: "${LOT_TAG:=lot}"

export DRY_RUN SKIP_TESTS SKIP_BUILD SKIP_PUSH NO_PUSH NO_PROPAGATE NO_TESTS NO_BUILD VERBOSE FORCE ASSUME_YES LOT_TAG

# ─── Couleurs ──────────────────────────────────────────────────────────────
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  C_RESET=$'\033[0m'; C_RST=$'\033[0m'
  C_DIM=$'\033[2m';    C_BOLD=$'\033[1m'
  C_RED=$'\033[31m';   C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m';  C_MAGENTA=$'\033[35m'; C_CYAN=$'\033[36m'
  C_GRAY=$'\033[90m'
  C_GRN=$C_GREEN; C_BLU=$C_BLUE; C_YEL=$C_YELLOW; C_MAG=$C_MAGENTA; C_CYN=$C_CYAN
else
  C_RESET=""; C_RST=""; C_DIM=""; C_BOLD=""
  C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_MAGENTA=""; C_CYAN=""; C_GRAY=""
  C_GRN=""; C_BLU=""; C_YEL=""; C_MAG=""; C_CYN=""
fi

# Filet de sécurité : toute couleur référencée mais non définie devient vide.
# (Évite "C_BLUE?: unbound variable" si un script accède à une couleur avant source.)
: "${C_RESET:=}" "${C_RST:=}" "${C_DIM:=}" "${C_BOLD:=}"
: "${C_RED:=}" "${C_GREEN:=}" "${C_YELLOW:=}" "${C_BLUE:=}"
: "${C_MAGENTA:=}" "${C_CYAN:=}" "${C_GRAY:=}"
: "${C_GRN:=}" "${C_BLU:=}" "${C_YEL:=}" "${C_MAG:=}" "${C_CYN:=}"
export C_RESET C_RST C_DIM C_BOLD C_RED C_GREEN C_YELLOW C_BLUE \
       C_MAGENTA C_CYAN C_GRAY C_GRN C_BLU C_YEL C_MAG C_CYN

# ─── Logging unifié ────────────────────────────────────────────────────────
_log_ts() { date -u +"%H:%M:%S"; }

_log_raw() {
  if [ -n "${LOG_FILE:-}" ]; then
    printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$LOG_FILE"
  fi
}

log()      { printf '%s%s %s[%s]%s %s\n' "$C_DIM" "$(_log_ts)" "$C_BLUE" "${LOT_TAG:-lot}" "$C_RESET" "$*"; _log_raw "LOG: $*"; }
info()     { printf '%s%s %s[%s]%s ℹ️  %s\n' "$C_DIM" "$(_log_ts)" "$C_BLUE" "${LOT_TAG:-lot}" "$C_RESET" "$*"; _log_raw "INFO: $*"; }
ok()       { printf '%s%s %s[%s]%s %s✅%s %s\n' "$C_DIM" "$(_log_ts)" "$C_GREEN" "${LOT_TAG:-lot}" "$C_RESET" "$C_GREEN" "$C_RESET" "$*"; _log_raw "OK: $*"; }
warn()     { printf '%s%s %s[%s]%s %s⚠️ %s\n' "$C_DIM" "$(_log_ts)" "$C_YELLOW" "${LOT_TAG:-lot}" "$C_RESET" "$C_YELLOW" "$C_RESET" "$*" >&2; _log_raw "WARN: $*"; }
err()      { printf '%s%s %s[%s]%s %s❌%s %s\n' "$C_DIM" "$(_log_ts)" "$C_RED" "${LOT_TAG:-lot}" "$C_RESET" "$C_RED" "$C_RESET" "$*" >&2; _log_raw "ERR: $*"; }
die()      { err "$*"; exit 1; }
dry()      { printf '%s[dry]%s %s\n' "$C_DIM" "$C_RST" "$*"; _log_raw "DRY: $*"; }
step()     { printf '%s  → %s%s\n' "$C_CYN" "$*" "$C_RST"; _log_raw "STEP: $*"; }
section()  { printf '\n%s%s── %s ──%s\n' "$C_BOLD" "$C_MAGENTA" "$*" "$C_RESET"; }
head1()    { printf '\n%s════ %s ════%s\n' "$C_MAG" "$*" "$C_RST"; }
log_step() { printf '\n%s\n' "$C_BOLD$C_BLUE══ $* ══$C_RESET"; }
log_ok()   { ok "$*"; }
log_warn() { warn "$*"; }
log_err()  { err "$*"; }
log_dim()  { printf '%s\n' "$C_GRAY$*$C_RESET"; }

log_init() {
  local lot="$1"
  LOT_TAG="$lot"
  local stamp
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  mkdir -p "${LOG_ROOT}/${stamp}-${lot}"
  LOG_FILE="${LOG_ROOT}/${stamp}-${lot}/build.log"
  : > "$LOG_FILE"
  _log_raw "log file initialisé: $LOG_FILE"
}

# ─── Gestion des fichiers & Écriture ───────────────────────────────────────
# Écrit un fichier de manière idempotente (respecte DRY_RUN et FORCE)
write_file() {
  local rel="$1"
  local mode="${2:-}"   # "safe" = ne pas écraser si existe
  local abs="$rel"
  [[ "$rel" != /* ]] && abs="${REPO_ROOT}/${rel}"
  local rel_display="${abs#"$REPO_ROOT"/}"

  local tmp; tmp="$(mktemp)"
  cat > "$tmp"

  # No-op si contenu identique
  if [[ -f "$abs" ]] && cmp -s "$tmp" "$abs" && [[ "${FORCE:-0}" != "1" ]]; then
    rm -f "$tmp"
    log_dim "= ${rel_display} (inchangé)"
    return 0
  fi

  # Mode safe : ne pas écraser un fichier existant sauf FORCE=1
  if [[ "$mode" == "safe" ]] && [[ -e "$abs" ]] && [[ "${FORCE:-0}" != "1" ]]; then
    warn "existe déjà, ignoré : $abs (FORCE=1 pour écraser)"
    rm -f "$tmp"
    return 0
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    local status="créer"
    [[ -f "$abs" ]] && status="modifier"
    info "  + ${rel_display} ($status [dry-run])"
    rm -f "$tmp"
    return 0
  fi

  mkdir -p "$(dirname "$abs")"
  mv "$tmp" "$abs"
  ok "écrit ${rel_display}"
}

write_exec() {
  local path="$1"
  write_file "$path"
  if [ "${DRY_RUN:-0}" -eq 0 ]; then
    chmod +x "$path" 2>/dev/null || true
  fi
}

write_file_if_absent() {
  local rel="$1"
  local abs="${REPO_ROOT}/${rel}"
  if [[ -e "${abs}" ]]; then
    log_dim "= ${rel} (déjà présent, non touché)"
    cat > /dev/null
    return 0
  fi
  write_file "${rel}"
}

append_line() {
  local file="$1" line="$2"
  [[ "${DRY_RUN:-0}" -eq 1 ]] && { dry "append '$line' to $file"; return 0; }
  touch "$file"
  if ! grep -qxF "$line" "$file"; then
    printf '%s\n' "$line" >> "$file"
    ok "ajouté à $file : $line"
  fi
}

emit_banner() {
  local lot="$1" desc="$2"
  printf '# ⚠ Généré par scripts/lots/build-lot-%s.sh — %s\n' "${lot}" "${desc}"
  printf '# Ne pas éditer à la main : relancer le script ou modifier le template.\n\n'
}

# ─── Pré-requis ─────────────────────────────────────────────────────
check_prereqs() { require_repo_root; require_cmd git; return 0; }

# ─── Utilitaires Git ───────────────────────────────────────────────────────
require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "commande requise introuvable: $cmd"
}

require_repo_root() {
  [[ -d "${REPO_ROOT}/.git" ]] || die "REPO_ROOT invalide (pas de .git): ${REPO_ROOT}"
}

require_clean_tree() {
  if [[ -n "$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null)" ]]; then
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
      warn "Working tree non propre (ignoré en mode dry-run)"
      return 0
    fi
    err "Working tree non propre"
    git -C "$REPO_ROOT" status --short | head_n 10 | sed 's/^/    /'
    die "Veuillez faire un commit ou un stash avant d'exécuter ce script."
  fi
  return 0
}

remote_branch_exists() {
  local b="$1"
  git ls-remote --heads origin "refs/heads/$b" 2>/dev/null | grep -q "$b"
}

ensure_branch() {
  local target="$1"
  local current; current="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || git branch --show-current)"
  if [[ "$current" == "$target" ]]; then
    ok "branche OK: $target"
    return 0
  fi
  warn "branche actuelle=$current, attendu=$target — checkout"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    return 0
  fi
  run git -C "$REPO_ROOT" fetch origin "$target" || true
  if git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$target"; then
    run git -C "$REPO_ROOT" checkout "$target"
  elif git -C "$REPO_ROOT" show-ref --verify --quiet "refs/remotes/origin/$target"; then
    run git -C "$REPO_ROOT" checkout -b "$target" "origin/$target"
  else
    run git -C "$REPO_ROOT" checkout -b "$target" main 2>/dev/null || run git -C "$REPO_ROOT" checkout -b "$target"
  fi
  run git -C "$REPO_ROOT" pull --ff-only origin "$target" || warn "pull a échoué (branche locale seule ?)"
}

checkout_or_create() {
  local branch="$1" base="${2:-main}"
  ensure_branch "$branch"
}

checkout_branch() {
  ensure_branch "$1"
}

get_from_branch() {
  local branch="$1" file="$2"
  git show "origin/$branch:$file" 2>/dev/null || echo ""
}

file_in_branch() {
  local branch="$1" file="$2"
  git cat-file -e "origin/$branch:$file" 2>/dev/null
}

copy_from_branch() {
  local branch="$1" src_path="$2" dst_path="$3"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    dry "would copy $branch:$src_path → $dst_path"
    return 0
  fi
  if file_in_branch "$branch" "$src_path"; then
    mkdir -p "$(dirname "$dst_path")"
    git show "$branch:$src_path" > "$dst_path"
    ok "copied $src_path from $branch"
    return 0
  fi
  return 1
}

show_diff_summary() {
  local scope="${1:-.}"
  if git rev-parse --verify HEAD >/dev/null 2>&1; then
    git diff HEAD --stat -- "$scope" | tail_n 20
  fi
}

commit_and_push() {
  local msg="$1"; shift || true
  local branches=("$@")

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log "[dry] commit + push : $msg"
    return 0
  fi

  git -C "$REPO_ROOT" add -A 2>/dev/null || true
  if git -C "$REPO_ROOT" diff --cached --quiet; then
    ok "rien à commiter"
  else
    git -C "$REPO_ROOT" commit -m "$msg" || { warn "commit échoué"; return 1; }
    ok "commit : $msg"
  fi

  if [[ "${NO_PUSH:-0}" == "1" ]] || [[ "${SKIP_PUSH:-0}" == "1" ]]; then
    warn "skip push (--no-push/--skip-push)"
    return 0
  fi

  if [ ${#branches[@]} -eq 0 ]; then
    local current
    current="$(git branch --show-current)"
    branches=("$current")
  fi

  local failed=""
  for b in "${branches[@]}"; do
    step "push → $b"
    if git push origin "HEAD:refs/heads/$b" 2>&1 | tail_n 2; then
      ok "  ✅ $b"
    else
      warn "  ❌ $b"
      failed="$failed $b"
    fi
  done

  [ -z "$failed" ] || { warn "push échoués :$failed"; return 1; }
  return 0
}

commit_all() {
  commit_and_push "$1"
}

propagate_to() {
  local files="$1" msg="$2"
  [[ "${NO_PROPAGATE:-0}" == "1" ]] && { warn "skip propagation (--no-propagate)"; return 0; }

  local prop="$LOTS_DIR/../git/propagate.sh"
  if [[ -x "$prop" ]]; then
    "$prop" --files "$files" --message "$msg" --yes || warn "propagation issues (non-blocking)"
  else
    warn "propagate.sh introuvable à $prop"
  fi
}

# ─── Exécution sécurisée (DRY_RUN) ─────────────────────────────────────────
run() {
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    printf '%s    [dry-run] %s%s\n' "$C_DIM" "$*" "$C_RESET"
    _log_raw "DRY-RUN EXEC: $*"
    return 0
  fi
  if [[ "${VERBOSE:-0}" -eq 1 ]]; then
    printf '%s    $ %s%s\n' "$C_DIM" "$*" "$C_RESET"
  fi
  _log_raw "EXEC: $*"
  "$@"
}

# ─── Contrôle de périmètre ─────────────────────────────────────────────────
assert_no_out_of_scope() {
  local allowed="$1"
  local changed
  changed="$(
    { git -C "$REPO_ROOT" diff --name-only
      git -C "$REPO_ROOT" diff --cached --name-only
      git -C "$REPO_ROOT" ls-files --others --exclude-standard
    } | sort -u
  )"
  local leaks=""
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    local match=0
    for a in $allowed; do
      case "$f" in "$a"*) match=1; break ;; esac
    done
    [[ $match -eq 0 ]] && leaks="$leaks $f"
  done <<< "$changed"

  if [[ -n "$leaks" ]]; then
    warn "Fichiers hors périmètre détectés:"
    for f in $leaks; do warn "    - $f"; done
    warn "Ils ne seront pas pris en compte par la liste blanche."
  fi
}

# ─── Tests & Qualité ───────────────────────────────────────────────────────
run_tsc() {
  log "typecheck (tsc --noEmit)"
  ( cd "${REPO_ROOT}" && "${PKG_MGR}" exec tsc --noEmit )
  ok "typecheck OK"
}

run_vitest() {
  local pattern="${1:-}"
  log "vitest ${pattern:-<all>}"
  ( cd "${REPO_ROOT}" && "${PKG_MGR}" exec vitest run ${pattern} )
  ok "tests OK"
}

run_i18n_parity() {
  local script="${REPO_ROOT}/scripts/quality/check-i18n-parity.ts"
  [[ -f "${script}" ]] || { log_warn "check-i18n-parity.ts absent — skip"; return 0; }
  log "i18n parity"
  ( cd "${REPO_ROOT}" && "${PKG_MGR}" exec tsx "${script}" )
  ok "i18n parity OK"
}

run_tests() {
  { [[ "${SKIP_TESTS:-0}" == "1" ]] || [[ "${NO_TESTS:-0}" == "1" ]]; } && { warn "skip tests"; return 0; }
  [[ "${DRY_RUN:-0}" == "1" ]] && return 0
  command -v "${PKG_MGR}" >/dev/null 2>&1 || { warn "${PKG_MGR} absent — skip tests"; return 0; }

  run_tsc || warn "typecheck issues"
  run_vitest || warn "test issues"
  run_i18n_parity || warn "i18n issues"
}

run_check() {
  if [ ! -x "$REPO_ROOT/scripts/quality/check.sh" ]; then
    warn "scripts/quality/check.sh absent — skip check"
    return 0
  fi
  if [ "${DRY_RUN:-0}" -eq 1 ]; then
    log "[dry] lancerait check.sh"
    return 0
  fi
  step "check complet"
  "$REPO_ROOT/scripts/quality/check.sh"
}

# ─── Parsing d'arguments & Rapports ────────────────────────────────────────
parse_common_args() {
  local consumed=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes|-y)          DRY_RUN=0; ASSUME_YES=1; export DRY_RUN ASSUME_YES; consumed=$((consumed+1)); shift ;;
      --dry-run)         DRY_RUN=1; export DRY_RUN; consumed=$((consumed+1)); shift ;;
      --skip-tests|--no-tests) SKIP_TESTS=1; NO_TESTS=1; export SKIP_TESTS NO_TESTS; consumed=$((consumed+1)); shift ;;
      --skip-build|--no-build) SKIP_BUILD=1; NO_BUILD=1; export SKIP_BUILD NO_BUILD; consumed=$((consumed+1)); shift ;;
      --skip-push|--no-push)   SKIP_PUSH=1; NO_PUSH=1; export SKIP_PUSH NO_PUSH; consumed=$((consumed+1)); shift ;;
      --no-propagate)    NO_PROPAGATE=1; export NO_PROPAGATE; consumed=$((consumed+1)); shift ;;
      --verbose|-v)      VERBOSE=1; export VERBOSE; consumed=$((consumed+1)); shift ;;
      -h|--help)         usage_hint; exit 0 ;;
      *) break ;;
    esac
  done
  return $consumed
}

# Alias rétrocompatible
parse_common_flags() {
  parse_common_args "$@"
}

usage_hint() {
  cat <<EOF
Usage: $0 [--dry-run | --yes] [--skip-tests] [--skip-build] [--skip-push] [--verbose]

  --dry-run      (défaut) simule sans modifier ni commiter
  --yes, -y      exécute réellement (écrit + commit + push)
  --skip-tests   saute la vérification des types et les tests
  --skip-build   saute l'étape de compilation
  --skip-push    saute le push distant
  --verbose, -v  affiche les commandes détaillées
EOF
}

print_summary() {
  local lot="$1" pivot="$2" nsubs="$3"
  section "Résumé $lot"
  printf '  %-14s %s\n' "pivot"     "$pivot"
  printf '  %-14s %s\n' "sous-lots" "$nsubs"
  printf '  %-14s %s\n' "mode"      "$( [[ $DRY_RUN -eq 1 ]] && echo "${C_YELLOW}DRY-RUN${C_RESET} (relancer avec --yes)" || echo "${C_GREEN}RÉEL${C_RESET}" )"
  printf '  %-14s %s\n' "tests"     "$( { [[ ${SKIP_TESTS:-0} -eq 1 ]] || [[ ${NO_TESTS:-0} -eq 1 ]]; } && echo skipped || echo ok )"
  printf '  %-14s %s\n' "build"     "$( { [[ ${SKIP_BUILD:-0} -eq 1 ]] || [[ ${NO_BUILD:-0} -eq 1 ]]; } && echo skipped || echo ok )"
  printf '  %-14s %s\n' "push"      "$( { [[ ${SKIP_PUSH:-0} -eq 1 ]] || [[ ${NO_PUSH:-0} -eq 1 ]]; } && echo skipped || echo ok )"
}

lot_summary() {
  local lot="$1"; shift
  local n_files="$1"; shift
  local n_tests="${1:-}"
  printf '\n%s\n' "${C_BOLD}${C_GREEN}┌─ Lot ${lot} ─────────────────────${C_RESET}"
  printf '%s\n'   "${C_GREEN}│${C_RESET} fichiers écrits : ${C_BOLD}${n_files}${C_RESET}"
  [[ -n "${n_tests}" ]] && printf '%s\n' "${C_GREEN}│${C_RESET} tests           : ${C_BOLD}${n_tests}${C_RESET}"
  printf '%s\n'   "${C_BOLD}${C_GREEN}└──────────────────────────────────${C_RESET}"
}

write_report() {
  local lot_num="$1"
  local lot_slug="$2"
  local body="$3"
  if [ "${DRY_RUN:-0}" -eq 1 ]; then
    return 0
  fi
  mkdir -p "$REPO_ROOT/.reports"
  local report="$REPO_ROOT/.reports/L${lot_num}-$(date +%Y%m%d-%H%M%SZ).md"
  {
    echo "# L${lot_num} — ${lot_slug}"
    echo ""
    echo "**Date** : $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo ""
    echo "$body"
  } > "$report"
  ok "rapport → $report"
}
