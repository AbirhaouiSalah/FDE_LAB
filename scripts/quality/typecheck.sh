#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
cd "$Q_LIB_ROOT"
log "tsc --noEmit…"
q_run typecheck
ok "typecheck OK"
