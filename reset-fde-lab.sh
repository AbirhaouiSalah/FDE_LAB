#!/usr/bin/env bash
# reset-fde-lab.sh (v3) — Reset complet du repo FDE_LAB
#
# Consolide le monorepo (Python + dashboard React), reset main,
# supprime/recrée les branches ats-lab/*, avec diagnostics automatiques.
#
# Usage:
#   ./reset-fde-lab.sh                # dry-run (défaut)
#   ./reset-fde-lab.sh --yes          # exécution
#   ./reset-fde-lab.sh --help

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

HEAD_BIN="/usr/bin/head"
[ -x "$HEAD_BIN" ] || HEAD_BIN="head"
head_n() { "$HEAD_BIN" -n "$1"; }
TAIL_BIN="/usr/bin/tail"
[ -x "$TAIL_BIN" ] || TAIL_BIN="tail"

# ─── Options ───────────────────────────────────────────────────────────────
DRY_RUN=1
while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y)   DRY_RUN=0 ;;
    --dry-run)  DRY_RUN=1 ;;
    -h|--help)  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Argument inconnu: $1" >&2; exit 1 ;;
  esac
  shift
done

# ─── Couleurs ──────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_CYA=$'\033[0;36m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_CYA=""; C_DIM=""; C_RST=""
fi
log()  { printf '%s[reset]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok   ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn ]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
err()  { printf '%s[err  ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; }
info() { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RST"; }
sep()  { printf '%s%s%s\n' "$C_DIM" "════════════════════════════════════════════════════════════════" "$C_RST"; }

# ─── Branches à créer ──────────────────────────────────────────────────────
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

# ─── Diagnostic ────────────────────────────────────────────────────────────
diagnose() {
  echo ""
  sep
  err "DIAGNOSTIC COMPLET"
  sep
  echo ""

  echo "▶ Branche courante:"
  git branch --show-current 2>/dev/null || echo "  (déconnecté)"
  echo ""

  echo "▶ Derniers commits:"
  git log --oneline -5 2>/dev/null || echo "  (impossible)"
  echo ""

  echo "▶ Git status (résumé chiffré):"
  git status --porcelain 2>/dev/null | wc -l | tr -d ' ' | sed 's/^/  Total: /'
  echo "  Staged :"
  git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ' | sed 's/^/    /'
  echo "  Untracked :"
  git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ' | sed 's/^/    /'
  echo ""

  echo "▶ Remotes:"
  git remote -v 2>/dev/null | sed 's/^/  /' || echo "  (impossible)"
  echo ""

  echo "▶ Branches locales:"
  git branch --list 2>/dev/null | head_n 30 | sed 's/^/  /' || echo "  (impossible)"
  echo ""

  echo "▶ Worktrees:"
  git worktree list 2>/dev/null | sed 's/^/  /' || echo "  (impossible)"
  echo ""

  echo "▶ Structure:"
  [ -d ".git" ] && echo "  .git racine       : ✅ PRÉSENT" || echo "  .git racine       : ❌ ABSENT"
  [ -d "ALTEN-INTERNAL-ATS/ats-copilot-dashboard/.git" ] && echo "  .git imbriqué     : ⚠️  PRÉSENT" || echo "  .git imbriqué     : ✅ absent"
  [ -f ".gitignore" ] && echo "  .gitignore racine : ✅ PRÉSENT ($(wc -l < .gitignore | tr -d ' ') lignes)" || echo "  .gitignore racine : ❌ ABSENT"
  echo ""

  echo "▶ Taille ALTEN-INTERNAL-ATS/:"
  du -sh ALTEN-INTERNAL-ATS/ 2>/dev/null | sed 's/^/  /' || echo "  (impossible)"
  echo ""

  echo "▶ Sauvegardes:"
  ls -lh ~/fde-lab-*-BACKUP-* 2>/dev/null | head_n 10 | sed 's/^/  /' || echo "  (aucune)"
  echo ""
}

trap_on_error() {
  local exit_code=$?
  echo ""
  err "╔════════════════════════════════════════════════════════════════╗"
  err "║  ⚠️  ERREUR (exit: $exit_code)                                   ║"
  err "╚════════════════════════════════════════════════════════════════╝"
  diagnose
  err "Restauration possible:"
  err "  git reset --hard origin/main"
  err "  tar xzf ~/fde-lab-FULL-BACKUP-*.tar.gz"
  echo ""
  exit $exit_code
}
trap trap_on_error ERR

# ─── Main ──────────────────────────────────────────────────────────────────
MODE_LABEL="[DRY-RUN]"
[ "$DRY_RUN" -eq 0 ] && MODE_LABEL="[EXECUTE]"

log "Mode: $MODE_LABEL"
log "Répertoire: $ROOT_DIR"

[ -d .git ] || { err "Pas dans un dépôt git"; exit 1; }

# ─── Sauvegardes ──────────────────────────────────────────────────────────
log "Vérification des sauvegardes…"
BACKUP_COUNT=$(find ~ -maxdepth 1 -name "fde-lab-*-BACKUP-*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$BACKUP_COUNT" -eq 0 ]; then
  err "Aucune sauvegarde trouvée. Fais d'abord:"
  err "  tar czf ~/fde-lab-FULL-BACKUP-\$(date +%Y%m%d-%H%M%S).tar.gz --exclude=node_modules --exclude=.git ALTEN-INTERNAL-ATS/"
  err "  git clone --bare . ~/fde-lab-repo-BACKUP-\$(date +%Y%m%d-%H%M%S).git"
  exit 1
fi
ok "$BACKUP_COUNT sauvegarde(s) trouvée(s)"

# ─── ANALYSE PRÉALABLE (crucial !) ─────────────────────────────────────────
sep
echo "  ANALYSE PRÉALABLE"
sep
echo ""

STAGED_COUNT=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
UNTRACKED_COUNT=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
DELETED_COUNT=$(git ls-files --deleted 2>/dev/null | wc -l | tr -d ' ')
MODIFIED_COUNT=$(git ls-files --modified 2>/dev/null | wc -l | tr -d ' ')

echo "État de l'index git:"
echo "  Fichiers stagés     : $STAGED_COUNT"
echo "  Fichiers untracked  : $UNTRACKED_COUNT"
echo "  Fichiers supprimés  : $DELETED_COUNT"
echo "  Fichiers modifiés   : $MODIFIED_COUNT"
echo ""

echo "Contenu ALTEN-INTERNAL-ATS/:"
AT_FILES=$(find ALTEN-INTERNAL-ATS/ -type f \
  -not -path '*/node_modules/*' \
  -not -path '*/.git/*' \
  -not -path '*/__pycache__/*' \
  -not -path '*/dist/*' \
  -not -path '*/coverage/*' \
  2>/dev/null | wc -l | tr -d ' ')
echo "  Fichiers (hors node_modules/.git/__pycache__) : $AT_FILES"
echo ""

# ─── Décision ─────────────────────────────────────────────────────────────
NEED_RESET_INDEX=0
if [ "$STAGED_COUNT" -gt 0 ] && [ "$UNTRACKED_COUNT" -eq 0 ]; then
  warn "⚠️  Des fichiers sont DÉJÀ stagés ($STAGED_COUNT) — probable `git add` précédent"
  warn "   → Il faut reset l'index avant de continuer"
  NEED_RESET_INDEX=1
fi

if [ "$AT_FILES" -eq 0 ]; then
  err "ALTEN-INTERNAL-ATS/ est vide ou introuvable"
  exit 1
fi

if [ "$UNTRACKED_COUNT" -eq 0 ] && [ "$STAGED_COUNT" -eq 0 ] && [ "$DELETED_COUNT" -eq 0 ]; then
  err "Rien à commiter — working tree identique à HEAD"
  err "Si tu as fait un `git add` avant, reset l'index :"
  err "  git reset HEAD ."
  exit 1
fi

echo "Résumé:"
echo "  Fichiers dans ALTEN-INTERNAL-ATS/ : $AT_FILES"
echo "  À stager après reset              : $(($AT_FILES + $DELETED_COUNT))"
echo ""

# ─── Confirmation ─────────────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 0 ]; then
  echo ""
  warn "⚠️  OPÉRATION DESTRUCTIVE"
  warn "  1. Reset de l'index git (si nécessaire)"
  warn "  2. Backup + suppression du .git imbriqué (si présent)"
  warn "  3. Vérification/création .gitignore racine"
  warn "  4. Reset main local sur origin/main"
  warn "  5. Suppression des branches locales"
  warn "  6. git add -A (tout) + commit"
  warn "  7. Push FORCÉ de main"
  warn "  8. Suppression TOUTES les branches ats-lab/* et backup/* sur origin"
  warn "  9. Recréation des 24 branches"
  warn "  10. Suppression du remote ats-local"
  warn ""
  printf 'Tape "reset-fde-lab" pour confirmer: '
  read -r confirmation
  [ "$confirmation" = "reset-fde-lab" ] || { echo "Abort."; exit 0; }
fi

# ─── Étape 1: Reset de l'index si nécessaire ──────────────────────────────
if [ "$NEED_RESET_INDEX" -eq 1 ]; then
  sep
  echo "  1. RESET DE L'INDEX GIT"
  sep
  if [ "$DRY_RUN" -eq 0 ]; then
    git reset HEAD . >/dev/null 2>&1 || true
    NEW_STAGED=$(git diff --cached --name-only | wc -l | tr -d ' ')
    ok "Index reset (stagés: $NEW_STAGED)"
  else
    info "  [dry-run] git reset HEAD ."
  fi
fi

# ─── Étape 2: Backup + suppression .git imbriqué ──────────────────────────
sep
echo "  2. .GIT IMBRIQUÉ (dashboard)"
sep
if [ -d "ALTEN-INTERNAL-ATS/ats-copilot-dashboard/.git" ]; then
  BACKUP_NAME="$HOME/ats-copilot-dashboard-REPO-BACKUP-$(date +%Y%m%d-%H%M%S).git"
  if [ "$DRY_RUN" -eq 0 ]; then
    git clone --bare ALTEN-INTERNAL-ATS/ats-copilot-dashboard "$BACKUP_NAME" >/dev/null 2>&1 || true
    ok "Backup: $BACKUP_NAME"
    rm -rf ALTEN-INTERNAL-ATS/ats-copilot-dashboard/.git
    ok ".git imbriqué supprimé"
  else
    info "  [dry-run] backup + rm -rf ALTEN-INTERNAL-ATS/ats-copilot-dashboard/.git"
  fi
else
  ok "Pas de .git imbriqué"
fi

# ─── Étape 3: .gitignore racine ───────────────────────────────────────────
sep
echo "  3. .GITIGNORE RACINE"
sep
if [ ! -f ".gitignore" ]; then
  if [ "$DRY_RUN" -eq 0 ]; then
    cat > .gitignore <<'EOF_GITIGNORE'
node_modules/
dist/
coverage/
.vite/
*.log
.pnpm-store/
.env
.env.*
!.env.example
.DS_Store
._*
playwright-report/
test-results/
storybook-static/
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/
.venv/
.pytest_cache/
.mypy_cache/
.ruff_cache/
*.egg-info/
.idea/
.vscode/
*.swp
*.swo
*.bak
*.orig
*.rej
.ci-reports/
.sync-worktrees/
.align-worktrees/
.push-worktrees/
.modify-worktrees/
EOF_GITIGNORE
    ok ".gitignore créé"
  else
    info "  [dry-run] création .gitignore"
  fi
else
  ok ".gitignore existe déjà"
fi

# ─── Étape 4: Reset main local ────────────────────────────────────────────
sep
echo "  4. RESET MAIN LOCAL"
sep
if [ "$DRY_RUN" -eq 0 ]; then
  log "Fetch origin…"
  git fetch origin --prune
  git checkout main 2>/dev/null || git checkout -b main origin/main
  git reset --hard origin/main >/dev/null 2>&1
  ok "main local = origin/main ($(git rev-parse --short HEAD))"
else
  info "  [dry-run] git fetch && reset --hard origin/main"
fi

# ─── Étape 5: Nettoyage branches locales ──────────────────────────────────
sep
echo "  5. NETTOYAGE BRANCHES LOCALES"
sep
LOCAL_BRANCHES="$(git branch --format='%(refname:short)' 2>/dev/null | grep -v '^main$' || true)"
if [ -z "$LOCAL_BRANCHES" ]; then
  ok "Aucune branche locale à supprimer"
else
  COUNT=$(printf '%s\n' "$LOCAL_BRANCHES" | grep -c . || echo 0)
  log "$COUNT branche(s) à supprimer"
  if [ "$DRY_RUN" -eq 0 ]; then
    printf '%s\n' "$LOCAL_BRANCHES" | while IFS= read -r b; do
      [ -z "$b" ] && continue
      git branch -D "$b" >/dev/null 2>&1 && ok "  supprimée: $b" || warn "  échec: $b"
    done
  else
    printf '%s\n' "$LOCAL_BRANCHES" | sed 's/^/  /'
  fi
fi

# ─── Étape 6: git add + commit ────────────────────────────────────────────
sep
echo "  6. GIT ADD + COMMIT"
sep
if [ "$DRY_RUN" -eq 0 ]; then
  log "git add -A ."
  git add -A .

  STAGED_AFTER=$(git diff --cached --name-only | wc -l | tr -d ' ')
  log "$STAGED_AFTER fichier(s) stagé(s)"

  if [ "$STAGED_AFTER" -eq 0 ]; then
    err "Aucun fichier stagé — rien à commiter"
    diagnose
    exit 1
  fi

  # Vérification: pas de node_modules dans le commit
  NM_STAGED=$(git diff --cached --name-only | grep -c node_modules || echo 0)
  if [ "$NM_STAGED" -gt 0 ]; then
    err "$NM_STAGED fichiers node_modules stagés — .gitignore défaillant"
    err "Reset l'index et corrige le .gitignore:"
    err "  git reset HEAD ."
    exit 1
  fi
  ok "Pas de node_modules dans l'index"

  git -c user.name="AbirhaouiSalah" -c user.email="sabirhaouipro@gmail.com" \
      commit -m "chore: consolidate monorepo (Python + dashboard React integrated)"
  ok "Commit: $(git rev-parse --short HEAD)"
else
  info "  [dry-run] git add -A . && commit"
  # Estimation
  ESTIMATED=$(find . -type f \
    -not -path './node_modules/*' \
    -not -path './.git/*' \
    -not -path '*/node_modules/*' \
    -not -path '*/.git/*' \
    -not -path '*/__pycache__/*' \
    -not -path '*/dist/*' \
    -not -path '*/coverage/*' \
    2>/dev/null | wc -l | tr -d ' ')
  info "  Fichiers qui seraient ajoutés (approx.): $ESTIMATED"
fi

# ─── Étape 7: Push forcé ──────────────────────────────────────────────────
sep
echo "  7. PUSH FORCÉ MAIN"
sep
if [ "$DRY_RUN" -eq 0 ]; then
  git push origin main --force-with-lease
  ok "main poussé"
else
  info "  [dry-run] git push origin main --force-with-lease"
fi

# ─── Étape 8: Suppression branches remote ────────────────────────────────
sep
echo "  8. SUPPRESSION BRANCHES REMOTE"
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
  log "${#REMOTE_BRANCHES[@]} branche(s) à supprimer"
  if [ "$DRY_RUN" -eq 0 ]; then
    for b in "${REMOTE_BRANCHES[@]}"; do
      git push origin --delete "$b" >/dev/null 2>&1 \
        && ok "  supprimée: $b" \
        || warn "  échec: $b"
    done
  else
    for b in "${REMOTE_BRANCHES[@]}"; do echo "  origin/$b"; done
  fi
fi

# ─── Étape 9: Recréation branches ────────────────────────────────────────
sep
echo "  9. RECRÉATION BRANCHES ats-lab/*"
sep
if [ "$DRY_RUN" -eq 0 ]; then
  for b in "${BRANCHES_TO_CREATE[@]}"; do
    git push origin "main:refs/heads/$b" >/dev/null 2>&1 \
      && ok "  créée: $b" \
      || warn "  échec: $b"
  done
else
  info "  [dry-run] créer ${#BRANCHES_TO_CREATE[@]} branches"
  for b in "${BRANCHES_TO_CREATE[@]}"; do echo "  $b"; done
fi

# ─── Étape 10: Suppression remote ats-local ──────────────────────────────
sep
echo "  10. SUPPRESSION REMOTE ats-local"
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
if [ "$DRY_RUN" -eq 1 ]; then
  warn "DRY-RUN — aucune modification effectuée"
  info ""
  info "Pour exécuter: ./reset-fde-lab.sh --yes"
else
  ok "Reset terminé avec succès"
  info ""
  info "Vérifications:"
  info "  git log --oneline -5"
  info "  git ls-remote --heads origin | wc -l"
  info "  ls -la ALTEN-INTERNAL-ATS/ats-copilot-dashboard/"
fi
sep