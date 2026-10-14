#!/usr/bin/env bash
# scripts/lots/build-all.sh — Orchestrateur L1..L7.
# Force `bash` pour chaque sous-script (indépendant de son shebang).
# Capture stdout/stderr, agrège un rapport, sortie non-zéro si au moins un échec.

source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

# ── Chemins canoniques (forcés) ──
LOTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LOTS_ROOT/../.." && pwd)"
export LOTS_ROOT REPO_ROOT

# ─── Config ────────────────────────────────────────────────────────────────
LOTS=(1 2 3 4 5 6 7)
SKIP="${SKIP:-}"                       # ex: SKIP="2 3"
ONLY="${ONLY:-}"                       # ex: ONLY="4"
CONTINUE_ON_ERROR="${CONTINUE_ON_ERROR:-1}"   # 1 par défaut : on veut le rapport complet
BASH_BIN="${BASH_BIN:-}"
if [[ -z "$BASH_BIN" ]]; then
  for _cand in /usr/local/bin/bash /opt/homebrew/bin/bash; do
    if [[ -x "$_cand" ]] && "$_cand" -c '[[ "${BASH_VERSINFO[0]}" -ge 4 ]]' 2>/dev/null; then
      BASH_BIN="$_cand"; break
    fi
  done
  [[ -z "$BASH_BIN" ]] && BASH_BIN="$(command -v bash)"
fi
export BASH_BIN
REPORT_DIR="${REPO_ROOT}/.reports"
FAIL_FAST_ON_INFRA="${FAIL_FAST_ON_INFRA:-0}"

# ─── Parsing ───────────────────────────────────────────────────────────────
PASSTHROUGH=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --only)        ONLY="$2"; shift 2 ;;
    --skip)        SKIP="$2"; shift 2 ;;
    --no-continue) CONTINUE_ON_ERROR=0; shift ;;
    --fail-fast)   FAIL_FAST_ON_INFRA=1; shift ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--only "4"] [--skip "2 3"] [--no-continue] [--fail-fast] [<flags passés à chaque lot>]

Flags passés aux lots : --dry-run --yes --skip-tests --skip-push --verbose

Env :
  ONLY=4           n'exécuter que le lot 4
  SKIP="2 3"       sauter L2 et L3
  BASH_BIN         binaire bash à utiliser (défaut: bash)
  FAIL_FAST_ON_INFRA=1  stoppe net en cas d'échec infra (bash absent, script manquant)
EOF
      exit 0 ;;
    *) PASSTHROUGH+=("$1"); shift ;;
  esac
done

should_run() {
  local id="$1"
  [[ -n "${ONLY}" ]] && [[ " ${ONLY} " != *" ${id} "* ]] && return 1
  [[ -n "${SKIP}" ]] && [[ " ${SKIP} " == *" ${id} "* ]] && return 1
  return 0
}

# ─── Sanity bash ───────────────────────────────────────────────────────────
log_step "build-all — L1..L7"
bash_ver="$("$BASH_BIN" -c 'echo "${BASH_VERSION}"' 2>/dev/null || echo "?")"
log_dim "bash          : $(command -v "$BASH_BIN") ($bash_ver)"
log_dim "bash          : $(command -v "$BASH_BIN") ($("$BASH_BIN" --version | head -1))"
log_dim "ONLY=${ONLY:-<tous>}  SKIP=${SKIP:-<aucun>}  CONTINUE_ON_ERROR=${CONTINUE_ON_ERROR}"
log_dim "flags passés  : ${PASSTHROUGH[*]:-<aucun>}"


# ─── Exécution ─────────────────────────────────────────────────────────────
declare -a RESULTS=()
declare -a LOG_FILES=()
start_ts=$(date +%s)
mkdir -p "$REPORT_DIR"

run_one_lot() {
  local id="$1"
  local script="${LOTS_ROOT}/build-lot-${id}.sh"

  if [[ ! -f "${script}" ]]; then
    log_err "L${id} — script introuvable : ${script}"
    RESULTS+=("L${id}|MISSING|0s|")
    [[ "$FAIL_FAST_ON_INFRA" == "1" ]] && return 1
    return 0
  fi
  if [[ ! -x "${script}" ]]; then
    log_warn "L${id} — ${script} non exécutable, on force via bash"
  fi

  local t0 t1 rc
  local logf="${REPORT_DIR}/L${id}-$(date +%Y%m%d-%H%M%SZ).log"
  LOG_FILES+=("$logf")

  t0=$(date +%s)
  log_step "L${id} — début"
  log_dim "  script : ${script}"
  log_dim "  log    : ${logf}"

  # Force bash + tee la sortie (visible + archivée)
  set +e
  "$BASH_BIN" "${script}" "${PASSTHROUGH[@]}" 2>&1 | tee "$logf"
  rc=${PIPESTATUS[0]}
  set -e
  t1=$(date +%s)

  case "$rc" in
    0)
      RESULTS+=("L${id}|OK|$((t1-t0))s|${logf}")
      log_ok "L${id} terminé en $((t1-t0))s"
      ;;
    *)
      RESULTS+=("L${id}|FAIL(rc=${rc})|$((t1-t0))s|${logf}")
      log_err "L${id} échoué (rc=${rc}) après $((t1-t0))s"
      log_dim "  → dernières lignes du log :"
      tail_n 15 "$logf" | sed 's/^/    /' >&2
      [[ "$CONTINUE_ON_ERROR" == "1" ]] || return 1
      ;;
  esac
  return 0
}

for id in "${LOTS[@]}"; do
  if ! should_run "${id}"; then
    log_warn "L${id} — sauté"
    RESULTS+=("L${id}|SKIP|0s|")
    continue
  fi
  if ! run_one_lot "$id"; then
    log_err "arrêt sur échec (CONTINUE_ON_ERROR=0)"
    break
  fi
done

# ─── Rapport final ─────────────────────────────────────────────────────────
end_ts=$(date +%s)
log_step "Rapport final (total $((end_ts-start_ts))s)"

ok_count=0; fail_count=0; skip_count=0
for r in "${RESULTS[@]}"; do
  IFS='|' read -r lot status dur logf <<< "$r"
  case "$status" in
    OK)      ok_count=$((ok_count+1));  log_ok  "$(printf '%-4s %-14s %-6s %s' "$lot" "$status" "$dur" "$logf")" ;;
    SKIP)    skip_count=$((skip_count+1)); log_dim "$(printf '%-4s %-14s %-6s %s' "$lot" "$status" "$dur" "")" ;;
    MISSING) fail_count=$((fail_count+1)); log_err "$(printf '%-4s %-14s %-6s %s' "$lot" "$status" "$dur" "")" ;;
    *)       fail_count=$((fail_count+1)); log_err "$(printf '%-4s %-14s %-6s %s' "$lot" "$status" "$dur" "$logf")" ;;
  esac
done

# Rapport markdown agrégé
summary_file="${REPORT_DIR}/SUMMARY-$(date +%Y%m%d-%H%M%SZ).md"
{
  echo "# build-all — $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo ""
  echo "- OK    : $ok_count"
  echo "- FAIL  : $fail_count"
  echo "- SKIP  : $skip_count"
  echo "- Durée : $((end_ts-start_ts))s"
  echo ""
  echo "| Lot | Statut | Durée | Log |"
  echo "|-----|--------|-------|-----|"
  for r in "${RESULTS[@]}"; do
    IFS='|' read -r lot status dur logf <<< "$r"
    echo "| $lot | $status | $dur | ${logf:-—} |"
  done
} > "$summary_file"
log_dim "rapport agrégé → $summary_file"

if [[ $fail_count -gt 0 ]]; then
  log_err "$fail_count lot(s) en échec"
  exit 1
fi
log_ok "tous les lots demandés sont OK"
exit 0
