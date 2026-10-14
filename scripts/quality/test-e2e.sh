#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
cd "$Q_LIB_ROOT"

if [ ! -f playwright.config.ts ]; then
  warn "Playwright non configuré — skip"
  exit 0
fi
log "Playwright E2E…"
q_exec playwright test
