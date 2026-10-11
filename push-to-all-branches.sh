#!/usr/bin/env bash
# push-to-all-branches.sh
# One script to:
#   1. push all local branches to a remote (optionally under a prefix)
#   2. push a specific file to every remote branch (default: the CI workflow)
#   3. do both, in one run
#
# Usage:
#   ./push-to-all-branches.sh                        # push branches only
#   ./push-to-all-branches.sh --with-file            # push branches + workflow
#   ./push-to-all-branches.sh --file-only            # push only the workflow
#   ./push-to-all-branches.sh --file other/path.yml  # custom file to push
#   ./push-to-all-branches.sh --dry-run              # preview
#   ./push-to-all-branches.sh --force-push           # force-with-lease
#   ./push-to-all-branches.sh --no-prefix            # don't prefix branches
#   ./push-to-all-branches.sh --prefix lab           # custom prefix (default: ats-lab)
#
# Env:
#   GIT_USER_NAME, GIT_USER_EMAIL  override identity (defaults below)

set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Config
# ─────────────────────────────────────────────────────────────
GIT_USER_NAME="${GIT_USER_NAME:-AbirhaouiSalah}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-sabirhaouipro@gmail.com}"

REMOTE_NAME="origin"
REMOTE_URL="git@github.com:AbirhaouiSalah/FDE_LAB.git"
PREFIX="ats-lab"
FILE_PATH=".github/workflows/dashboard-ci.yml"
FILE_SOURCE="main"

MODE="branches"          # branches | file | both
DRY_RUN=0
FORCE_PUSH=0

# ─────────────────────────────────────────────────────────────
# Args
# ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-file)   MODE="both"; shift ;;
    --file-only)   MODE="file"; shift ;;
    --branches-only) MODE="branches"; shift ;;
    --file)        FILE_PATH="${2:-}"; shift 2 ;;
    --file-source) FILE_SOURCE="${2:-}"; shift 2 ;;
    --url)         REMOTE_URL="${2:-}"; shift 2 ;;
    --remote)      REMOTE_NAME="${2:-}"; shift 2 ;;
    --prefix)      PREFIX="${2:-}"; shift 2 ;;
    --no-prefix)   PREFIX=""; shift ;;
    --force-push)  FORCE_PUSH=1; shift ;;
    --dry-run)     DRY_RUN=1; shift ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *)
      printf 'unexpected argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

# ─────────────────────────────────────────────────────────────
# Logging
# ─────────────────────────────────────────────────────────────
C_RESET="\033[0m"
C_BLUE="\033[1;34m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"
C_DIM="\033[2m"

log()  { printf "${C_BLUE}[push]${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_GREEN}[ ok ]${C_RESET} %s\n" "$*"; }
warn() { printf "${C_YELLOW}[warn]${C_RESET} %s\n" "$*"; }
dry()  { printf "${C_DIM}[ dry]${C_RESET} %s\n" "$*"; }
die()  { printf "${C_RED}[fail]${C_RESET} %s\n" "$*" >&2; exit 1; }

# ─────────────────────────────────────────────────────────────
# Pre-flight
# ─────────────────────────────────────────────────────────────
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repo"

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
log "repo: $REPO_ROOT"
log "mode: $MODE"

if [[ -n "$(git status --porcelain)" ]]; then
  warn "working tree has uncommitted changes:"
  git status --short | sed 's/^/    /'
  die "commit or stash before running"
fi

# Set identity
log "configuring local git identity"
git config user.name  "$GIT_USER_NAME"
git config user.email "$GIT_USER_EMAIL"
printf '    user.name=%s\n'  "$(git config user.name)"
printf '    user.email=%s\n' "$(git config user.email)"

# Configure remote
if git remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
  log "updating remote '$REMOTE_NAME' → $REMOTE_URL"
  git remote set-url "$REMOTE_NAME" "$REMOTE_URL"
else
  log "adding remote '$REMOTE_NAME' → $REMOTE_URL"
  git remote add "$REMOTE_NAME" "$REMOTE_URL"
fi
git remote -v | sed 's/^/    /'

# Verify reachability
log "checking target reachability"
set +e
LS_OUT="$(git ls-remote --exit-code "$REMOTE_NAME" 2>&1)"
LS_RC=$?
set -e
if [[ $LS_RC -ne 0 ]]; then
  warn "git ls-remote failed (rc=$LS_RC):"
  printf '%s\n' "$LS_OUT" | sed 's/^/    /'
  die "target not reachable"
fi
ok "target reachable"

# ─────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────
remote_has_branch() {
  local ref="$1"
  git ls-remote --exit-code --heads "$REMOTE_NAME" "$ref" >/dev/null 2>&1
}

fetch_remote() {
  [[ "$DRY_RUN" == "1" ]] && { dry "would fetch $REMOTE_NAME"; return; }
  git fetch --quiet --prune "$REMOTE_NAME" 2>/dev/null || true
}

PUSH_FLAGS=()
if [[ "$FORCE_PUSH" == "1" ]]; then
  PUSH_FLAGS+=("--force-with-lease")
fi

# ─────────────────────────────────────────────────────────────
# Phase 1 — push every local branch
# ─────────────────────────────────────────────────────────────
push_local_branches() {
  log "Phase 1 — push local branches"

  PUSHED=0; SKIPPED=0; FAILED=0; DRY=0

  while IFS= read -r branch; do
    [[ -z "$branch" ]] && continue

    if [[ -n "$PREFIX" ]]; then
      dest="$PREFIX/$branch"
    else
      dest="$branch"
    fi

    printf "${C_BLUE}[push]${C_RESET} %-45s → %-45s " "$branch" "$dest"

    if remote_has_branch "$dest" && [[ "$FORCE_PUSH" != "1" ]]; then
      printf "${C_YELLOW}(skip)${C_RESET}\n"
      SKIPPED=$((SKIPPED + 1))
      continue
    fi

    if [[ "$DRY_RUN" == "1" ]]; then
      printf "${C_DIM}(dry)${C_RESET}\n"
      DRY=$((DRY + 1))
      continue
    fi

    if git push "${PUSH_FLAGS[@]}" --quiet "$REMOTE_NAME" \
         "refs/heads/$branch:refs/heads/$dest"; then
      printf "${C_GREEN}ok${C_RESET}\n"
      PUSHED=$((PUSHED + 1))
    else
      printf "${C_RED}FAILED${C_RESET}\n"
      FAILED=$((FAILED + 1))
    fi
  done < <(git for-each-ref --format='%(refname:short)' refs/heads | sort)

  echo
  ok "Phase 1 summary: pushed=$PUSHED skipped=$SKIPPED failed=$FAILED dry=$DRY"
  return $FAILED
}

# ─────────────────────────────────────────────────────────────
# Phase 2 — push a file to every remote branch under the prefix
# ─────────────────────────────────────────────────────────────
push_file_to_all_branches() {
  log "Phase 2 — push '$FILE_PATH' to every '$PREFIX/*' branch"

  # Ensure the file exists in the source ref
  if ! git cat-file -e "$FILE_SOURCE:$FILE_PATH" 2>/dev/null; then
    die "$FILE_PATH not found in branch '$FILE_SOURCE'"
  fi

  # Refresh remote tracking refs
  fetch_remote

  # List target branches
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
      [[ -n "$line" ]] && BRANCHES+=("$line")
    done < <(
      git for-each-ref --format='%(refname:short)' \
        "refs/remotes/$REMOTE_NAME" \
      | grep -v "/HEAD$" \
      | sed "s|^$REMOTE_NAME/||" \
      | sort
    )
  fi

  [[ ${#BRANCHES[@]} -gt 0 ]] || die "no branches matching prefix '$PREFIX'"

  log "found ${#BRANCHES[@]} branches"

  # Get the file content and blob SHA ONCE
  FILE_CONTENT="$(git show "$FILE_SOURCE:$FILE_PATH")"
  FILE_BLOB="$(printf '%s' "$FILE_CONTENT" | git hash-object -w --stdin)"

  UPDATED=0; SKIPPED=0; FAILED=0; DRY=0

  for ref in "${BRANCHES[@]}"; do
    printf "${C_BLUE}[push]${C_RESET} %-45s " "$ref"

    # Skip if unchanged
    if git cat-file -e "$REMOTE_NAME/$ref:$FILE_PATH" 2>/dev/null; then
      existing="$(git show "$REMOTE_NAME/$ref:$FILE_PATH" 2>/dev/null || true)"
      if [[ "$existing" == "$FILE_CONTENT" ]]; then
        printf "${C_YELLOW}(skip — up to date)${C_RESET}\n"
        SKIPPED=$((SKIPPED + 1))
        continue
      fi
    fi

    if [[ "$DRY_RUN" == "1" ]]; then
      printf "${C_DIM}(dry — would add/update)${C_RESET}\n"
      DRY=$((DRY + 1))
      continue
    fi

    # Build commit with temporary index
    TMPINDEX="$(mktemp)"
    export GIT_INDEX_FILE="$TMPINDEX"

    PARENT="$(git rev-parse "$REMOTE_NAME/$ref")"
    git read-tree "$PARENT"

    DIR="$(dirname "$FILE_PATH")"
    # Create missing tree entries along the path
    if [[ "$DIR" != "." ]]; then
      # git update-index --add --cacheinfo needs the full path; it creates
      # parent tree objects automatically when the index is written.
      :
    fi
    git update-index --add --cacheinfo 100644 "$FILE_BLOB" "$FILE_PATH"

    TREE="$(git write-tree)"
    COMMIT="$(GIT_AUTHOR_NAME="$GIT_USER_NAME" \
              GIT_AUTHOR_EMAIL="$GIT_USER_EMAIL" \
              GIT_COMMITTER_NAME="$GIT_USER_NAME" \
              GIT_COMMITTER_EMAIL="$GIT_USER_EMAIL" \
              git commit-tree "$TREE" -p "$PARENT" -m "ci: add $(basename "$FILE_PATH") to this branch")"

    unset GIT_INDEX_FILE
    rm -f "$TMPINDEX"

    if git push --quiet "$REMOTE_NAME" "$COMMIT:refs/heads/$ref"; then
      printf "${C_GREEN}ok${C_RESET}\n"
      UPDATED=$((UPDATED + 1))
    else
      printf "${C_RED}FAILED${C_RESET}\n"
      FAILED=$((FAILED + 1))
    fi
  done

  echo
  ok "Phase 2 summary: updated=$UPDATED skipped=$SKIPPED failed=$FAILED dry=$DRY"
  return $FAILED
}

# ─────────────────────────────────────────────────────────────
# Execute
# ─────────────────────────────────────────────────────────────
FAILED_TOTAL=0

case "$MODE" in
  branches)
    push_local_branches || FAILED_TOTAL=$((FAILED_TOTAL + $?))
    ;;
  file)
    push_file_to_all_branches || FAILED_TOTAL=$((FAILED_TOTAL + $?))
    ;;
  both)
    push_local_branches || FAILED_TOTAL=$((FAILED_TOTAL + $?))
    echo
    push_file_to_all_branches || FAILED_TOTAL=$((FAILED_TOTAL + $?))
    ;;
esac

# ─────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────
echo
if [[ $FAILED_TOTAL -eq 0 ]]; then
  ok "all done — no failures"
else
  warn "$FAILED_TOTAL branch(es) failed"
fi

URL_BASE="${REMOTE_URL%.git}"
URL_BASE="${URL_BASE/git@github.com:/https://github.com/}"
printf "  view: %s/branches/all\n" "$URL_BASE"

exit $FAILED_TOTAL
