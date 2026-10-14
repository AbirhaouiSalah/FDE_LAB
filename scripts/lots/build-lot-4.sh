#!/usr/bin/env bash
# scripts/lots/build-lot-4.sh — L4 Shell & Routing
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

LOT_ID="L4"; LOT_TAG="${LOT_ID}"; export LOT_TAG
LOT_BRANCH="ats-lab/comp/shell/app-shell"
LOT_NAME="Shell & Routing"
LOT_FILES="src/app/ src/styles/"
COMMIT_MSG="feat(L4): shell & routing"

parse_common_flags "$@" || true

if command -v check_prereqs >/dev/null 2>&1; then check_prereqs || true; else require_repo_root || true; fi
ensure_branch "${LOT_BRANCH}" || true

log_init "${LOT_ID}"
log_step "${LOT_ID} — ${LOT_NAME}"
log_dim "branche : ${LOT_BRANCH}"
log_dim "files   : ${LOT_FILES}"
log_dim "mode    : $( [ "${DRY_RUN}" = "1" ] && echo DRY-RUN || echo APPLY )"

# ═══════════════════════════════════════════════════════════════════════════
# Fichiers du lot — AJOUTER LES write_file ICI
# ═══════════════════════════════════════════════════════════════════════════
# Exemple :
# write_file "${LOT_FILES}/exemple.ts" <<'FILEEOF'
# ... contenu ...
# FILEEOF

FILES_WRITTEN="$(git -C "$REPO_ROOT" status --porcelain "${LOT_FILES}" 2>/dev/null | wc -l | tr -d ' ')"
lot_summary "${LOT_ID}" "${FILES_WRITTEN:-0}" ""
log_ok "${LOT_ID} — complete"
