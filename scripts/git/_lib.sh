#!/usr/bin/env bash
# scripts/git/_lib.sh — helpers git communs. À sourcer.
set -euo pipefail

GIT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_LIB_ROOT="$(cd "$GIT_LIB_DIR/../.." && pwd)"

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_RST=""
fi

log()  { printf '%s[git ]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok  ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
die()  { printf '%s[err ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; exit 1; }

git_require_clean() {
  [ -z "$(git status --porcelain)" ] || die "working tree non clean"
}

git_require_remote() {
  git remote get-url origin >/dev/null 2>&1 || die "remote origin absent"
}

git_list_remote_ats_branches() {
  git ls-remote --heads origin 'refs/heads/ats-lab/*' \
    | awk -F'refs/heads/' '{print $2}' | sort -u
}

git_list_local_ats_branches() {
  git for-each-ref --format='%(refname:short)' 'refs/heads/ats-lab/*'
}
