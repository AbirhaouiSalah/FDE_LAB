cat > diagnose.sh <<'SCRIPT_EOF'
#!/usr/bin/env bash
# diagnose.sh
# Collects a complete snapshot of local + remote + CI state for the ATS Copilot repo.
# Output is safe to paste into an issue or share with another engineer.
#
# Usage:
#   ./diagnose.sh                 # interactive summary
#   ./diagnose.sh --full          # include file listings
#   ./diagnose.sh --remote URL    # inspect a different remote
#   ./diagnose.sh --quiet         # minimal output
#
# Writes: .diagnostics/<timestamp>/report.md

set -uo pipefail

# ─────────────────────────────────────────────────────────────
# Config
# ─────────────────────────────────────────────────────────────
REMOTE_NAME="origin"
REMOTE_PREFIX="ats-lab"
WORKFLOW_PATH=".github/workflows/dashboard-ci.yml"
FULL=0
QUIET=0
REMOTE_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --full)   FULL=1; shift ;;
    --quiet)  QUIET=1; shift ;;
    --remote) REMOTE_OVERRIDE="${2:-}"; shift 2 ;;
    --prefix) REMOTE_PREFIX="${2:-}"; shift 2 ;;
    --remote-name) REMOTE_NAME="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '2,12p' "$0"; exit 0 ;;
    *) printf 'unexpected arg: %s\n' "$1" >&2; exit 1 ;;
  esac
done

# ─────────────────────────────────────────────────────────────
# Logging
# ─────────────────────────────────────────────────────────────
C_RESET="\033[0m"; C_BLUE="\033[1;34m"; C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"; C_RED="\033[1;31m"; C_DIM="\033[2m"
say()  { [[ "$QUIET" == "1" ]] && return; printf "${C_BLUE}[diag]${C_RESET} %s\n" "$*"; }
good() { [[ "$QUIET" == "1" ]] && return; printf "${C_GREEN}[  ok ]${C_RESET} %s\n" "$*"; }
bad()  { [[ "$QUIET" == "1" ]] && return; printf "${C_RED}[ fail]${C_RESET} %s\n" "$*"; }
warn() { [[ "$QUIET" == "1" ]] && return; printf "${C_YELLOW}[ warn]${C_RESET} %s\n" "$*"; }

# ─────────────────────────────────────────────────────────────
# Output target
# ─────────────────────────────────────────────────────────────
TS="$(date -u +%Y%m%d-%H%M%S)"
OUTDIR=".diagnostics/$TS"
mkdir -p "$OUTDIR"
REPORT="$OUTDIR/report.md"

# Also print a copy to terminal
TEE() { tee -a "$REPORT"; }

# Header
{
  echo "# ATS Copilot — Diagnostics"
  echo ""
  echo "- **Timestamp:** $TS (UTC)"
  echo "- **Hostname:** $(hostname)"
  echo "- **User:** $(whoami)"
  echo "- **CWD:** $(pwd)"
  echo ""
  echo '```'
  echo "uname:  $(uname -a)"
  echo "bash:   $(bash --version | head -1)"
  echo "zsh:    $(zsh --version 2>/dev/null || echo 'n/a')"
  echo "git:    $(git --version)"
  echo "node:   $(node --version 2>/dev/null || echo 'n/a')"
  echo "pnpm:   $(pnpm --version 2>/dev/null || echo 'n/a')"
  echo '```'
  echo ""
} > "$REPORT"

# ─────────────────────────────────────────────────────────────
# Section helper
# ─────────────────────────────────────────────────────────────
section() {
  local title="$1"
  {
    echo ""
    echo "## $title"
    echo ""
  } | TEE
  say "$title"
}

codeblock() {
  echo '```' | TEE
  "$@" 2>&1 | TEE
  local rc=${PIPESTATUS[0]}
  echo '```' | TEE
  return $rc
}

# ─────────────────────────────────────────────────────────────
# 1. Repo detection
# ─────────────────────────────────────────────────────────────
section "1. Repository"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  good "git repo detected: $REPO_ROOT"
  cd "$REPO_ROOT"
  {
    echo "- Repo root: \`$REPO_ROOT\`"
    echo "- Current branch: \`$(git branch --show-current)\`"
    echo "- HEAD: \`$(git rev-parse HEAD)\`"
    echo "- HEAD short: \`$(git rev-parse --short HEAD)\`"
    echo "- Last commit: $(git log -1 --pretty=format:'%h %an <%ae> — %s (%ar)')"
  } | TEE
else
  bad "not inside a git repository"
  echo "- **Error:** Not a git repo" | TEE
  exit 1
fi

# ─────────────────────────────────────────────────────────────
# 2. Working tree status
# ─────────────────────────────────────────────────────────────
section "2. Working tree status"

DIRTY="$(git status --porcelain)"
if [[ -z "$DIRTY" ]]; then
  good "clean"
  echo "- **Status:** clean ✅" | TEE
else
  warn "uncommitted changes present"
  echo "- **Status:** dirty ⚠️" | TEE
  echo "" | TEE
  codeblock git status --short
fi

# ─────────────────────────────────────────────────────────────
# 3. Local branches
# ─────────────────────────────────────────────────────────────
section "3. Local branches"

LOCAL_COUNT="$(git for-each-ref --format='%(refname:short)' refs/heads | wc -l | tr -d ' ')"
echo "- Count: **$LOCAL_COUNT**" | TEE
echo "" | TEE
codeblock bash -c "git branch --format='%(refname:short) %(objectname:short) %(upstream:short)'"

# ─────────────────────────────────────────────────────────────
# 4. Remote configuration
# ─────────────────────────────────────────────────────────────
section "4. Remote configuration"

codeblock git remote -v

if [[ -n "$REMOTE_OVERRIDE" ]]; then
  say "checking custom remote: $REMOTE_OVERRIDE"
  codeblock git ls-remote --exit-code --heads "$REMOTE_OVERRIDE"
fi

# ─────────────────────────────────────────────────────────────
# 5. Remote reachability
# ─────────────────────────────────────────────────────────────
section "5. Remote reachability"

set +e
LS_OUT="$(git ls-remote --exit-code "$REMOTE_NAME" 2>&1)"
LS_RC=$?
set -e

if [[ $LS_RC -eq 0 ]]; then
  good "$REMOTE_NAME reachable"
  echo "- \`$REMOTE_NAME\` reachable ✅ (rc=$LS_RC)" | TEE
else
  bad "$REMOTE_NAME NOT reachable (rc=$LS_RC)"
  echo "- \`$REMOTE_NAME\` NOT reachable ❌ (rc=$LS_RC)" | TEE
  echo "" | TEE
  codeblock bash -c "printf '%s' '$LS_OUT'"
fi

# SSH check if it's an SSH URL
REMOTE_URL="$(git remote get-url "$REMOTE_NAME" 2>/dev/null || true)"
if [[ "$REMOTE_URL" =~ ^git@github\.com ]]; then
  say "checking SSH auth to github.com"
  SSH_OUT="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)"
  if [[ "$SSH_OUT" =~ [Ss]uccessfully\ authenticated ]] || [[ "$SSH_OUT" =~ ^Hi\ [A-Za-z0-9_-]+! ]]; then
    good "SSH ok: $SSH_OUT"
    echo "- SSH: ✅ $SSH_OUT" | TEE
  else
    bad "SSH inconclusive"
    echo "- SSH: ❌ inconclusive" | TEE
    codeblock bash -c "printf '%s' '$SSH_OUT'"
  fi
fi

# ─────────────────────────────────────────────────────────────
# 6. Remote branches (prefix-scoped)
# ─────────────────────────────────────────────────────────────
section "6. Remote branches under '$REMOTE_PREFIX/*'"

git fetch --quiet --prune "$REMOTE_NAME" 2>/dev/null || true

REMOTE_BRANCHES_FILE="$OUTDIR/remote-branches.txt"
git ls-remote --heads "$REMOTE_NAME" "refs/heads/$REMOTE_PREFIX/*" 2>/dev/null \
  | sort > "$REMOTE_BRANCHES_FILE" || true

REMOTE_COUNT="$(wc -l < "$REMOTE_BRANCHES_FILE" | tr -d ' ')"
echo "- Count: **$REMOTE_COUNT**" | TEE
echo "" | TEE

if [[ "$FULL" == "1" ]]; then
  codeblock cat "$REMOTE_BRANCHES_FILE"
else
  echo '```' | TEE
  head -40 "$REMOTE_BRANCHES_FILE" | TEE
  [[ "$REMOTE_COUNT" -gt 40 ]] && echo "... ($((REMOTE_COUNT - 40)) more)" | TEE
  echo '```' | TEE
fi

# ─────────────────────────────────────────────────────────────
# 7. Divergence between local and remote
# ─────────────────────────────────────────────────────────────
section "7. Divergence local ↔ remote"

DIVERGENCE="$OUTDIR/divergence.txt"
: > "$DIVERGENCE"

if [[ -n "$REMOTE_PREFIX" ]]; then
  while IFS= read -r branch; do
    [[ -z "$branch" ]] && continue

    remote_ref="$REMOTE_NAME/$REMOTE_PREFIX/$branch"
    if git show-ref --verify --quiet "refs/remotes/$remote_ref"; then
      local_sha="$(git rev-parse "$branch" 2>/dev/null || echo MISSING)"
      remote_sha="$(git rev-parse "$remote_ref" 2>/dev/null || echo MISSING)"
      if [[ "$local_sha" == "$remote_sha" ]]; then
        echo "SYNCED  $branch ($local_sha)" >> "$DIVERGENCE"
      else
        echo "DIFF    $branch  local=$local_sha  remote=$remote_sha" >> "$DIVERGENCE"
      fi
    else
      echo "MISSING $branch (remote has no $REMOTE_PREFIX/$branch)" >> "$DIVERGENCE"
    fi
  done < <(git for-each-ref --format='%(refname:short)' refs/heads | sort)
fi

SYNCED="$(grep -c '^SYNCED'  "$DIVERGENCE" 2>/dev/null || echo 0)"
DIFF="$(grep -c '^DIFF'      "$DIVERGENCE" 2>/dev/null || echo 0)"
MISSING="$(grep -c '^MISSING' "$DIVERGENCE" 2>/dev/null || echo 0)"

{
  echo "- Synced:  **$SYNCED**"
  echo "- Diff:    **$DIFF**"
  echo "- Missing: **$MISSING**"
  echo ""
  echo '```'
  cat "$DIVERGENCE"
  echo '```'
} | TEE

# ─────────────────────────────────────────────────────────────
# 8. Workflow file presence
# ─────────────────────────────────────────────────────────────
section "8. Workflow file presence"

WF_REPORT="$OUTDIR/workflow-presence.txt"
: > "$WF_REPORT"

while IFS= read -r branch; do
  [[ -z "$branch" ]] && continue
  remote_ref="$REMOTE_PREFIX/$branch"

  if git cat-file -e "$REMOTE_NAME/$remote_ref:$WORKFLOW_PATH" 2>/dev/null; then
    blob="$(git rev-parse "$REMOTE_NAME/$remote_ref:$WORKFLOW_PATH" 2>/dev/null || echo '?')"
    echo "PRESENT  $remote_ref  blob=$blob" >> "$WF_REPORT"
  else
    echo "ABSENT   $remote_ref" >> "$WF_REPORT"
  fi
done < <(git for-each-ref --format='%(refname:short)' refs/heads | sort)

PRESENT="$(grep -c '^PRESENT' "$WF_REPORT" 2>/dev/null || echo 0)"
ABSENT="$(grep -c '^ABSENT'  "$WF_REPORT" 2>/dev/null || echo 0)"

{
  echo "- Present: **$PRESENT**"
  echo "- Absent:  **$ABSENT**"
  echo ""
  echo '```'
  cat "$WF_REPORT"
  echo '```'
} | TEE

# ─────────────────────────────────────────────────────────────
# 9. Commits per branch (last 3)
# ─────────────────────────────────────────────────────────────
section "9. Recent commits per branch"

COMMITS="$OUTDIR/commits.txt"
: > "$COMMITS"

while IFS= read -r branch; do
  [[ -z "$branch" ]] && continue
  {
    echo "--- $branch"
    git log --oneline -3 "$branch" 2>/dev/null || echo "  (no commits)"
    echo ""
  } >> "$COMMITS"
done < <(git for-each-ref --format='%(refname:short)' refs/heads | sort)

if [[ "$FULL" == "1" ]]; then
  codeblock cat "$COMMITS"
else
  echo "- Written to: \`$COMMITS\`" | TEE
fi

# ─────────────────────────────────────────────────────────────
# 10. GitHub Actions runs (if gh CLI available)
# ─────────────────────────────────────────────────────────────
section "10. GitHub Actions status"

if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    say "gh CLI available, fetching workflow runs"
    codeblock bash -c "gh run list --limit 10 2>&1 || true"
  else
    warn "gh CLI not authenticated (run: gh auth login)"
    echo "- gh CLI not authenticated" | TEE
  fi
else
  warn "gh CLI not installed (optional: brew install gh)"
  echo "- gh CLI not installed" | TEE
  echo "- To inspect runs: https://github.com/AbirhaouiSalah/FDE_LAB/actions" | TEE
fi

# ─────────────────────────────────────────────────────────────
# 11. CI workflow file content (from source ref)
# ─────────────────────────────────────────────────────────────
section "11. Workflow file content ($WORKFLOW_PATH from main)"

if git cat-file -e "main:$WORKFLOW_PATH" 2>/dev/null; then
  SIZE="$(git cat-file -s "main:$WORKFLOW_PATH")"
  echo "- Size: $SIZE bytes" | TEE
  echo "" | TEE
  if [[ "$FULL" == "1" ]]; then
    codeblock bash -c "git show main:$WORKFLOW_PATH"
  else
    echo '```yaml' | TEE
    git show "main:$WORKFLOW_PATH" | head -20 | TEE
    echo '...' | TEE
    echo '```' | TEE
  fi
else
  bad "not present on main"
  echo "- ❌ Not found on branch \`main\`" | TEE
fi

# ─────────────────────────────────────────────────────────────
# 12. Common issues
# ─────────────────────────────────────────────────────────────
section "12. Common issues (auto-detected)"

ISSUES=0

# Dirty tree
if [[ -n "$DIRTY" ]]; then
  warn "working tree is dirty"
  echo "- ⚠️ Working tree dirty → \`git status\`" | TEE
  ISSUES=$((ISSUES + 1))
fi

# Not on main
CURRENT="$(git branch --show-current)"
if [[ "$CURRENT" != "main" ]]; then
  warn "not on main branch (on: $CURRENT)"
  echo "- ⚠️ On branch \`$CURRENT\` (not \`main\`)" | TEE
  ISSUES=$((ISSUES + 1))
fi

# Remote unreachable
if [[ $LS_RC -ne 0 ]]; then
  bad "remote unreachable"
  echo "- ❌ Remote \`$REMOTE_NAME\` unreachable → check URL / SSH key" | TEE
  ISSUES=$((ISSUES + 1))
fi

# Workflow missing on some branches
if [[ "$ABSENT" -gt 0 ]]; then
  warn "workflow absent on $ABSENT branch(es)"
  echo "- ⚠️ Workflow absent on $ABSENT branch(es) → run \`./push-to-all-branches.sh --file-only\`" | TEE
  ISSUES=$((ISSUES + 1))
fi

# Divergence
if [[ "$DIFF" -gt 0 ]] || [[ "$MISSING" -gt 0 ]]; then
  warn "$DIFF divergent, $MISSING missing"
  echo "- ⚠️ $DIFF branch(es) differ from remote, $MISSING missing" | TEE
  echo "     → run \`./push-to-all-branches.sh --with-file --force-push\`" | TEE
  ISSUES=$((ISSUES + 1))
fi

# No issues
if [[ "$ISSUES" -eq 0 ]]; then
  good "no common issues detected"
  echo "- ✅ No common issues detected" | TEE
fi

# ─────────────────────────────────────────────────────────────
# 13. Recommended next command
# ─────────────────────────────────────────────────────────────
section "13. Recommended next command"

REC=""
if [[ -n "$DIRTY" ]]; then
  REC="git add -A && git commit -m 'chore: checkpoint'"
elif [[ $LS_RC -ne 0 ]]; then
  REC="ssh -T git@github.com  # verify SSH, then retry"
elif [[ "$ABSENT" -gt 0 ]]; then
  REC="./push-to-all-branches.sh --file-only"
elif [[ "$DIFF" -gt 0 ]] || [[ "$MISSING" -gt 0 ]]; then
  REC="./push-to-all-branches.sh --with-file --force-push"
else
  REC="./push-to-all-branches.sh --with-file --dry-run"
fi

echo '```' | TEE
echo "$REC" | TEE
echo '```' | TEE

# ─────────────────────────────────────────────────────────────
# Wrap up
# ─────────────────────────────────────────────────────────────
{
  echo ""
  echo "---"
  echo ""
  echo "_Report saved to: \`$REPORT\`_"
} >> "$REPORT"

echo
good "report saved to $REPORT"
echo
echo "To share this with another engineer:"
echo "  cat $REPORT"
echo
echo "Or upload it:"
echo "  gh gist create $REPORT"
SCRIPT_EOF