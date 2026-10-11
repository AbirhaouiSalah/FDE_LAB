#!/usr/bin/env bash
# scripts/merge-all-into-main.sh (v1)
#
# Merge toutes les branches ats-lab/* dans main.
#
# Approche:
#   1. Pour chaque branche ats-lab/*
#   2. Calculer les commits uniques (non-CI)
#   3. Si 0 → skip
#   4. Sinon → git merge --no-ff --allow-unrelated-histories -X ours
#      (résolution auto en faveur de main pour les conflits)
#   5. Push main à la fin
#
# Usage:
#   ./scripts/merge-all-into-main.sh                    # dry-run (défaut)
#   ./scripts/merge-all-into-main.sh --yes              # exécute
#   ./scripts/merge-all-into-main.sh --strategy ours    # défaut: garder main
#   ./scripts/merge-all-into-main.sh --strategy theirs  # garder la branche
#   ./scripts/merge-all-into-main.sh --keep-ci          # ne pas filtrer les commits CI
#   ./scripts/merge-all-into-main.sh --target develop   # cible alternative (défaut: main)
#   ./scripts/merge-all-into-main.sh --help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

HEAD_BIN="/usr/bin/head"
[ -x "$HEAD_BIN" ] || HEAD_BIN="head"
head_n() { "$HEAD_BIN" -n "$1"; }

GIT_NAME="AbirhaouiSalah"
GIT_EMAIL="sabirhaouipro@gmail.com"

# ─── Options ───────────────────────────────────────────────────────────────
DRY_RUN=1
STRATEGY="ours"
FILTER_CI=1
TARGET_BRANCH="main"

while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y)         DRY_RUN=0 ;;
    --dry-run)        DRY_RUN=1 ;;
    --strategy)       shift; STRATEGY="${1:?--strategy requiert ours|theirs}" ;;
    --keep-ci)        FILTER_CI=0 ;;
    --target)         shift; TARGET_BRANCH="${1:?--target requiert une branche}" ;;
    -h|--help)
      sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) printf 'Argument inconnu: %s\n' "$1" >&2; exit 1 ;;
  esac
  shift
done

case "$STRATEGY" in
  ours|theirs) ;;
  *) printf 'Stratégie invalide: %s (attendu: ours|theirs)\n' "$STRATEGY" >&2; exit 1 ;;
esac

# ─── Couleurs ──────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_CYA=$'\033[0;36m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_CYA=""; C_DIM=""; C_RST=""
fi
log()  { printf '%s[merge]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok   ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn ]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
err()  { printf '%s[err  ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; }
info() { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RST"; }
sep()  { printf '%s%s%s\n' "$C_DIM" "════════════════════════════════════════════════════════════════" "$C_RST"; }
sub()  { printf '%s%s%s\n' "$C_DIM" "────────────────────────────────────────────────────────────────" "$C_RST"; }

# ─── Préflight ─────────────────────────────────────────────────────────────
[ -d .git ] || { err "Pas dans un dépôt git"; exit 1; }

if [ -n "$(git status --porcelain)" ]; then
  err "Working tree non propre. Commit ou stash d'abord."
  git status --short 2>/dev/null | head_n 20
  exit 1
fi

git rev-parse --verify "$TARGET_BRANCH" >/dev/null 2>&1 \
  || { err "Branche cible '$TARGET_BRANCH' introuvable"; exit 1; }

MODE_LABEL="[DRY-RUN]"
[ "$DRY_RUN" -eq 0 ] && MODE_LABEL="[EXECUTE]"

log "Mode: $MODE_LABEL"
log "Stratégie: -X $STRATEGY"
log "Cible: $TARGET_BRANCH"
if [ "$FILTER_CI" -eq 1 ]; then
  log "Filtrage des commits CI: ACTIVÉ"
else
  log "Filtrage des commits CI: désactivé"
fi

# ─── Fetch ─────────────────────────────────────────────────────────────────
log "Fetch origin…"
git fetch origin --prune 2>/dev/null || { err "Fetch échoué"; exit 1; }

# ─── Se placer sur la cible ────────────────────────────────────────────────
CURRENT_BRANCH="$(git branch --show-current)"
if [ "$CURRENT_BRANCH" != "$TARGET_BRANCH" ]; then
  log "Bascule sur $TARGET_BRANCH…"
  if [ "$DRY_RUN" -eq 1 ]; then
    info "  [dry-run] git checkout $TARGET_BRANCH"
  else
    git checkout "$TARGET_BRANCH" >/dev/null 2>&1 || { err "checkout $TARGET_BRANCH impossible"; exit 1; }
  fi
fi

# ─── Backup ────────────────────────────────────────────────────────────────
BACKUP="backup/pre-merge-all-$(date +%Y%m%d-%H%M%S)"
if [ "$DRY_RUN" -eq 0 ]; then
  git branch "$BACKUP" "$TARGET_BRANCH" 2>/dev/null || true
  git push origin "$BACKUP" >/dev/null 2>&1 && ok "Backup: origin/$BACKUP" || warn "Backup échouée"
else
  info "  [dry-run] aurait créé backup/$BACKUP"
fi

# ─── Liste des branches ────────────────────────────────────────────────────
BRANCHES=()
while IFS= read -r b; do
  [ -n "$b" ] && BRANCHES+=("$b")
done < <(git ls-remote --heads origin 'refs/heads/ats-lab/*' \
         | awk -F'refs/heads/' '{print $2}' | sort -u)

TOTAL="${#BRANCHES[@]}"
[ "$TOTAL" -eq 0 ] && { err "Aucune branche ats-lab/* trouvée"; exit 1; }

log "Branches à considérer: $TOTAL"

# ─── Analyse préliminaire ──────────────────────────────────────────────────
sep
echo "  ANALYSE PRÉLIMINAIRE"
sep
echo ""

printf '%-45s %10s %s\n' "BRANCHE" "UNIQUES" "STATUT"
sub

PLAN_MERGE=()
PLAN_SKIP=()

for b in "${BRANCHES[@]}"; do
  [ "$b" = "ats-lab/main" ] && continue

  if ! git rev-parse --verify "origin/$b" >/dev/null 2>&1; then
    printf '%-45s %10s %s\n' "$b" "?" "introuvable"
    continue
  fi

  if [ "$FILTER_CI" -eq 1 ]; then
    UNIQUE=$(git log "$TARGET_BRANCH..origin/$b" --oneline 2>/dev/null \
             | grep -v -E "ci: report|ci: sync|chore\(sync\)|merge: sync|\[skip ci\]" \
             | wc -l | tr -d ' ')
  else
    UNIQUE=$(git rev-list --count "$TARGET_BRANCH..origin/$b" 2>/dev/null || echo "0")
  fi

  if [ "$UNIQUE" -eq 0 ]; then
    printf '%-45s %10s %s\n' "$b" "$UNIQUE" "à skip"
    PLAN_SKIP+=("$b")
  else
    printf '%-45s %10s %s\n' "$b" "$UNIQUE" "à merger"
    PLAN_MERGE+=("$b")
  fi
done

echo ""
log "${#PLAN_MERGE[@]} branche(s) à merger, ${#PLAN_SKIP[@]} à skip"
echo ""

# ─── Confirmation ─────────────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 0 ] && [ "${#PLAN_MERGE[@]}" -gt 0 ]; then
  warn "Merger ${#PLAN_MERGE[@]} branche(s) dans $TARGET_BRANCH ?"
  warn "Stratégie: -X $STRATEGY"
  printf '\nContinuer ? [y/N] '
  read -r ans
  [ "${ans:-N}" = "y" ] || [ "${ans:-N}" = "Y" ] || { echo "Abort."; exit 0; }
fi

# ─── Merge ─────────────────────────────────────────────────────────────────
sep
echo "  MERGE"
sep
echo ""

M_MERGED=0; M_FAILED=0
FAILED_LIST=()

for b in "${PLAN_MERGE[@]+"${PLAN_MERGE[@]}"}"; do
  echo ""
  log "▶ $b"

  if [ "$DRY_RUN" -eq 1 ]; then
    log "  [dry-run] git merge -X $STRATEGY origin/$b"
    continue
  fi

  if git -c user.name="$GIT_NAME" -c user.email="$GIT_EMAIL" \
      merge --no-ff --allow-unrelated-histories -X "$STRATEGY" \
      -m "merge: sync $b into $TARGET_BRANCH [skip ci]" \
      "origin/$b" >/dev/null 2>&1; then
    ok "  mergé"
    M_MERGED=$((M_MERGED+1))
  else
    warn "  conflit → abort"
    git merge --abort 2>/dev/null || true
    M_FAILED=$((M_FAILED+1)); FAILED_LIST+=("$b")
  fi
done

# ─── Push final ────────────────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 0 ] && [ "$M_MERGED" -gt 0 ]; then
  echo ""
  log "Push final de $TARGET_BRANCH…"
  git push origin "$TARGET_BRANCH" && ok "poussé" || warn "push échoué"
fi

# ─── Résumé ────────────────────────────────────────────────────────────────
echo ""
sep
echo "  RÉSUMÉ"
sep
echo ""
printf '  ✅ %d mergées\n' "$M_MERGED"
printf '  ⏭  %d sans commits utiles\n' "${#PLAN_SKIP[@]}"
printf '  ❌ %d échecs\n' "$M_FAILED"

if [ "${#FAILED_LIST[@]}" -gt 0 ]; then
  echo ""
  printf '  Échecs:\n'
  for f in "${FAILED_LIST[@]}"; do
    printf '    - %s\n' "$f"
  done
fi

if [ "$DRY_RUN" -eq 0 ] && [ "$M_MERGED" -gt 0 ]; then
  echo ""
  ok "Backup disponible: origin/$BACKUP"
fi

# ─── Retour à la branche initiale ─────────────────────────────────────────
if [ "$DRY_RUN" -eq 0 ] && [ "$CURRENT_BRANCH" != "$(git branch --show-current)" ]; then
  log "Retour sur $CURRENT_BRANCH…"
  git checkout "$CURRENT_BRANCH" >/dev/null 2>&1 || true
fi

echo ""