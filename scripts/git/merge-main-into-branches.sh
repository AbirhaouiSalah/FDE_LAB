#!/usr/bin/env bash
# scripts/merge-main-into-branches.sh (v2)
#
# Merge 'main' dans chaque branche ats-lab/* pour que les branches
# contiennent tout le contenu de main + leur historique propre.
#
# Résolution automatique des conflits en faveur de main (--theirs).
#
# Usage:
#   ./scripts/merge-main-into-branches.sh [OPTIONS]
#
# Options:
#   --dry-run       Simule, ne pousse rien
#   --yes, -y       Pas de confirmation interactive
#   --source <b>    Branche source (défaut: main)
#   -h, --help      Aide

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT_DIR"

GIT_NAME="AbirhaouiSalah"
GIT_EMAIL="sabirhaouipro@gmail.com"

DRY_RUN=0
ASSUME_YES=0
SOURCE_BRANCH="main"

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)  DRY_RUN=1 ;;
    --yes|-y)   ASSUME_YES=1 ;;
    --source)   shift; SOURCE_BRANCH="${1:?--source requiert une valeur}" ;;
    -h|--help)  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'Argument inconnu: %s\n' "$1" >&2; exit 1 ;;
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
log()  { printf '%s[sync]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok  ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
err()  { printf '%s[err ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; }
die()  { err "$@"; exit 1; }
sep()  { printf '%s%s%s\n' "$C_DIM" "════════════════════════════════════════════════════════════════" "$C_RST"; }

# ─── Préflight ─────────────────────────────────────────────────────────────
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

# ─── Backup ────────────────────────────────────────────────────────────────
BACKUP="backup/pre-align-$(date +%Y%m%d-%H%M%S)"
if [ "$DRY_RUN" -eq 0 ]; then
  git branch "$BACKUP" "$SOURCE_BRANCH" 2>/dev/null || true
  git push origin "$BACKUP" >/dev/null 2>&1 && ok "Backup: origin/$BACKUP" || warn "Backup échouée"
fi

if [ "$DRY_RUN" -eq 0 ] && [ "$ASSUME_YES" -eq 0 ]; then
  printf '\n'
  warn "Merger '$SOURCE_BRANCH' dans $TOTAL branches ats-lab/*"
  warn "Résolution automatique des conflits en faveur de $SOURCE_BRANCH"
  printf '\nContinuer ? [y/N] '
  read -r ans
  [ "${ans:-N}" = "y" ] || [ "${ans:-N}" = "Y" ] || { echo "Abort."; exit 0; }
fi

# ─── Worktrees ─────────────────────────────────────────────────────────────
WORKTREE_BASE=".align-worktrees"
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

# ─── Merge main → chaque branche ──────────────────────────────────────────
M_MERGED=0; M_SKIP=0; M_FAILED=0
FAILED_LIST=()

echo ""
sep
log "MERGE $SOURCE_BRANCH → $TOTAL branches"
sep

for b in "${BRANCHES[@]}"; do
  [ "$b" = "ats-lab/main" ] && { log "  skip ats-lab/main"; continue; }

  SAFE="${b//\//_}"
  WT="$WORKTREE_BASE/$SAFE"
  TMP_BRANCH="align-tmp-$$-$SAFE"

  echo ""
  log "▶ $b"

  if ! git worktree add --detach "$WT" "origin/$b" >/dev/null 2>&1; then
    warn "  worktree add échoué"
    M_FAILED=$((M_FAILED+1)); FAILED_LIST+=("$b (worktree)"); continue
  fi

  # Vérifier si main est déjà ancêtre
  IS_ANCESTOR=0
  if (cd "$WT" && git merge-base --is-ancestor "$SOURCE_BRANCH" HEAD 2>/dev/null); then
    IS_ANCESTOR=1
  fi

  if [ "$IS_ANCESTOR" -eq 1 ]; then
    log "  ⏭ $SOURCE_BRANCH déjà ancêtre — rien à faire"
    M_SKIP=$((M_SKIP+1))
    git worktree remove --force "$WT" 2>/dev/null || rm -rf "$WT"
    continue
  fi

  AHEAD=$(cd "$WT" && git rev-list --count "HEAD..$SOURCE_BRANCH" 2>/dev/null || echo "?")
  log "  $AHEAD commits de $SOURCE_BRANCH à absorber"

  if [ "$DRY_RUN" -eq 1 ]; then
    log "  [dry-run] skip merge+push"
    git worktree remove --force "$WT" 2>/dev/null || rm -rf "$WT"
    continue
  fi

  # ─── Merge avec résolution automatique des conflits ─────────────────
  PUSHED_SHA=$(
    cd "$WT" || exit 1

    # Créer branche locale
    git checkout -b "$TMP_BRANCH" >/dev/null 2>&1 || exit 1

    # 1. Merge avec -X theirs (résout les hunks)
    MERGE_OK=0
    if git -c user.name="$GIT_NAME" -c user.email="$GIT_EMAIL" \
         merge --no-ff --allow-unrelated-histories -X theirs \
         -m "merge: align $b with $SOURCE_BRANCH [skip ci]" \
         "$SOURCE_BRANCH" >/dev/null 2>&1; then
      MERGE_OK=1
    fi

    # 2. Si conflit → résoudre automatiquement en faveur de main
    if [ "$MERGE_OK" -eq 0 ]; then
      CONFLICTS=$(git diff --name-only --diff-filter=U 2>/dev/null || true)

      if [ -z "$CONFLICTS" ]; then
        # Pas de conflit listé mais merge a échoué → erreur inconnue
        echo "MERGE_FAILED_NO_CONFLICT" >&2
        exit 2
      fi

      # Résoudre chaque conflit avec la version de "theirs" (= main)
      echo "$CONFLICTS" | while IFS= read -r f; do
        [ -z "$f" ] && continue
        if git checkout --theirs -- "$f" 2>/dev/null; then
          git add -- "$f"
        else
          # Si checkout échoue (fichier binaire ?), on prend main
          git rm -f -- "$f" 2>/dev/null || true
          git show "$SOURCE_BRANCH:$f" > "$f" 2>/dev/null && git add -- "$f" || true
        fi
      done

      # Vérifier qu'il ne reste plus de conflit
      REMAINING=$(git diff --name-only --diff-filter=U 2>/dev/null || true)
      if [ -n "$REMAINING" ]; then
        echo "UNRESOLVED_CONFLICTS: $REMAINING" >&2
        exit 2
      fi

      # Finaliser le merge
      if ! git -c user.name="$GIT_NAME" -c user.email="$GIT_EMAIL" \
           commit --no-edit >/dev/null 2>&1; then
        echo "FINAL_COMMIT_FAILED" >&2
        exit 2
      fi
    fi

    LOCAL_SHA="$(git rev-parse HEAD)"

    # Push
    if ! git push origin "HEAD:refs/heads/$b" >/dev/null 2>&1; then
      echo "PUSH_FAILED" >&2
      exit 3
    fi

    REMOTE_SHA="$(git ls-remote origin "refs/heads/$b" 2>/dev/null | awk '{print $1}')"
    if [ "$REMOTE_SHA" != "$LOCAL_SHA" ]; then
      echo "MISMATCH local=$LOCAL_SHA remote=$REMOTE_SHA" >&2
      exit 4
    fi

    echo "$LOCAL_SHA"
  )
  RC=$?

  if [ "$RC" -eq 0 ]; then
    ok "  aligné avec $SOURCE_BRANCH (sha=$(printf '%.7s' "$PUSHED_SHA"))"
    M_MERGED=$((M_MERGED+1))
  else
    case "$RC" in
      2) warn "  conflit non résolu" ;;
      3) warn "  push échoué" ;;
      4) warn "  remote mismatch" ;;
      *) warn "  échec (code $RC)" ;;
    esac
    M_FAILED=$((M_FAILED+1)); FAILED_LIST+=("$b (rc=$RC)")
  fi

  git branch -D "$TMP_BRANCH" >/dev/null 2>&1 || true
  git worktree remove --force "$WT" 2>/dev/null || rm -rf "$WT"
done

# ─── Résumé ────────────────────────────────────────────────────────────────
echo ""
sep
echo "  RÉSUMÉ"
sep
echo ""
printf '  ✅ %d branches alignées avec %s\n' "$M_MERGED" "$SOURCE_BRANCH"
printf '  ⏭  %d déjà à jour\n' "$M_SKIP"
printf '  ❌ %d échecs\n' "$M_FAILED"

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