#!/usr/bin/env bash
# push-all-branches.sh
# Push every local branch to the target remote, attributed to AbirhaouiSalah.
#
# Usage:
#   ./push-all-branches.sh
#   ./push-all-branches.sh --url git@github.com:AbirhaouiSalah/FDE_LAB.git --prefix ats-lab
#   ./push-all-branches.sh --dry-run

set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Configuration — defaults
# ─────────────────────────────────────────────────────────────
GIT_USER_NAME="AbirhaouiSalah"
GIT_USER_EMAIL="sabirhaouipro@gmail.com"
REMOTE_URL="git@github.com:AbirhaouiSalah/FDE_LAB.git"
REMOTE_NAME="origin"
PREFIX="ats-lab"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)         REMOTE_URL="${2:-}"; shift 2 ;;
    --remote-name) REMOTE_NAME="${2:-}"; shift 2 ;;
    --prefix)      PREFIX="${2:-}"; shift 2 ;;
    --no-prefix)   PREFIX=""; shift ;;
    --dry-run)     DRY_RUN=1; shift ;;
    -h|--help)     sed -n '2,8p' "$0"; exit 0 ;;
    *) printf 'unexpected argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

# ─────────────────────────────────────────────────────────────
# Logging
# ─────────────────────────────────────────────────────────────
log()  { printf '\033[1;34m[push]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[ ok ]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[fail]\033[0m %s\n' "$*" >&2; exit 1; }

# ─────────────────────────────────────────────────────────────
# Pre-flight
# ─────────────────────────────────────────────────────────────
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repo"

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
log "repo: $REPO_ROOT"

# Working tree must be clean (or we refuse to push, to avoid surprises)
if [[ -n "$(git status --porcelain)" ]]; then
  warn "working tree has uncommitted changes:"
  git status --short | sed 's/^/    /'
  die "commit or stash before pushing"
fi

# Set local (repo-scoped) identity so every push is attributed correctly
log "configuring local git identity"
git config user.name  "$GIT_USER_NAME"
git config user.email "$GIT_USER_EMAIL"
git config --list | grep -E '^user\.' | sed 's/^/    /'

# Configure remote
if git remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
  log "updating remote '$REMOTE_NAME' → $REMOTE_URL"
  git remote set-url "$REMOTE_NAME" "$REMOTE_URL"
else
  log "adding remote '$REMOTE_NAME' → $REMOTE_URL"
  git remote add "$REMOTE_NAME" "$REMOTE_URL"
fi
git remote -v | sed 's/^/    /'

# ─────────────────────────────────────────────────────────────
# Verify target reachable
# ─────────────────────────────────────────────────────────────
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
# Push
# ─────────────────────────────────────────────────────────────
PUSHED=0; SKIPPED=0; FAILED=0

while IFS= read -r branch; do
  [[ "$branch" == "main" ]] && continue

  if [[ -n "$PREFIX" ]]; then
    dest="${PREFIX}/${branch}"
  else
    dest="${branch}"
  fi

  printf '\033[1;34m[push]\033[0m %-45s → %s ' "$branch" "$dest"

  # Skip if remote already has this ref
  if git ls-remote --exit-code --heads "$REMOTE_NAME" "$dest" >/dev/null 2>&1; then
    printf '\033[1;33m(skip)\033[0m\n'
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    printf '\033[2m(dry)\033[0m\n'
    continue
  fi

  if git push --quiet "$REMOTE_NAME" "refs/heads/$branch:refs/heads/$dest"; then
    printf '\033[1;32mok\033[0m\n'
    PUSHED=$((PUSHED + 1))
  else
    printf '\033[1;31mFAILED\033[0m\n'
    FAILED=$((FAILED + 1))
  fi
done < <(git for-each-ref --format='%(refname:short)' refs/heads | sort)

# Push main under the prefix too
MAIN_DEST="${PREFIX:+$PREFIX/}main"
printf '\033[1;34m[push]\033[0m %-45s → %s ' "main" "$MAIN_DEST"
if git ls-remote --exit-code --heads "$REMOTE_NAME" "$MAIN_DEST" >/dev/null 2>&1; then
  printf '\033[1;33m(skip)\033[0m\n'
  SKIPPED=$((SKIPPED + 1))
elif [[ "$DRY_RUN" == "1" ]]; then
  printf '\033[2m(dry)\033[0m\n'
else
  if git push --quiet "$REMOTE_NAME" "refs/heads/main:refs/heads/$MAIN_DEST"; then
    printf '\033[1;32mok\033[0m\n'
    PUSHED=$((PUSHED + 1))
  else
    printf '\033[1;31mFAILED\033[0m\n'
    FAILED=$((FAILED + 1))
  fi
fi

# ─────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────
echo
ok "push complete"
printf "  pushed:  %d\n" "$PUSHED"
printf "  skipped: %d\n" "$SKIPPED"
printf "  failed:  %d\n" "$FAILED"

if [[ -n "$PREFIX" ]]; then
  printf "  view:    %s/branches/all?query=%s\n" \
    "${REMOTE_URL%.git}" "${PREFIX%%/*}"
else
  printf "  view:    %s/branches/all\n" "${REMOTE_URL%.git}"
fi

[[ "$FAILED" -gt 0 ]] && exit 1