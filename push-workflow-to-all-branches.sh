#!/usr/bin/env bash
# push-workflow-to-all-branches.sh
# Push a single file (default: CI workflow) to every remote branch under a prefix.
#
# Usage:
#   ./push-workflow-to-all-branches.sh
#   ./push-workflow-to-all-branches.sh --dry-run
#   ./push-workflow-to-all-branches.sh --file other/path.yml
#   ./push-workflow-to-all-branches.sh --file-source main
#   ./push-workflow-to-all-branches.sh --prefix ats-lab
#   ./push-workflow-to-all-branches.sh --no-prefix
#   ./push-workflow-to-all-branches.sh --skip-main
#   ./push-workflow-to-all-branches.sh --force-push
#
# Portable: bash 3.2 (macOS), bash 4+, no mapfile, no worktrees, no external tools.

set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Defaults
# ─────────────────────────────────────────────────────────────
GIT_USER_NAME="${GIT_USER_NAME:-AbirhaouiSalah}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-sabirhaouipro@gmail.com}"

REMOTE_NAME="origin"
REMOTE_URL="git@github.com:AbirhaouiSalah/FDE_LAB.git"
PREFIX="ats-lab"
FILE_PATH=".github/workflows/dashboard-ci.yml"
FILE_SOURCE="main"
COMMIT_MSG_PREFIX="ci: sync"

DRY_RUN=0
FORCE_PUSH=0
SKIP_MAIN=0

# ─────────────────────────────────────────────────────────────
# Args
# ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)         FILE_PATH="${2:-}"; shift 2 ;;
    --file-source)  FILE_SOURCE="${2:-}"; shift 2 ;;
    --prefix)       PREFIX="${2:-}"; shift 2 ;;
    --no-prefix)    PREFIX=""; shift ;;
    --url)          REMOTE_URL="${2:-}"; shift 2 ;;
    --remote)       REMOTE_NAME="${2:-}"; shift 2 ;;
    --skip-main)    SKIP_MAIN=1; shift ;;
    --force-push)   FORCE_PUSH=1; shift ;;
    --dry-run)      DRY_RUN=1; shift ;;
    -h|--help)
      sed -n '2,17p' "$0"
      exit 0
      ;;
    *)
      printf 'unexpected arg: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

# ─────────────────────────────────────────────────────────────
# Colors + logging
# ─────────────────────────────────────────────────────────────
C_RESET="\033[0m"; C_BLUE="\033[1;34m"; C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"; C_RED="\033[1;31m"; C_DIM="\033[2m"

log()  { printf "${C_BLUE}[wf]${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_GREEN}[ok ]${C_RESET} %s\n" "$*"; }
warn() { printf "${C_YELLOW}[wrn]${C_RESET} %s\n" "$*"; }
dry()  { printf "${C_DIM}[dry]${C_RESET} %s\n" "$*"; }
die()  { printf "${C_RED}[err]${C_RESET} %s\n" "$*" >&2; exit 1; }

# ─────────────────────────────────────────────────────────────
# Pre-flight
# ─────────────────────────────────────────────────────────────
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repo"

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
log "repo: $REPO_ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
  warn "working tree has uncommitted changes:"
  git status --short | sed 's/^/    /'
  die "commit or stash first"
fi

# Configure identity
git config user.name  "$GIT_USER_NAME"
git config user.email "$GIT_USER_EMAIL"
log "identity: $GIT_USER_NAME <$GIT_USER_EMAIL>"

# Configure remote
if git remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
  log "updating remote '$REMOTE_NAME' → $REMOTE_URL"
  git remote set-url "$REMOTE_NAME" "$REMOTE_URL"
else
  log "adding remote '$REMOTE_NAME' → $REMOTE_URL"
  git remote add "$REMOTE_NAME" "$REMOTE_URL"
fi

log "checking target reachability"
set +e
LS_OUT="$(git ls-remote --exit-code "$REMOTE_NAME" 2>&1)"
LS_RC=$?
set -e
if [[ $LS_RC -ne 0 ]]; then
  warn "git ls-remote failed (rc=$LS_RC):"
  printf '%s\n' "$LS_OUT" | sed 's/^/    /'
  die "target not reachable at $REMOTE_URL"
fi
ok "target reachable"

# Verify the file exists on the source branch
log "checking file '$FILE_PATH' on '$FILE_SOURCE'"
git rev-parse --verify "$FILE_SOURCE" >/dev/null 2>&1 \
  || die "source branch '$FILE_SOURCE' not found"
git cat-file -e "$FILE_SOURCE:$FILE_PATH" 2>/dev/null \
  || die "'$FILE_PATH' not found in branch '$FILE_SOURCE'"
ok "file exists on $FILE_SOURCE"

# ─────────────────────────────────────────────────────────────
# Fetch remote refs
# ─────────────────────────────────────────────────────────────
log "fetching remote refs from '$REMOTE_NAME'"
git fetch --quiet --prune "$REMOTE_NAME" 2>/dev/null || true

# ─────────────────────────────────────────────────────────────
# List target branches (bash 3.2-safe: no mapfile)
# ─────────────────────────────────────────────────────────────
BRANCHES=()
if [[ -n "$PREFIX" ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && BRANCHES+=("$line")
  done < <(
    git for-each-ref --format='%(refname:short)' \
      "refs/remotes/$REMOTE_NAME/$PREFIX" \
    | sed "s|^$REMOTE_NAME/||" \
    | sort
  )
else
  while IFS= read -r line; do
    [[ -n "$line" && "$line" != */HEAD ]] && BRANCHES+=("$line")
  done < <(
    git for-each-ref --format='%(refname:short)' \
      "refs/remotes/$REMOTE_NAME" \
    | sed "s|^$REMOTE_NAME/||" \
    | sort
  )
fi

[[ ${#BRANCHES[@]} -gt 0 ]] || die "no branches matching prefix '$PREFIX/*' on $REMOTE_NAME"
log "found ${#BRANCHES[@]} target branches"

# ─────────────────────────────────────────────────────────────
# Capture file content + blob ONCE
# ─────────────────────────────────────────────────────────────
FILE_CONTENT="$(git show "$FILE_SOURCE:$FILE_PATH")"
FILE_BLOB="$(printf '%s' "$FILE_CONTENT" | git hash-object -w --stdin)"
FILE_BASENAME="$(basename "$FILE_PATH")"
FILE_COMMIT_MSG="$COMMIT_MSG_PREFIX $FILE_BASENAME"

log "file blob: ${FILE_BLOB:0:10}..."
log "file size: $(printf '%s' "$FILE_CONTENT" | wc -c | tr -d ' ') bytes"

# ─────────────────────────────────────────────────────────────
# Prepare push flags (portable empty-array pattern)
# ─────────────────────────────────────────────────────────────
PUSH_FLAGS=()
if [[ "$FORCE_PUSH" == "1" ]]; then
  PUSH_FLAGS+=("--force-with-lease")
fi

# ─────────────────────────────────────────────────────────────
# Iterate branches
# ─────────────────────────────────────────────────────────────
UPDATED=0
SKIPPED=0
FAILED=0
DRY=0
SKIPPED_MAIN=0

for ref in "${BRANCHES[@]}"; do
  # Optional main skip
  if [[ "$SKIP_MAIN" == "1" && "$ref" == "$PREFIX/main" ]]; then
    printf "${C_BLUE}[wf]${C_RESET} %-45s ${C_DIM}(skip - main)${C_RESET}\n" "$ref"
    SKIPPED_MAIN=$((SKIPPED_MAIN + 1))
    continue
  fi

  printf "${C_BLUE}[wf]${C_RESET} %-45s " "$ref"

  # Skip if already identical
  if git cat-file -e "$REMOTE_NAME/$ref:$FILE_PATH" 2>/dev/null; then
    existing="$(git show "$REMOTE_NAME/$ref:$FILE_PATH" 2>/dev/null || true)"
    if [[ "$existing" == "$FILE_CONTENT" ]]; then
      printf "${C_YELLOW}(skip - up to date)${C_RESET}\n"
      SKIPPED=$((SKIPPED + 1))
      continue
    fi
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    printf "${C_DIM}(dry - would update)${C_RESET}\n"
    DRY=$((DRY + 1))
    continue
  fi

  # Build commit with a temp index
  TMPINDEX="$(mktemp)"
  export GIT_INDEX_FILE="$TMPINDEX"

  if ! PARENT="$(git rev-parse "$REMOTE_NAME/$ref" 2>/dev/null)"; then
    printf "${C_RED}FAILED (no parent)${C_RESET}\n"
    unset GIT_INDEX_FILE; rm -f "$TMPINDEX"
    FAILED=$((FAILED + 1))
    continue
  fi

  if ! git read-tree "$PARENT" 2>/dev/null; then
    printf "${C_RED}FAILED (read-tree)${C_RESET}\n"
    unset GIT_INDEX_FILE; rm -f "$TMPINDEX"
    FAILED=$((FAILED + 1))
    continue
  fi

  if ! git update-index --add --cacheinfo 100644 "$FILE_BLOB" "$FILE_PATH" 2>/dev/null; then
    printf "${C_RED}FAILED (update-index)${C_RESET}\n"
    unset GIT_INDEX_FILE; rm -f "$TMPINDEX"
    FAILED=$((FAILED + 1))
    continue
  fi

  if ! TREE="$(git write-tree 2>/dev/null)"; then
    printf "${C_RED}FAILED (write-tree)${C_RESET}\n"
    unset GIT_INDEX_FILE; rm -f "$TMPINDEX"
    FAILED=$((FAILED + 1))
    continue
  fi

  unset GIT_INDEX_FILE
  rm -f "$TMPINDEX"

  if ! COMMIT="$(
      GIT_AUTHOR_NAME="$GIT_USER_NAME" \
      GIT_AUTHOR_EMAIL="$GIT_USER_EMAIL" \
      GIT_COMMITTER_NAME="$GIT_USER_NAME" \
      GIT_COMMITTER_EMAIL="$GIT_USER_EMAIL" \
      git commit-tree "$TREE" -p "$PARENT" -m "$FILE_COMMIT_MSG" 2>/dev/null
    )"; then
    printf "${C_RED}FAILED (commit-tree)${C_RESET}\n"
    FAILED=$((FAILED + 1))
    continue
  fi

  if git push --quiet ${PUSH_FLAGS[@]+"${PUSH_FLAGS[@]}"} "$REMOTE_NAME" \
       "$COMMIT:refs/heads/$ref" 2>/dev/null; then
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
ok "propagation complete"
printf "  updated:      %d\n" "$UPDATED"
printf "  skipped:      %d\n" "$SKIPPED"
if [[ "$SKIPPED_MAIN" -gt 0 ]]; then
  printf "  skipped main: %d\n" "$SKIPPED_MAIN"
fi
printf "  failed:       %d\n" "$FAILED"
if [[ "$DRY" -gt 0 ]]; then
  printf "  dry:          %d\n" "$DRY"
fi

# Browser-friendly view URL
URL_BASE="${REMOTE_URL%.git}"
URL_BASE="${URL_BASE/git@github.com:/https://github.com/}"
printf "  view:         %s/branches/all\n" "$URL_BASE"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
