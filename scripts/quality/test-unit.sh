#!/usr/bin/env bash
# scripts/quality/test-unit.sh [pattern]
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
cd "$Q_LIB_ROOT"

PATTERN="${1:-}"
if [ -t 1 ] && [ -z "${CI:-}" ]; then
  log "Vitest watch${PATTERN:+ — pattern: $PATTERN}"
  if [ -n "$PATTERN" ]; then q_exec vitest "$PATTERN"; else q_exec vitest; fi
else
  log "Vitest run${PATTERN:+ — pattern: $PATTERN}"
  if [ -n "$PATTERN" ]; then q_exec vitest run "$PATTERN"; else q_exec vitest run; fi
fi
