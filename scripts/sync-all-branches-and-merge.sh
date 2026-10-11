#!/usr/bin/env bash
# scripts/sync-all-branches-and-merge.sh (v2)
#
# Propage la toolchain de 'main' sur toutes les branches ats-lab/*,
# puis merge toutes les ats-lab/* dans main.
#
# Approche: git worktree — le working tree principal n'est JAMAIS modifié.
#
# Usage:
#   ./scripts/sync-all-branches-and-merge.sh [--dry-run] [--yes] [--no-merge] [--source main]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

# Fichiers à propager
FILES=(
  "scripts/run.sh"
  "scripts/run.ps1"
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

DRY_RUN=0; ASSUME_YES=0; SKIP_MERGE=0; SOURCE_BRANCH="main"
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)  DRY_RUN=1 ;;
    --yes|-y)   ASSUME_YES=1 ;;
    --no-merge) SKIP_MERGE=1 ;;
    --source)   shift; SOURCE_BRANCH="${1:?--source requiert une valeur}" ;;
    -h|--help)  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
log()  { printf '%s[sync]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok  ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
die()  { printf '%s[err ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; exit 1; }

# ─── Préflight ─────────────────────────────────────────────────────────────
[ -d .git ] || die "Pas dans un dépôt git"
[ -n "$(git status --porcelain)" ] && die "Working tree non propre — commit/stash d'abord"
git rev-parse --verify "$SOURCE_BRANCH" >/dev/null 2>&1 || die "Branche source '$SOURCE_BRANCH' introuvable"

log "Fetch origin…"
git fetch origin --prune

# Branches ats-lab/*
BRANCHES=()
while IFS= read -r b; do
  [ -n "$b" ] && BRANCHES+=("$b")
done < <(git ls-remote --heads origin 'refs/heads/ats-lab/*' \
         | awk -F'refs/heads/' '{print $2}' | sort -u)

[ "${#BRANCHES[@]}" -eq 0 ] && die "Aucune branche ats-lab/* trouvée"
log "Branches détectées: ${#BRANCHES[@]}"

# Backup
BACKUP="backup/pre-merge-$(date +%Y%m%d-%H%M%S)"
if [ "$DRY_RUN" -eq 0 ]; then
  git branch "$BACKUP" "$SOURCE_BRANCH"
  git push origin "$BACKUP" 2>&1 | tail -1
  ok "Backup: origin/$BACKUP"
fi

# Confirmation
if [ "$DRY_RUN" -eq 0 ] && [ "$ASSUME_YES" -eq 0 ]; then
  warn "Propagation de '$SOURCE_BRANCH' → ${#BRANCHES[@]} branches + merge retour"
  read -r -p "Continuer ? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { echo "Abort."; exit 0; }
fi

# ─── Worktrees temporaires ─────────────────────────────────────────────────
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

# ─── Phase 1: propagation ──────────────────────────────────────────────────
log "=== Phase 1: propagation ==="
PROPAGATED=0; NOOP=0; FAILED_PROP=()

for b in "${BRANCHES[@]}"; do
  [ "$b" = "ats-lab/main" ] && { log "  skip ats-lab/main"; continue; }

  SAFE_NAME="${b//\//_}"
  WT_DIR="$WORKTREE_BASE/$SAFE_NAME"

  log "▶ $b"

  # Créer un worktree sur la branche distante
  if ! git worktree add --force --detach "$WT_DIR" "origin/$b" >/dev/null 2>&1; then
    warn "  worktree add échoué"
    FAILED_PROP+=("$b (worktree)")
    continue
  fi

  # Copier les fichiers depuis main
  COPIED=0
  for f in "${FILES[@]}"; do
    SRC_CONTENT="$(git show "$SOURCE_BRANCH:$f" 2>/dev/null || true)"
    [ -z "$SRC_CONTENT" ] && continue

    TARGET="$WT_DIR/$f"
    mkdir -p "$(dirname "$TARGET")"

    # Comparer avant d'écrire
    if [ -f "$TARGET" ] && [ "$(cat "$TARGET")" = "$SRC_CONTENT" ]; then
      continue
    fi

    printf '%s' "$SRC_CONTENT" > "$TARGET"
    COPIED=$((COPIED+1))
  done

  if [ "$COPIED" -eq 0 ]; then
    log "  déjà à jour"
    NOOP=$((NOOP+1))
    git worktree remove --force "$WT_DIR" 2>/dev/null || true
    continue
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log "  [dry-run] $COPIED fichiers à copier"
    ( cd "$WT_DIR" && git diff --stat )
    git worktree remove --force "$WT_DIR" 2>/dev/null || true
    continue
  fi

  # Commit + push depuis le worktree
  (
    cd "$WT_DIR"
    git checkout -B "$b" >/dev/null 2>&1
    git add "${FILES[@]}" 2>/dev/null || true
    git -c user.name="AbirhaouiSalah" -c user.email="sabirhaouipro@gmail.com" \
        commit -m "chore(sync): propagate toolchain from $SOURCE_BRANCH [skip ci]" >/dev/null
    git push origin "HEAD:refs/heads/$b" >/dev/null 2>&1
  ) && { ok "  poussé ($COPIED fichiers)"; PROPAGATED=$((PROPAGATED+1)); } \
    || { warn "  push échoué"; FAILED_PROP+=("$b (push)"); }

  git worktree remove --force "$WT_DIR" 2>/dev/null || true
done

# ─── Phase 2: merge dans main ──────────────────────────────────────────────
if [ "$SKIP_MERGE" -eq 0 ]; then
  log "=== Phase 2: merge dans $SOURCE_BRANCH ==="
  git checkout "$SOURCE_BRANCH" >/dev/null 2>&1 || die "checkout $SOURCE_BRANCH impossible"

  MERGED=0; NOOP_M=0; FAILED_M=()

  for b in "${BRANCHES[@]}"; do
    [ "$b" = "ats-lab/main" ] && continue

    log "▶ merge $b"

    git fetch origin "$b" >/dev/null 2>&1 || true

    if git merge-base --is-ancestor "origin/$b" "$SOURCE_BRANCH" 2>/dev/null; then
      log "  déjà dans $SOURCE_BRANCH"
      NOOP_M=$((NOOP_M+1))
      continue
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
      log "  [dry-run] merge à effectuer"
      continue
    fi

    if git -c user.name="AbirhaouiSalah" -c user.email="sabirhaouipro@gmail.com" \
        merge --no-ff --allow-unrelated-histories -X theirs \
        -m "merge: sync $b into $SOURCE_BRANCH [skip ci]" \
        "origin/$b" >/dev/null 2>&1; then
      ok "  mergé"
      MERGED=$((MERGED+1))
    else
      warn "  conflit → abort"
      git merge --abort 2>/dev/null || true
      FAILED_M+=("$b")
    fi
  done

  if [ "$DRY_RUN" -eq 0 ]; then
    log "Push final $SOURCE_BRANCH…"
    git push origin "$SOURCE_BRANCH"
  fi
fi

# ─── Résumé ────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo "  RÉSUMÉ"
echo "════════════════════════════════════════"
[ "$SKIP_MERGE" -eq 0 ] && {
  echo "Propagation: $PROPAGATED poussées, $NOOP déjà à jour, ${#FAILED_PROP[@]} échecs"
  echo "Merge:       $MERGED mergées, $NOOP_M déjà présentes, ${#FAILED_M[@]} échecs"
} || {
  echo "Propagation: $PROPAGATED poussées, $NOOP déjà à jour, ${#FAILED_PROP[@]} échecs"
}
[ "$DRY_RUN" -eq 0 ] && ok "Backup: origin/$BACKUP"