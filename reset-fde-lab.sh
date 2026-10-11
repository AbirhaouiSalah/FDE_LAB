#!/usr/bin/env bash
# reset-fde-lab.sh — Reset total du repo FDE_LAB
#
# Attention: ce script fait des opérations DESTRUCTIVES sur origin.
# Il exige une confirmation explicite et des sauvegardes préalables.
#
# Usage:
#   ./reset-fde-lab.sh --dry-run     # simulation
#   ./reset-fde-lab.sh --yes         # exécution
#   ./reset-fde-lab.sh --help

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

HEAD_BIN="/usr/bin/head"
[ -x "$HEAD_BIN" ] || HEAD_BIN="head"
head_n() { "$HEAD_BIN" -n "$1"; }

# ─── Options ───────────────────────────────────────────────────────────────
DRY_RUN=1
while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y)   DRY_RUN=0 ;;
    --dry-run)  DRY_RUN=1 ;;
    -h|--help)
      sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Argument inconnu: $1" >&2; exit 1 ;;
  esac
  shift
done

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_DIM=$'\033[2m';    C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_DIM=""; C_RST=""
fi
log()  { printf '%s[reset]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok   ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn ]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
err()  { printf '%s[err  ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; }
info() { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RST"; }
sep()  { printf '%s%s%s\n' "$C_DIM" "════════════════════════════════════════════════════════════════" "$C_RST"; }

# ─── Les 23 branches à recréer ─────────────────────────────────────────────
BRANCHES_TO_CREATE=(
  "ats-lab/chore/ci/frontend-pipeline"
  "ats-lab/comp/fairness/page"
  "ats-lab/comp/governance/page"
  "ats-lab/comp/operations/page"
  "ats-lab/comp/overview/page"
  "ats-lab/comp/pipeline/page"
  "ats-lab/comp/quality/page"
  "ats-lab/comp/queue/page"
  "ats-lab/comp/rubric/page"
  "ats-lab/comp/shell/app-shell"
  "ats-lab/comp/widgets/alert-panel"
  "ats-lab/comp/widgets/funnel-chart"
  "ats-lab/comp/widgets/gauge"
  "ats-lab/comp/widgets/heatmap"
  "ats-lab/comp/widgets/kpi-card"
  "ats-lab/comp/widgets/queue-table"
  "ats-lab/comp/widgets/small-group-guard"
  "ats-lab/comp/widgets/time-series"
  "ats-lab/docs/spec/dashboard"
  "ats-lab/feat/api/contracts"
  "ats-lab/feat/auth/rbac"
  "ats-lab/feat/i18n/fr-en"
  "ats-lab/feat/server/read-only-api"
  "ats-lab/main"
)

MODE_LABEL="[DRY-RUN]"
[ "$DRY_RUN" -eq 0 ] && MODE_LABEL="[EXECUTE]"

log "Mode: $MODE_LABEL"
log "Répertoire: $ROOT_DIR"

# ─── Vérifications préalables ──────────────────────────────────────────────
[ -d .git ] || { err "Pas dans un dépôt git (pas de .git)"; exit 1; }

log "Vérification des sauvegardes…"
BACKUP_COUNT=$(find ~ -maxdepth 1 -name "fde-lab-*-BACKUP-*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$BACKUP_COUNT" -eq 0 ]; then
  err "Aucune sauvegarde trouvée dans ~/"
  err "Fais d'abord:"
  err "  tar czf ~/fde-lab-FULL-BACKUP-\$(date +%Y%m%d-%H%M%S).tar.gz --exclude=node_modules --exclude=.git ALTEN-INTERNAL-ATS/"
  err "  git clone --bare . ~/fde-lab-repo-BACKUP-\$(date +%Y%m%d-%H%M%S).git"
  exit 1
fi
ok "$BACKUP_COUNT sauvegarde(s) trouvée(s) dans ~/"

# ─── Confirmation ─────────────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 0 ]; then
  echo ""
  warn "╔════════════════════════════════════════════════════════════════╗"
  warn "║  ⚠️  OPÉRATION DESTRUCTIVE SUR ORIGIN ⚠️                        ║"
  warn "╚════════════════════════════════════════════════════════════════╝"
  warn ""
  warn "Ce script va:"
  warn "  1. Reset main local sur origin/main"
  warn "  2. Supprimer les branches locales (ats-lab/*, backup/*, etc.)"
  warn "  3. Préparer un commit avec tout ALTEN-INTERNAL-ATS/"
  warn "  4. Push FORCÉ de main sur origin"
  warn "  5. Supprimer TOUTES les branches ats-lab/* et backup/* sur origin"
  warn "  6. Recréer les 23 branches ats-lab/* à partir du nouveau main"
  warn "  7. Supprimer le remote 'ats-local'"
  warn ""
  warn "Sauvegardes disponibles:"
  find ~ -maxdepth 1 -name "fde-lab-*-BACKUP-*" 2>/dev/null | sed 's/^/    /'
  warn ""
  printf 'Tape EXACTEMENT "reset-fde-lab" pour confirmer: '
  read -r confirmation
  if [ "$confirmation" != "reset-fde-lab" ]; then
    echo "Abort."
    exit 0
  fi
fi

# ─── 1. Fetch + reset main ─────────────────────────────────────────────────
sep
echo "  1. RESET MAIN LOCAL"
sep
log "Fetch origin…"
git fetch origin --prune
log "Reset main local sur origin/main…"
if [ "$DRY_RUN" -eq 0 ]; then
  git checkout main 2>/dev/null || git checkout -b main origin/main
  git reset --hard origin/main
  ok "main local = origin/main ($(git rev-parse --short HEAD))"
else
  info "  [dry-run] git reset --hard origin/main"
fi

# ─── 2. Nettoyage branches locales ────────────────────────────────────────
sep
echo "  2. NETTOYAGE BRANCHES LOCALES"
sep
LOCAL_BRANCHES=$(git branch --format='%(refname:short)' | grep -v '^main$' || true)
BRANCH_COUNT=$(echo "$LOCAL_BRANCHES" | grep -c . || echo 0)

if [ "$BRANCH_COUNT" -eq 0 ]; then
  ok "Aucune branche locale à supprimer"
else
  log "$BRANCH_COUNT branche(s) locale(s) à supprimer:"
  echo "$LOCAL_BRANCHES" | sed 's/^/  /'
  if [ "$DRY_RUN" -eq 0 ]; then
    echo "$LOCAL_BRANCHES" | while IFS= read -r b; do
      [ -z "$b" ] && continue
      git branch -D "$b" 2>/dev/null && ok "  supprimée: $b" || warn "  échec: $b"
    done
  fi
fi

# ─── 3. Préparer le commit ────────────────────────────────────────────────
sep
echo "  3. PRÉPARATION DU COMMIT"
sep
log "Ajout de tout ALTEN-INTERNAL-ATS/…"

if [ "$DRY_RUN" -eq 0 ]; then
  git add -A ALTEN-INTERNAL-ATS/
  if git diff --cached --quiet; then
    ok "Rien à commiter (working tree identique à origin/main)"
  else
    git -c user.name="AbirhaouiSalah" -c user.email="sabirhaouipro@gmail.com" \
        commit -m "chore: consolidate monorepo (Python + dashboard React)"
    ok "Commit créé: $(git rev-parse --short HEAD)"
  fi
else
  info "  [dry-run] git add -A ALTEN-INTERNAL-ATS/ && git commit -m '...'"
fi

# ─── 4. Push forcé sur main ───────────────────────────────────────────────
sep
echo "  4. PUSH FORCÉ MAIN"
sep
if [ "$DRY_RUN" -eq 0 ]; then
  log "Push forcé de main…"
  git push origin main --force-with-lease
  ok "main poussé sur origin"
else
  info "  [dry-run] git push origin main --force-with-lease"
fi

# ─── 5. Supprimer branches remote ats-lab/* et backup/* ──────────────────
sep
echo "  5. SUPPRESSION BRANCHES REMOTE"
sep
REMOTE_BRANCHES=()
while IFS= read -r b; do
  [ -n "$b" ] && REMOTE_BRANCHES+=("$b")
done < <(git ls-remote --heads origin 2>/dev/null \
         | awk -F'refs/heads/' '{print $2}' \
         | grep -E '^(ats-lab/|backup/)' \
         | sort -u)

if [ "${#REMOTE_BRANCHES[@]}" -eq 0 ]; then
  ok "Aucune branche remote à supprimer"
else
  log "${#REMOTE_BRANCHES[@]} branche(s) remote à supprimer:"
  for b in "${REMOTE_BRANCHES[@]}"; do
    echo "  origin/$b"
  done
  if [ "$DRY_RUN" -eq 0 ]; then
    for b in "${REMOTE_BRANCHES[@]}"; do
      git push origin --delete "$b" 2>&1 | tail_n 1 || warn "  échec: $b"
    done
    ok "Branches remote supprimées"
  fi
fi

# ─── 6. Recréer les branches ats-lab/* ────────────────────────────────────
sep
echo "  6. RECRÉATION DES 23 BRANCHES ats-lab/*"
sep
if [ "$DRY_RUN" -eq 0 ]; then
  for b in "${BRANCHES_TO_CREATE[@]}"; do
    git push origin "main:refs/heads/$b" >/dev/null 2>&1 \
      && ok "  créée: $b" \
      || warn "  échec: $b"
  done
else
  info "  [dry-run] aurait créé ${#BRANCHES_TO_CREATE[@]} branches:"
  for b in "${BRANCHES_TO_CREATE[@]}"; do
    echo "    - $b"
  done
fi

# ─── 7. Supprimer le remote ats-local ─────────────────────────────────────
sep
echo "  7. SUPPRESSION DU REMOTE ats-local"
sep
if git remote | grep -q '^ats-local$'; then
  if [ "$DRY_RUN" -eq 0 ]; then
    git remote remove ats-local
    ok "Remote 'ats-local' supprimé"
  else
    info "  [dry-run] git remote remove ats-local"
  fi
else
  ok "Remote 'ats-local' déjà absent"
fi

# ─── Résumé ────────────────────────────────────────────────────────────────
sep
echo "  RÉSUMÉ"
sep
echo ""
if [ "$DRY_RUN" -eq 1 ]; then
  warn "DRY-RUN — aucune modification effectuée"
  info ""
  info "Pour exécuter:"
  info "  ./reset-fde-lab.sh --yes"
else
  ok "Reset terminé"
  info ""
  info "Vérifie:"
  info "  git log --oneline -5"
  info "  git ls-remote --heads origin | wc -l"
fi
sep