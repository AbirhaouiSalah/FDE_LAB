#!/usr/bin/env bash
# scripts/git/backup.sh — backup horodaté de l'état git (branches + bundle + working tree).
# Usage: ./scripts/git/backup.sh [<label>]
set -euo pipefail
source "$(dirname "$0")/_lib.sh"

LABEL="${1:-manual}"
TS="$(date +%Y%m%d-%H%M%S)"
DIR=".backups/git-${TS}-${LABEL}"
mkdir -p "$DIR"

log "Backup git → $DIR"
git branch --show-current > "$DIR/current-branch.txt" 2>/dev/null || true
git for-each-ref --format='%(refname) %(objectname:short)' 'refs/heads/*' > "$DIR/local-refs.txt"
git ls-remote --heads origin > "$DIR/remote-refs.txt" 2>/dev/null || true
git diff HEAD > "$DIR/working.diff" 2>/dev/null || true
git diff --cached > "$DIR/staged.diff" 2>/dev/null || true
git ls-files --others --exclude-standard > "$DIR/untracked.txt"
git log --oneline --all --decorate -n 200 > "$DIR/log.txt"
git bundle create "$DIR/repo.bundle" --all >/dev/null 2>&1 || warn "bundle partiel"

ok "Backup dans $DIR"
echo "  Restore : ./scripts/git/restore-backup.sh $DIR"
