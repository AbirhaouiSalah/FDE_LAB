#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
cd "$Q_LIB_ROOT"

if [ -f vitest.a11y.config.ts ]; then
  log "Tests a11y…"
  q_exec vitest run --config vitest.a11y.config.ts
  ok "a11y OK"
else
  warn "vitest.a11y.config.ts absent — skip"
fi
