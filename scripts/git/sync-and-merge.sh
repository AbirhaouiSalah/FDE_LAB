#!/usr/bin/env bash
# scripts/sync-all-branches-and-merge.sh (v4)
#
# Synchronise les branches ats-lab/* avec main:
#   Phase 1: propage la toolchain de main vers chaque branche
#   Phase 2: merge chaque branche dans main si elle a des commits uniques
#
# Approche: git worktree + branche temporaire unique par worktree
#
# Usage:
#   ./scripts/sync-all-branches-and-merge.sh [OPTIONS]
#
# Options:
#   --dry-run       Simule, ne pousse rien
#   --yes, -y       Pas de confirmation interactive
#   --no-merge      Phase 1 uniquement
#   --only-merge    Phase 2 uniquement
#   --source <b>    Branche source (défaut: main)
#   -h, --help      Aide

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT_DIR"

FILES=(
  "scripts/run.sh"
  ".npmrc"
  "package.json"
  "pnpm-lock.yaml"
  "index.html"
  "tsconfig.json"
  "vite.config.ts"
  "vitest.config.ts"
  "vitest.setup.ts"
  "eslint.config.js"
  "src/vite-env.d.ts"
  "src/app/main.tsx"
  ".github/workflows/dashboard-ci.yml"
)

GIT_NAME="AbirhaouiSalah"
GIT_EMAIL="sabirhaouipro@gmail.com"

DRY_RUN=0
ASSUME_YES=0
SKIP_PROPAGATE=0
SKIP_MERGE=0
SOURCE_BRANCH="main"

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)    DRY_RUN=1 ;;
    --yes|-y)     ASSUME_YES=1 ;;
    --no-merge)   SKIP_MERGE=1 ;;
    --only-merge) SKIP_PROPAGATE=1 ;;
    --source)     shift; SOURCE_BRANCH="${1:?--source requiert une valeur}" ;;
    -h|--help)    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'Argument inconnu: %s\n' "$1" >&2; exit 1 ;;
  esac
  shift
done

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_CYA=$'\033[0;36m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_CYA=""; C_DIM=""; C_RST=""
fi
log()  { printf '%s[sync]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok  ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
err()  { printf '%s[err ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; }
die()  { err "$@"; exit 1; }
sep()  { printf '%s%s%s\n' "$C_DIM" "════════════════════════════════════════════════════════════════" "$C_RST"; }

[ -d .git ] || die "Pas dans un dépôt git"
[ -n "$(git status --porcelain)" ] && die "Working tree non propre"

git rev-parse --verify "$SOURCE_BRANCH" >/dev/null 2>&1 \
  || die "Branche source '$SOURCE_BRANCH' introuvable"

log "Fetch origin…"
git fetch origin --prune 2>/dev/null || die "Fetch échoué"

BRANCHES=()
while IFS= read -r b; do
  [ -n "$b" ] && BRANCHES+=("$b")
done < <(git ls-remote --heads origin 'refs/heads/ats-lab/*' \
         | awk -F'refs/heads/' '{print $2}' | sort -u)

TOTAL="${#BRANCHES[@]}"
[ "$TOTAL" -eq 0 ] && die "Aucune branche ats-lab/* détectée"
log "Branches détectées: $TOTAL"

# Backup
BACKUP="backup/pre-merge-$(date +%Y%m%d-%H%M%S)"
if [ "$DRY_RUN" -eq 0 ]; then
  git branch "$BACKUP" "$SOURCE_BRANCH" 2>/dev/null || true
  git push origin "$BACKUP" >/dev/null 2>&1 && ok "Backup: origin/$BACKUP" || warn "Backup échouée"
fi

if [ "$DRY_RUN" -eq 0 ] && [ "$ASSUME_YES" -eq 0 ]; then
  printf '\n'
  warn "Propagation $SOURCE_BRANCH → $TOTAL branches"
  [ "$SKIP_MERGE" -eq 0 ] && warn "Puis merge retour dans $SOURCE_BRANCH"
  printf '\nContinuer ? [y/N] '
  read -r ans
  [ "${ans:-N}" = "y" ] || [ "${ans:-N}" = "Y" ] || { echo "Abort."; exit 0; }
fi

# Worktrees
WORKTREE_BASE=".sync-worktrees"
mkdir -p "$WORKTREE_BASE"

cleanup_worktrees() {
  if [ -d "$WORKTREE_BASE" ]; then
    for d in "$WORKTREE_BASE"/*; do
      [ -d "$d" ] || continue
      git worktree remove --force "$d" 2>/dev/null || rm -rf "$d"
    done
    rm -rf "$WORKTREE_BASE"
  fi
}
trap cleanup_worktrees EXIT

# ─── PHASE 1: PROPAGATION ─────────────────────────────────────────────────
P_PUSHED=0; P_SKIP=0; P_FAILED=0
FAILED_LIST=()

if [ "$SKIP_PROPAGATE" -eq 0 ]; then
  echo ""
  sep
  log "PHASE 1: Propagation → $TOTAL branches"
  sep

  for b in "${BRANCHES[@]}"; do
    [ "$b" = "ats-lab/main" ] && { log "  skip ats-lab/main"; continue; }

    SAFE="${b//\//_}"
    WT="$WORKTREE_BASE/$SAFE"
    TMP_BRANCH="sync-tmp-$$-$SAFE"

    echo ""
    log "▶ $b"

    # Créer un worktree DÉTACHÉ (pas de branche locale)
    if ! git worktree add --detach "$WT" "origin/$b" >/dev/null 2>&1; then
      warn "  worktree add échoué"
      P_FAILED=$((P_FAILED+1)); FAILED_LIST+=("$b (worktree)"); continue
    fi

    # Copier les fichiers
    COPIED=0
    for f in "${FILES[@]}"; do
      SRC="$(git show "$SOURCE_BRANCH:$f" 2>/dev/null || echo "")"
      [ -z "$SRC" ] && continue

      TARGET="$WT/$f"
      mkdir -p "$(dirname "$TARGET")"

      if [ -f "$TARGET" ] && cmp -s <(printf '%s' "$SRC") "$TARGET"; then
        continue
      fi

      printf '%s' "$SRC" > "$TARGET"
      COPIED=$((COPIED+1))
    done

    if [ "$COPIED" -eq 0 ]; then
      log "  ⏭ déjà à jour (0 fichier à copier)"
      P_SKIP=$((P_SKIP+1))
      git worktree remove --force "$WT" 2>/dev/null || rm -rf "$WT"
      continue
    fi

    log "  $COPIED fichier(s) à propager"

    if [ "$DRY_RUN" -eq 1 ]; then
      log "  [dry-run] skip commit+push"
      git worktree remove --force "$WT" 2>/dev/null || rm -rf "$WT"
      continue
    fi

    # Commit + push dans le worktree
    (
      cd "$WT" || exit 1

      # Créer une branche temporaire UNIQUE (jamais utilisée ailleurs)
      git checkout -b "$TMP_BRANCH" || exit 1

      # Add + commit
      git add "${FILES[@]}" || exit 1

      if ! git -c user.name="$GIT_NAME" -c user.email="$GIT_EMAIL" \
           commit -m "chore(sync): propagate toolchain from $SOURCE_BRANCH [skip ci]" >/dev/null; then
        echo "COMMIT_FAILED" >&2
        exit 2
      fi

      LOCAL_SHA="$(git rev-parse HEAD)"

      # Push vers la branche cible
      if ! git push origin "HEAD:refs/heads/$b" 2>&1; then
        echo "PUSH_FAILED" >&2
        exit 3
      fi

      # Vérifier que le remote a bien le commit
      REMOTE_SHA="$(git ls-remote origin "refs/heads/$b" | awk '{print $1}')"
      if [ "$REMOTE_SHA" != "$LOCAL_SHA" ]; then
        echo "REMOTE_MISMATCH local=$LOCAL_SHA remote=$REMOTE_SHA" >&2
        exit 4
      fi

      echo "PUSHED_SHA=$LOCAL_SHA"
    )
    RC=$?

    if [ "$RC" -eq 0 ]; then
      ok "  poussé ($COPIED fichiers)"
      P_PUSHED=$((P_PUSHED+1))
    else
      case "$RC" in
        2) warn "  commit échoué" ;;
        3) warn "  push échoué" ;;
        4) warn "  remote mismatch" ;;
        *) warn "  échec (code $RC)" ;;
      esac
      P_FAILED=$((P_FAILED+1)); FAILED_LIST+=("$b (rc=$RC)")
    fi

    # Supprimer la branche temporaire locale
    git branch -D "$TMP_BRANCH" >/dev/null 2>&1 || true

    git worktree remove --force "$WT" 2>/dev/null || rm -rf "$WT"
  done
fi

# ─── PHASE 2: MERGE ───────────────────────────────────────────────────────
M_MERGED=0; M_SKIP=0; M_FAILED=0

if [ "$SKIP_MERGE" -eq 0 ]; then
  echo ""
  sep
  log "PHASE 2: Merge des branches dans $SOURCE_BRANCH"
  sep

  git checkout "$SOURCE_BRANCH" >/dev/null 2>&1 || die "checkout $SOURCE_BRANCH impossible"

  for b in "${BRANCHES[@]}"; do
    [ "$b" = "ats-lab/main" ] && continue

    echo ""
    log "▶ $b"

    git fetch origin "$b" >/dev/null 2>&1 || true

    UNIQUE=$(git rev-list --count "$SOURCE_BRANCH..origin/$b" 2>/dev/null || echo "0")

    if [ "$UNIQUE" -eq 0 ]; then
      log "  ⏭ 0 commit unique — rien à merger"
      M_SKIP=$((M_SKIP+1))
      continue
    fi

    log "  $UNIQUE commit(s) unique(s)"

    if [ "$DRY_RUN" -eq 1 ]; then
      log "  [dry-run] skip merge"
      continue
    fi

    if git -c user.name="$GIT_NAME" -c user.email="$GIT_EMAIL" \
        merge --no-ff --allow-unrelated-histories -X theirs \
        -m "merge: sync $b into $SOURCE_BRANCH [skip ci]" \
        "origin/$b" >/dev/null 2>&1; then
      ok "  mergé"
      M_MERGED=$((M_MERGED+1))
    else
      warn "  conflit → abort"
      git merge --abort 2>/dev/null || true
      M_FAILED=$((M_FAILED+1)); FAILED_LIST+=("$b (merge)")
    fi
  done

  if [ "$DRY_RUN" -eq 0 ] && [ "$M_MERGED" -gt 0 ]; then
    log "Push final de $SOURCE_BRANCH…"
    git push origin "$SOURCE_BRANCH" && ok "poussé" || warn "push échoué"
  fi
fi

# ─── RÉSUMÉ ────────────────────────────────────────────────────────────────
echo ""
sep
echo "  RÉSUMÉ"
sep
echo ""

if [ "$SKIP_PROPAGATE" -eq 0 ]; then
  printf '  Phase 1 (propagation):\n'
  printf '    ✅ %d poussées\n' "$P_PUSHED"
  printf '    ⏭  %d déjà à jour\n' "$P_SKIP"
  printf '    ❌ %d échecs\n' "$P_FAILED"
fi

if [ "$SKIP_MERGE" -eq 0 ]; then
  printf '  Phase 2 (merge):\n'
  printf '    ✅ %d mergées\n' "$M_MERGED"
  printf '    ⏭  %d sans commits uniques\n' "$M_SKIP"
  printf '    ❌ %d échecs\n' "$M_FAILED"
fi

if [ "${#FAILED_LIST[@]}" -gt 0 ]; then
  echo ""
  printf '  Échecs:\n'
  for f in "${FAILED_LIST[@]}"; do
    printf '    - %s\n' "$f"
  done
fi

echo ""
if [ "$DRY_RUN" -eq 0 ] && [ "${#FAILED_LIST[@]}" -eq 0 ]; then
  ok "Backup disponible: origin/$BACKUP"
fi
echo ""