#!/usr/bin/env bash
# scripts/ci/ci-report.sh — affiche .ci-reports/<branch>.md local.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
cd "$CI_LIB_ROOT"

BRANCH="$(git branch --show-current | tr '/' '_')"
F=".ci-reports/${BRANCH}.md"
if [ -f "$F" ]; then
  cat "$F"
else
  warn "Aucun rapport pour $BRANCH (fichier $F absent)"
fi
