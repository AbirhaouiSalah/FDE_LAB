#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"
LOT=""; FILES=""; MSG=""; CONFIRM=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --lot) LOT="$2"; shift 2 ;;
    --files) FILES="$2"; shift 2 ;;
    --message) MSG="$2"; shift 2 ;;
    --yes|-y) CONFIRM=1; shift ;;
    *) shift ;;
  esac
done
[[ -z "$LOT" || -z "$FILES" || -z "$MSG" ]] && { echo "Usage: $0 --lot X --files 'src/' --message 'msg'"; exit 2; }
ensure_branch "$LOT"; assert_no_out_of_scope "$FILES"
git -C "$REPO_ROOT" add -A -- $FILES 2>/dev/null || true
git -C "$REPO_ROOT" diff --cached --quiet && { log_ok "rien à commiter"; exit 0; }
[[ "$CONFIRM" -ne 1 ]] && { git -C "$REPO_ROOT" diff --cached --stat; read -r "ans?Confirmer [y/N] "; [[ "$ans" == "y" ]] || exit 1; }
commit_and_push "$MSG" "$LOT"
