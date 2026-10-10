#!/usr/bin/env bash
# push-all-branches.sh
# Push every local branch to a remote, optionally under a prefix.
# Attributed to a fixed git identity so GitHub counts contributions.
#
# Usage:
#   ./push-all-branches.sh
#   ./push-all-branches.sh --url git@github.com:USER/REPO.git
#   ./push-all-branches.sh --prefix ats-lab
#   ./push-all-branches.sh --no-prefix
#   ./push-all-branches.sh --force-push
#   ./push-all-branches.sh --dry-run
#
# Safety:
#   - refuses to push with a dirty working tree
#   - verifies the remote is reachable before pushing anything
#   - never uses plain -f (only --force-with-lease, and only with --force-push)
#   - idempotent: branches already on the remote are skipped

set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Defaults
# ─────────────────────────────────────────────────────────────
GIT_USER_NAME="AbirhaouiSalah"
GIT_USER_EMAIL="sabirhaouipro@gmail.com"

REMOTE_NAME="origin"
REMOTE_URL="git@github.com:AbirhaouiSalah/FDE_LAB.git"
PREFIX="ats-lab"
FORCE_PUSH=0
DRY_RUN=0
SKIP_MAIN=0

# ─────────────────────────────────────────────────────────────
# Args
# ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)         REMOTE_URL="${2:-}"; shift 2 ;;
    --remote-name) REMOTE_NAME="${2:-}"; shift 2 ;;
    --prefix)      PREFIX="${2:-}"; shift 2 ;;
    --no-prefix)   PREFIX=""; shift ;;
    --skip-main)   SKIP_MAIN=1; shift ;;
    --force-push)  FORCE_PUSH=1; shift ;;
    --dry-run)     DRY_RUN=1; shift ;;
    -h|--help)
      sed -n '2,16p' "$0"
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

# Refuse if the working tree is dirty
if [[ -n "$(git status --porcelain)" ]]; then
  warn "working tree has uncommitted changes:"
  git status --short | sed 's/^/    /'
  die "commit or stash before pushing"
fi

# ─────────────────────────────────────────────────────────────
# Configure local git identity (repo-scoped)
# ─────────────────────────────────────────────────────────────
log "configuring local git identity"
git config user.name  "$GIT_USER_NAME"
git config user.email "$GIT_USER_EMAIL"
printf '    user.name=%s\n'  "$(git config user.name)"
printf '    user.email=%s\n' "$(git config user.email)"

# ─────────────────────────────────────────────────────────────
# Configure remote
# ─────────────────────────────────────────────────────────────
if git remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
  log "updating remote '$REMOTE_NAME' → $REMOTE_URL"
  git remote set-url "$REMOTE_NAME" "$REMOTE_URL"
else
  log "adding remote '$REMOTE_NAME' → $REMOTE_URL"
  git remote add "$REMOTE_NAME" "$REMOTE_URL"
fi
git remote -v | sed 's/^/    /'

# ─────────────────────────────────────────────────────────────
# Verify remote is reachable
# ─────────────────────────────────────────────────────────────
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

# ─────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────
PUSH_FLAGS=()
[[ "$FORCE_PUSH" == "1" ]] && PUSH_FLAGS+=("--force-with-lease")

remote_has_branch() {
  local dest="$1"
  git ls-remote --exit-code --heads "$REMOTE_NAME" "$dest" >/dev/null 2>&1
}

push_one() {
  local branch="$1"
  local dest="$2"

  printf "${C_BLUE}[push]${C_RESET} %-45s → %-45s " "$branch" "$dest"

  if remote_has_branch "$dest"; then
    if [[ "$FORCE_PUSH" != "1" ]]; then
      printf "${C_YELLOW}(skip)${C_RESET}\n"
      return 2   # skipped
    fi
    # force-push intent: fall through
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    printf "${C_DIM}(dry)${C_RESET}\n"
    return 3   # dry
  fi

  if git push "${PUSH_FLAGS[@]}" --quiet "$REMOTE_NAME" \
        "refs/heads/$branch:refs/heads/$dest"; then
    printf "${C_GREEN}ok${C_RESET}\n"
    return 0   # pushed
  else
    printf "${C_RED}FAILED${C_RESET}\n"
    return 1   # failed
  fi
}

# ─────────────────────────────────────────────────────────────
# Push every local branch
# ─────────────────────────────────────────────────────────────
PUSHED=0
SKIPPED=0
FAILED=0
DRY=0

while IFS= read -r branch; do
  [[ -z "$branch" ]] && continue
  [[ "$branch" == "main" && "$SKIP_MAIN" == "1" ]] && continue

  if [[ -n "$PREFIX" ]]; then
    dest="${PREFIX}/${branch}"
  else
    dest="${branch}"
  fi

  set +e
  push_one "$branch" "$dest"
  rc=$?
  set -e

  case "$rc" in
    0) PUSHED=$((PUSHED + 1)) ;;
    1) FAILED=$((FAILED + 1)) ;;
    2) SKIPPED=$((SKIPPED + 1)) ;;
    3) DRY=$((DRY + 1)) ;;
  esac
done < <(git for-each-ref --format='%(refname:short)' refs/heads | sort)

# ─────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────
echo
ok "push complete"
printf "  pushed:  %d\n" "$PUSHED"
printf "  skipped: %d\n" "$SKIPPED"
printf "  failed:  %d\n" "$FAILED"
[[ "$DRY" -gt 0 ]] && printf "  dry-run: %d\n" "$DRY"

# Build a browser-friendly URL from a git URL
browser_url() {
  local u="$1"
  u="${u%.git}"
  case "$u" in
    git@github.com:*)  printf 'https://github.com/%s\n' "${u#git@github.com:}" ;;
    https://github.com/*) printf '%s\n' "$u" ;;
    *) printf '%s\n' "$u" ;;
  esac
}

URL_BASE="$(browser_url "$REMOTE_URL")"
if [[ -n "$PREFIX" ]]; then
  printf "  view:    %s/branches/all?query=%s\n" "$URL_BASE" "${PREFIX%%/*}"
else
  printf "  view:    %s/branches/all\n" "$URL_BASE"
fi

[[ "$FAILED" -gt 0 ]] && exit 1
exit 0