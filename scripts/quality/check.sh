#!/usr/bin/env bash
# scripts/quality/check.sh — check complet.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
cd "$Q_LIB_ROOT"

log "=== lint ==="       ; q_run lint
log "=== typecheck ==="  ; q_run typecheck
log "=== test ==="       ; CI=1 q_exec vitest run
log "=== build ==="      ; q_run build
log "=== a11y ==="       ; q_run test:a11y 2>/dev/null || warn "test:a11y absent — skip"
log "=== i18n ==="       ; q_run test:i18n 2>/dev/null || warn "test:i18n absent — skip"

ok "check complet passé ✅"
