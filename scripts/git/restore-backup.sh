#!/usr/bin/env bash
# scripts/git/restore-backup.sh <dir> — restaure les refs d'un backup dans refs/restored/*.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"

DIR="${1:-}"
[ -n "$DIR" ] || die "usage: $0 <backup-dir>"
[ -d "$DIR" ] || die "dossier introuvable: $DIR"
[ -f "$DIR/repo.bundle" ] || die "repo.bundle absent dans $DIR"

warn "Cette opération ajoute des refs dans refs/restored/* (aucun écrasement)."
git fetch "$DIR/repo.bundle" 'refs/*:refs/restored/*' --force
ok "Refs restaurées dans refs/restored/*"
echo "  Exemple : git branch <name> refs/restored/heads/<branch>"
