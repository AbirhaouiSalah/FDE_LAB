#!/usr/bin/env bash
# merge-all-branches-to-main.sh
# Merge every ats-lab/* branch into main as merge commits. Never deletes branches.
# Auto-resolves conflicts using --strategy (default: theirs).
#
# Usage:
#   ./merge-all-branches-to-main.sh              # auto-merge, no push
#   ./merge-all-branches-to-main.sh --push       # auto-merge and push
#   ./merge-all-branches-to-main.sh --dry-run
#   ./merge-all-branches-to-main.sh --strategy ours
#   ./merge-all-branches-to-main.sh --prefix ats-lab
#   ./merge-all-branches-to-main.sh --into main

set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Config
# ─────────────────────────────────────────────────────────────
GIT_USER_NAME="${GIT_USER_NAME:-AbirhaouiSalah}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-sabirhaouipro@gmail.com}"

REMOTE_NAME="origin"
REMOTE_URL="git@github.com:AbirhaouiSalah/FDE_LAB.git"
PREFIX="ats-lab"
INTO_BRANCH="main"
STRATEGY="theirs"       # auto-merge default: prefer incoming branch on conflict
DRY_RUN=0
DO_PUSH=0

# ─────────────────────────────────────────────────────────────
# Args
# ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)     DRY_RUN=1; shift ;;
    --push)        DO_PUSH=1; shift ;;
    --strategy)    STRATEGY="${2:-}"; shift 2 ;;
    --prefix)      PREFIX="${2:-}"; shift 2 ;;
    --into)        INTO_BRANCH="${2:-}"; shift 2 ;;
    --url)         REMOTE_URL="${2:-}"; shift 2 ;;
    --remote)      REMOTE_NAME="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '2,16p' "$0"
      exit 0
      ;;
    *)
      printf 'unexpected arg: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

case "$STRATEGY" in
  ours|theirs|manual) ;;
  *) printf 'invalid --strategy: %s (expected ours|theirs|manual)\n' "$STRATEGY" >&2; exit 1 ;;
esac

# ─────────────────────────────────────────────────────────────
# Colors
# ─────────────────────────────────────────────────────────────
C_RESET="\033[0m"; C_BLUE="\033[1;34m"; C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"; C_RED="\033[1;31m"; C_DIM="\033[2m"
log()  { printf "${C_BLUE}[merge]${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_GREEN}[ ok  ]${C_RESET} %s\n" "$*"; }
warn() { printf "${C_YELLOW}[warn ]${C_RESET} %s\n" "$*"; }
dry()  { printf "${C_DIM}[ dry ]${C_RESET} %s\n" "$*"; }
die()  { printf "${C_RED}[fail ]${C_RESET} %s\n" "$*" >&2; exit 1; }

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

git config user.name  "$GIT_USER_NAME"
git config user.email "$GIT_USER_EMAIL"
log "identity: $GIT_USER_NAME <$GIT_USER_EMAIL>"

if git remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
  log "updating remote '$REMOTE_NAME' → $REMOTE_URL"
  git remote set-url "$REMOTE_NAME" "$REMOTE_URL"
else
  log "adding remote '$REMOTE_NAME' → $REMOTE_URL"
  git remote add "$REMOTE_NAME" "$REMOTE_URL"
fi

log "fetching remote refs"
git fetch --quiet --prune "$REMOTE_NAME" 2>/dev/null || true

if git rev-parse --verify "$REMOTE_NAME/$INTO_BRANCH" >/dev/null 2>&1; then
  INTO_REF="$REMOTE_NAME/$INTO_BRANCH"
elif git rev-parse --verify "$INTO_BRANCH" >/dev/null 2>&1; then
  INTO_REF="$INTO_BRANCH"
else
  die "cannot find '$INTO_BRANCH' locally or on $REMOTE_NAME"
fi
log "target branch: $INTO_REF ($(git rev-parse --short "$INTO_REF"))"

# ─────────────────────────────────────────────────────────────
# Collect branches (bash 3.2-safe)
# ─────────────────────────────────────────────────────────────
BRANCHES=()
while IFS= read -r line; do
  [[ -n "$line" ]] && BRANCHES+=("$line")
done < <(
  git for-each-ref --format='%(refname:short)' "refs/remotes/$REMOTE_NAME/$PREFIX" \
  | sed "s|^$REMOTE_NAME/||" \
  | grep -v "^$PREFIX/$INTO_BRANCH\$" \
  | grep -v "^$PREFIX/$INTO_BRANCH/HEAD\$" \
  | sort
)

[[ ${#BRANCHES[@]} -gt 0 ]] || die "no branches matching '$PREFIX/*' (excluding $PREFIX/$INTO_BRANCH)"
log "found ${#BRANCHES[@]} branches to merge into $INTO_BRANCH"

# ─────────────────────────────────────────────────────────────
# Worktree
# ─────────────────────────────────────────────────────────────
TMP="$(mktemp -d)"
KEEP_WT=0
cleanup() {
  if [[ "$KEEP_WT" == "0" ]]; then
    git worktree remove --force "$TMP/wt" 2>/dev/null || true
    rm -rf "$TMP"
  fi
}
trap cleanup EXIT

log "creating worktree at $TMP/wt"
git worktree add --quiet --detach "$TMP/wt" "$INTO_REF"
WT="$TMP/wt"

git -C "$WT" reset --hard --quiet "$INTO_REF"
git -C "$WT" clean -fdx --quiet
log "worktree ready at $(git -C "$WT" rev-parse --short HEAD)"

# ─────────────────────────────────────────────────────────────
# Merge loop — auto-resolves with strategy
# ─────────────────────────────────────────────────────────────
MERGED=0
SKIPPED=0
AUTO_RESOLVED=0
FAILED=0

for branch in "${BRANCHES[@]}"; do
  short="${branch#"$PREFIX"/}"
  ref="$REMOTE_NAME/$branch"

  if ! git rev-parse --verify "$ref" >/dev/null 2>&1; then
    if git rev-parse --verify "$branch" >/dev/null 2>&1; then
      ref="$branch"
    else
      printf "${C_BLUE}[merge]${C_RESET} %-45s ${C_RED}(ref missing)${C_RESET}\n" "$short"
      FAILED=$((FAILED + 1))
      continue
    fi
  fi

  if git -C "$WT" merge-base --is-ancestor "$ref" HEAD 2>/dev/null; then
    printf "${C_BLUE}[merge]${C_RESET} %-45s ${C_YELLOW}(already merged)${C_RESET}\n" "$short"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  printf "${C_BLUE}[merge]${C_RESET} %-45s " "$short"

  if [[ "$DRY_RUN" == "1" ]]; then
    printf "${C_DIM}(dry - would merge)${C_RESET}\n"
    continue
  fi

  # Attempt merge
  set +e
  git -C "$WT" merge --no-ff --no-edit -m "merge($PREFIX): $short into $INTO_BRANCH" "$ref" >/dev/null 2>&1
  rc=$?
  set -e

  if [[ $rc -eq 0 ]]; then
    printf "${C_GREEN}ok${C_RESET}\n"
    MERGED=$((MERGED + 1))
    continue
  fi

  # Conflict — resolve with strategy
  if [[ "$STRATEGY" == "manual" ]]; then
    printf "${C_RED}(conflict — manual)${C_RESET}\n"
    git -C "$WT" merge --abort >/dev/null 2>&1 || true
    FAILED=$((FAILED + 1))
    continue
  fi

  # Unmerged files list
  UNMERGED="$(git -C "$WT" diff --name-only --diff-filter=U 2>/dev/null || true)"

  if [[ -z "$UNMERGED" ]]; then
    # Not a file conflict — could be an add/add or modify/delete edge
    git -C "$WT" merge --abort >/dev/null 2>&1 || true
    printf "${C_RED}(conflict — unmerged unknown)${C_RESET}\n"
    FAILED=$((FAILED + 1))
    continue
  fi

  # Resolve each unmerged path with the chosen side
  RESOLVED_OK=1
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    set +e
    if [[ "$STRATEGY" == "theirs" ]]; then
      git -C "$WT" checkout --theirs -- "$f" >/dev/null 2>&1
      rc2=$?
    else
      git -C "$WT" checkout --ours -- "$f" >/dev/null 2>&1
      rc2=$?
    fi
    set -e
    if [[ $rc2 -ne 0 ]]; then
      RESOLVED_OK=0
      break
    fi
    git -C "$WT" add -- "$f" >/dev/null 2>&1 || true
  done <<< "$UNMERGED"

  if [[ "$RESOLVED_OK" != "1" ]]; then
    git -C "$WT" merge --abort >/dev/null 2>&1 || true
    printf "${C_RED}(auto-resolve failed)${C_RESET}\n"
    FAILED=$((FAILED + 1))
    continue
  fi

  # Complete the merge
  if git -C "$WT" -c user.name="$GIT_USER_NAME" \
                   -c user.email="$GIT_USER_EMAIL" \
                   commit --no-edit --quiet >/dev/null 2>&1; then
    printf "${C_GREEN}ok (auto-resolved: $STRATEGY)${C_RESET}\n"
    MERGED=$((MERGED + 1))
    AUTO_RESOLVED=$((AUTO_RESOLVED + 1))
  else
    git -C "$WT" merge --abort >/dev/null 2>&1 || true
    printf "${C_RED}(commit failed)${C_RESET}\n"
    FAILED=$((FAILED + 1))
  fi
done

# ─────────────────────────────────────────────────────────────
# Push
# ─────────────────────────────────────────────────────────────
echo
if [[ "$DRY_RUN" == "1" ]]; then
  warn "dry-run — nothing pushed"
elif [[ "$DO_PUSH" != "1" ]]; then
  warn "not pushing (pass --push to publish)"
  log "local merge HEAD: $(git -C "$WT" rev-parse --short HEAD)"
  KEEP_WT=1
  trap - EXIT
  log "worktree left at: $WT"
  log "inspect: git -C $WT log --oneline --graph -30"
  log "remove:  git worktree remove --force $WT"
  exit 0
else
  log "pushing $INTO_BRANCH to $REMOTE_NAME"
  if git -C "$WT" push --quiet "$REMOTE_NAME" "HEAD:refs/heads/$INTO_BRANCH"; then
    ok "pushed $INTO_BRANCH"
  else
    die "push failed (remote may have diverged — pull and retry)"
  fi
fi

# ─────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────
echo
ok "merge complete"
printf "  merged:        %d\n" "$MERGED"
printf "  auto-resolved: %d\n" "$AUTO_RESOLVED"
printf "  skipped:       %d\n" "$SKIPPED"
printf "  failed:        %d\n" "$FAILED"
printf "  strategy:      %s\n" "$STRATEGY"

URL_BASE="${REMOTE_URL%.git}"
URL_BASE="${URL_BASE/git@github.com:/https://github.com/}"
printf "  view:          %s/commits/%s\n" "$URL_BASE" "$INTO_BRANCH"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
