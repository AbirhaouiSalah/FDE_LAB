#!/usr/bin/env bash
# publish-to-fde-lab.sh
# Push local branches of ats-copilot-dashboard into the FDE_LAB GitHub repo
# under an "ats-lab/" prefix, without disturbing FDE_LAB's existing branches.
#
# Usage:
#   ./publish-to-fde-lab.sh
#   ./publish-to-fde-lab.sh --prefix ats-lab
#   ./publish-to-fde-lab.sh --url git@github.com:USER/REPO.git
#   ./publish-to-fde-lab.sh --dry-run

set -euo pipefail

PREFIX="ats-lab"
REMOTE_URL="git@github.com:AbirhaouiSalah/FDE_LAB.git"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)/ats-copilot-dashboard"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)  PREFIX="${2:-}"; shift 2 ;;
    --url)     REMOTE_URL="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) printf 'unexpected arg: %s\n' "$1" >&2; exit 1 ;;
  esac
done

log()  { printf '[publish] %s\n' "$*"; }
ok()   { printf '[  ok   ] %s\n' "$*"; }
warn() { printf '[ warn  ] %s\n' "$*"; }
die()  { printf '[ fail  ] %s\n' "$*" >&2; exit 1; }

[[ -d "$SRC_DIR/.git" ]] || die "source repo not found: $SRC_DIR"
[[ -n "$PREFIX" ]] || die "prefix must not be empty"

log "source: $SRC_DIR"
log "target: $REMOTE_URL"
log "prefix: $PREFIX/"

# Clean source required
if [[ -n "$(cd "$SRC_DIR" && git status --porcelain)" ]]; then
  warn "source repo has uncommitted changes:"
  (cd "$SRC_DIR" && git status --short | sed 's/^/    /')
  die "commit or stash first"
fi

# Verify target reachable
log "checking target repo reachability"
if ! git ls-remote --exit-code "$REMOTE_URL" >/dev/null 2>&1; then
  die "cannot reach $REMOTE_URL — check URL / SSH key / repo existence"
fi
ok "target reachable"

# Temp clone
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
log "cloning target into $TMP"
git clone --quiet "$REMOTE_URL" "$TMP/target"
cd "$TMP/target"

# Fetch source branches
log "fetching source branches"
git remote add src "$SRC_DIR"
git fetch --quiet src '+refs/heads/*:refs/remotes/src/*'

# Push each branch under prefix
PUSHED=0; SKIPPED=0; FAILED=0

while IFS= read -r ref; do
  b="${ref#refs/remotes/src/}"
  [[ "$b" == "HEAD" ]] && continue

  dest="${PREFIX}/${b}"

  # Skip if remote already has this branch
  if git ls-remote --exit-code --heads origin "$dest" >/dev/null 2>&1; then
    warn "already on remote — skip: $dest"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  printf '  %-45s → %s ... ' "$b" "$dest"

  if [[ "$DRY_RUN" == "1" ]]; then
    printf 'dry\n'
    continue
  fi

  if git push --quiet origin "$ref:refs/heads/$dest"; then
    printf 'ok\n'
    PUSHED=$((PUSHED + 1))
  else
    printf 'FAILED\n'
    FAILED=$((FAILED + 1))
  fi
done < <(git for-each-ref --format='%(refname)' refs/remotes/src | sort)

echo
ok "publish complete"
printf "  pushed:  %d\n" "$PUSHED"
printf "  skipped: %d\n" "$SKIPPED"
printf "  failed:  %d\n" "$FAILED"
printf "  view:    https://github.com/AbirhaouiSalah/FDE_LAB/branches/all\n"

[[ "$FAILED" -gt 0 ]] && exit 1