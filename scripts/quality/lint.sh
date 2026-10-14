#!/usr/bin/env bash
# scripts/quality/lint.sh [--fix]
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
cd "$Q_LIB_ROOT"

if [ "${1:-}" = "--fix" ]; then
  log "ESLint (fix)…"
  q_exec eslint . --fix
else
  log "ESLint…"
  q_run lint
fi
ok "lint OK"
