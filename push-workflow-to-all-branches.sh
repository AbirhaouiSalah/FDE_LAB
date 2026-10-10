#!/usr/bin/env bash
# push-workflow-to-all-branches.sh
# Adds .github/workflows/dashboard-ci.yml to every ats-lab/* branch on the remote.
# Works on bash 3.2+ (macOS default).

set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Config
# ─────────────────────────────────────────────────────────────
REMOTE_NAME="origin"
REMOTE_PREFIX="ats-lab"
WORKFLOW_PATH=".github/workflows/dashboard-ci.yml"
SOURCE_REF="HEAD"
COMMIT_MSG="ci: add dashboard workflow to this branch"
DRY_RUN=0
FORCE_PUSH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)     DRY_RUN=1; shift ;;
    --force-push)  FORCE_PUSH=1; shift ;;
    --source)      SOURCE_REF="${2:-}"; shift 2 ;;
    --prefix)      REMOTE_PREFIX="${2:-}"; shift 2 ;;
    --remote)      REMOTE_NAME="${2:-}"; shift 2 ;;
    -h|--help)     sed -n '2,5p' "$0"; exit 0 ;;
    *) printf 'unexpected arg: %s\n' "$1" >&2; exit 1 ;;
  esac
done

# ─────────────────────────────────────────────────────────────
# Logging
# ─────────────────────────────────────────────────────────────
C_RESET="\033[0m"; C_BLUE="\033[1;34m"; C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"; C_RED="\033[1;31m"; C_DIM="\033[2m"
log()  { printf "${C_BLUE}[wf]${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_GREEN}[ok ]${C_RESET} %s\n" "$*"; }
warn() { printf "${C_YELLOW}[wrn]${C_RESET} %s\n" "$*"; }
die()  { printf "${C_RED}[err]${C_RESET} %s\n" "$*" >&2; exit 1; }

# ─────────────────────────────────────────────────────────────
# Pre-flight
# ─────────────────────────────────────────────────────────────
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not a git repo"
[[ -z "$(git status --porcelain)" ]] || die "working tree is dirty — commit or stash first"

git rev-parse --verify "$SOURCE_REF" >/dev/null 2>&1 || die "source ref '$SOURCE_REF' not found"
git cat-file -e "$SOURCE_REF:$WORKFLOW_PATH" 2>/dev/null \
  || die "$WORKFLOW_PATH not found in $SOURCE_REF"

log "workflow source: $SOURCE_REF:$WORKFLOW_PATH"
log "target remote:   $REMOTE_NAME"
log "target prefix:   $REMOTE_PREFIX/"

log "fetching remote refs"
git fetch --quiet "$REMOTE_NAME" '+refs/heads/*:refs/remotes/'"$REMOTE_NAME"'/*'

# List every remote ref matching the prefix (bash 3.2-compatible)
BRANCHES=()
while IFS= read -r line; do
  [[ -n "$line" ]] && BRANCHES+=("$line")
done < <(
  git for-each-ref --format='%(refname:short)' \
    "refs/remotes/$REMOTE_NAME/$REMOTE_PREFIX" \
  | sed "s|^$REMOTE_NAME/||" \
  | sort
)

[[ ${#BRANCHES[@]} -gt 0 ]] || die "no branches matching '$REMOTE_PREFIX/*' on $REMOTE_NAME"
log "found ${#BRANCHES[@]} branches to update"

# ─────────────────────────────────────────────────────────────
# Temp worktree
# ─────────────────────────────────────────────────────────────
TMP="$(mktemp -d)"
cleanup() {
  git worktree remove --force "$TMP/wt" 2>/dev/null || true
  rm -rf "$TMP"
}
trap cleanup EXIT

git worktree add --detach --quiet "$TMP/wt" "$SOURCE_REF"
WT="$TMP/wt"
log "worktree at $WT"

# ─────────────────────────────────────────────────────────────
# Iterate
# ─────────────────────────────────────────────────────────────
UPDATED=0
SKIPPED=0
FAILED=0
DRY=0

for remote_ref in "${BRANCHES[@]}"; do
  printf "${C_BLUE}[wf]${C_RESET} %-45s " "$remote_ref"

  # Check if the workflow already exists on that branch
  if git cat-file -e "$REMOTE_NAME/$remote_ref:$WORKFLOW_PATH" 2>/dev/null; then
    local_sha="$(git rev-parse "$SOURCE_REF:$WORKFLOW_PATH")"
    remote_sha="$(git rev-parse "$REMOTE_NAME/$remote_ref:$WORKFLOW_PATH")"
    if [[ "$local_sha" == "$remote_sha" ]]; then
      printf "${C_YELLOW}(skip — already up to date)${C_RESET}\n"
      SKIPPED=$((SKIPPED + 1))
      continue
    fi
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    printf "${C_DIM}(dry — would add/update)${C_RESET}\n"
    DRY=$((DRY + 1))
    continue
  fi

  # Check out the branch head in the worktree
  if ! git -C "$WT" checkout --quiet --detach "$REMOTE_NAME/$remote_ref" 2>/dev/null; then
    printf "${C_RED}FAILED (checkout)${C_RESET}\n"
    FAILED=$((FAILED + 1))
    continue
  fi

  # Extract the workflow file from the source ref using git show
  mkdir -p "$WT/$(dirname "$WORKFLOW_PATH")"
  if ! git show "$SOURCE_REF:$WORKFLOW_PATH" > "$WT/$WORKFLOW_PATH" 2>/dev/null; then
    printf "${C_RED}FAILED (extract)${C_RESET}\n"
    FAILED=$((FAILED + 1))
    continue
  fi

  # Stage it (git add -A picks up new files anywhere)
  git -C "$WT" add -A "$(dirname "$WORKFLOW_PATH")"

  # Nothing to commit?
  if git -C "$WT" diff --quiet --cached; then
    printf "${C_YELLOW}(skip — no changes)${C_RESET}\n"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Commit
  git -C "$WT" -c user.name="AbirhaouiSalah" \
              -c user.email="sabirhaouipro@gmail.com" \
              commit --quiet -m "$COMMIT_MSG"

  # Push
  PUSH_FLAGS=()
  [[ "$FORCE_PUSH" == "1" ]] && PUSH_FLAGS+=("--force-with-lease")

  if git -C "$WT" push --quiet "${PUSH_FLAGS[@]}" "$REMOTE_NAME" \
       "HEAD:refs/heads/$remote_ref"; then
    printf "${C_GREEN}ok${C_RESET}\n"
    UPDATED=$((UPDATED + 1))
  else
    printf "${C_RED}FAILED (push)${C_RESET}\n"
    FAILED=$((FAILED + 1))
  fi
done

# ─────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────
echo
ok "workflow propagation complete"
printf "  updated: %d\n" "$UPDATED"
printf "  skipped: %d\n" "$SKIPPED"
printf "  failed:  %d\n" "$FAILED"
[[ "$DRY" -gt 0 ]] && printf "  dry:     %d\n" "$DRY"

[[ "$FAILED" -gt 0 ]] && exit 1
exit 0