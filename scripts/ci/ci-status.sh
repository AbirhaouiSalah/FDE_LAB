#!/usr/bin/env bash
# scripts/ci/ci-status.sh — dernier run CI pour la branche courante (gh CLI requis).
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
cd "$CI_LIB_ROOT"

if ! command -v gh >/dev/null 2>&1; then
  warn "gh CLI absent — installe-le pour utiliser ce script"
  exit 0
fi

BRANCH="$(git branch --show-current)"
log "Dernier run CI pour '$BRANCH' :"
gh run list --branch "$BRANCH" --limit 5
