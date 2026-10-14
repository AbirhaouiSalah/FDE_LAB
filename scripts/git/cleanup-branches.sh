#!/usr/bin/env bash
# scripts/cleanup-branches.sh (v3)
#
# Nettoie l'état du repo après les opérations sync/merge:
#   1. Worktrees résiduels (.sync-worktrees, .align-worktrees, .push-worktrees, etc.)
#   2. Branches locales temporaires (sync-tmp-*, align-tmp-*, push-tmp-*, mod-tmp-*)
#   3. Branches locales orphelines (sans équivalent remote)
#   4. Branches locales "nu" (comp/*, feat/* sans préfixe ats-lab/)
#   5. Backups locales anciennes (garde les N plus récentes)
#   6. Branches distantes temporaires (option --remote)
#   7. Fichiers non traqués parasites
#
# Usage:
#   ./scripts/cleanup-branches.sh                    # dry-run (défaut)
#   ./scripts/cleanup-branches.sh --yes              # exécute
#   ./scripts/cleanup-branches.sh --keep-backups 3   # garde les 3 backups les plus récentes
#   ./scripts/cleanup-branches.sh --keep-backups 0   # supprime toutes les backups locales
#   ./scripts/cleanup-branches.sh --remote           # nettoie aussi les branches distantes
#   ./scripts/cleanup-branches.sh --no-orphans       # ne supprime PAS les branches orphelines
#   ./scripts/cleanup-branches.sh --help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT_DIR"

# Force head BSD (macOS) au lieu du head Perl
HEAD_BIN="/usr/bin/head"
[ -x "$HEAD_BIN" ] || HEAD_BIN="head"
head_n() { "$HEAD_BIN" -n "$1"; }

# ─── Options ───────────────────────────────────────────────────────────────
DRY_RUN=1
KEEP_BACKUPS=5
CLEAN_REMOTE=0
CLEAN_ORPHANS=1

while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y)         DRY_RUN=0 ;;
    --dry-run)        DRY_RUN=1 ;;
    --keep-backups)   shift; KEEP_BACKUPS="${1:?--keep-backups requiert un nombre}" ;;
    --remote)         CLEAN_REMOTE=1 ;;
    --no-orphans)     CLEAN_ORPHANS=0 ;;
    -h|--help)
      sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) printf 'Argument inconnu: %s\n' "$1" >&2; exit 1 ;;
  esac
  shift
done

# ─── Couleurs ──────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_CYA=$'\033[0;36m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_CYA=""; C_DIM=""; C_RST=""
fi
log()  { printf '%s[clean]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok   ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn ]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
err()  { printf '%s[err  ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; }
info() { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RST"; }
sep()  { printf '%s%s%s\n' "$C_DIM" "════════════════════════════════════════════════════════════════" "$C_RST"; }
sub()  { printf '%s%s%s\n' "$C_DIM" "────────────────────────────────────────────────────────────────" "$C_RST"; }

# ─── Préflight ─────────────────────────────────────────────────────────────
[ -d .git ] || { err "Pas dans un dépôt git"; exit 1; }

MODE_LABEL="[DRY-RUN]"
[ "$DRY_RUN" -eq 0 ] && MODE_LABEL="[EXECUTE]"

log "Mode: $MODE_LABEL"
log "Répertoire: $ROOT_DIR"
log "Garder les $KEEP_BACKUPS backups locales les plus récentes"
if [ "$CLEAN_REMOTE" -eq 1 ]; then
  log "Nettoyage remote: ACTIVÉ"
else
  log "Nettoyage remote: désactivé (--remote pour activer)"
fi
if [ "$CLEAN_ORPHANS" -eq 1 ]; then
  log "Suppression des branches orphelines: ACTIVÉE"
else
  log "Suppression des branches orphelines: désactivée"
fi

# ─── État initial ──────────────────────────────────────────────────────────
sep
echo "  ÉTAT INITIAL"
sep
echo ""

echo "Branche courante: $(git branch --show-current)"
echo "Working tree:"
if [ -z "$(git status --porcelain)" ]; then
  echo "  clean"
else
  git status --short 2>/dev/null | head_n 20
fi
echo ""

# S'assurer qu'on n'est pas sur une branche qu'on va supprimer
CURRENT_BRANCH="$(git branch --show-current)"
if [ "$CURRENT_BRANCH" != "main" ] && [ "$CURRENT_BRANCH" != "master" ]; then
  info "Bascule sur main avant nettoyage…"
  if [ "$DRY_RUN" -eq 0 ]; then
    git checkout main >/dev/null 2>&1 || git checkout master >/dev/null 2>&1 || true
  fi
fi

# ─── 1. Worktrees résiduels ────────────────────────────────────────────────
sep
echo "  1. WORKTREES RÉSIDUELS"
sep
echo ""

WORKTREE_COUNT=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  WT_PATH="$(printf '%s' "$line" | awk '{print $1}')"
  [ "$WT_PATH" = "$ROOT_DIR" ] && continue
  case "$WT_PATH" in
    */.sync-worktrees/*|*/.align-worktrees/*|*/.push-worktrees/*|*/.modify-worktrees/*|*/tmp/*|*/test-wt|*/merge-test)
      echo "  → $WT_PATH"
      WORKTREE_COUNT=$((WORKTREE_COUNT+1))
      if [ "$DRY_RUN" -eq 0 ]; then
        git worktree remove --force "$WT_PATH" 2>/dev/null && ok "    retiré" || warn "    échec"
      fi
      ;;
  esac
done < <(git worktree list --porcelain | grep '^worktree ' | sed 's/^worktree //')

if [ "$WORKTREE_COUNT" -eq 0 ]; then
  ok "Aucun worktree résiduel"
else
  log "$WORKTREE_COUNT worktree(s) à nettoyer"
fi
echo ""

# Dossiers orphelins
for d in .sync-worktrees .align-worktrees .push-worktrees .modify-worktrees; do
  if [ -d "$d" ]; then
    echo "  → dossier orphelin: $d"
    if [ "$DRY_RUN" -eq 0 ]; then
      rm -rf "$d"
      ok "    supprimé"
    fi
  fi
done
echo ""

# ─── 2. Branches locales temporaires ───────────────────────────────────────
sep
echo "  2. BRANCHES LOCALES TEMPORAIRES"
sep
echo ""

TEMP_PATTERNS=(
  'sync-tmp-*'
  'align-tmp-*'
  'push-tmp-*'
  'mod-tmp-*'
  'test-sync'
  'merge-test'
  'test-*'
)

TEMP_COUNT=0
for pattern in "${TEMP_PATTERNS[@]}"; do
  while IFS= read -r b; do
    [ -z "$b" ] && continue
    # Skip les branches "officielles"
    case "$b" in
      ats-lab/*|main|master|develop|staging|production|backup/*) continue ;;
    esac
    echo "  → $b"
    TEMP_COUNT=$((TEMP_COUNT+1))
    if [ "$DRY_RUN" -eq 0 ]; then
      git branch -D "$b" 2>/dev/null && ok "    supprimée" || warn "    échec"
    fi
  done < <(git branch --list "$pattern" 2>/dev/null | sed 's/^[* ] *//')
done

if [ "$TEMP_COUNT" -eq 0 ]; then
  ok "Aucune branche temporaire locale"
else
  log "$TEMP_COUNT branche(s) temporaire(s) locale(s)"
fi
echo ""

# ─── 3. Branches locales orphelines (sans remote) ──────────────────────────
if [ "$CLEAN_ORPHANS" -eq 1 ]; then
  sep
  echo "  3. BRANCHES LOCALES ORPHELINES (sans équivalent remote)"
  sep
  echo ""

  # Récupérer la liste des branches remote
  REMOTE_BRANCHES=$(git ls-remote --heads origin 2>/dev/null \
                    | awk -F'refs/heads/' '{print $2}' || true)

  ORPHAN_COUNT=0
  while IFS= read -r b; do
    [ -z "$b" ] && continue
    # Skip les branches protégées
    case "$b" in
      main|master|develop|staging|production) continue ;;
      ats-lab/*) continue ;;
      backup/*) continue ;;
    esac

    # Vérifier si la branche existe sur origin
    if [ -n "$REMOTE_BRANCHES" ] && printf '%s\n' "$REMOTE_BRANCHES" | grep -qx "$b"; then
      continue
    fi

    echo "  → $b (locale uniquement)"
    ORPHAN_COUNT=$((ORPHAN_COUNT+1))
    if [ "$DRY_RUN" -eq 0 ]; then
      git branch -D "$b" 2>/dev/null && ok "    supprimée" || warn "    échec"
    fi
  done < <(git branch --format='%(refname:short)' 2>/dev/null)

  if [ "$ORPHAN_COUNT" -eq 0 ]; then
    ok "Aucune branche locale orpheline"
  else
    log "$ORPHAN_COUNT branche(s) orpheline(s)"
  fi
  echo ""
else
  info "  (Section orphelines désactivée — utilise --no-orphans pour la désactiver définitivement)"
  echo ""
fi

# ─── 4. Backups locales anciennes ──────────────────────────────────────────
sep
echo "  4. BACKUPS LOCALES (garder les $KEEP_BACKUPS plus récentes)"
sep
echo ""

BACKUPS=()
while IFS= read -r b; do
  [ -z "$b" ] && continue
  BACKUPS+=("$b")
done < <(git branch --list 'backup/*' 2>/dev/null | sed 's/^[* ] *//' | sort -r)

echo "Backups trouvées (${#BACKUPS[@]}):"
for b in "${BACKUPS[@]+"${BACKUPS[@]}"}"; do
  echo "  - $b"
done
echo ""

if [ "${#BACKUPS[@]}" -gt "$KEEP_BACKUPS" ]; then
  TO_DELETE=()
  i=0
  for b in "${BACKUPS[@]}"; do
    i=$((i+1))
    [ "$i" -gt "$KEEP_BACKUPS" ] && TO_DELETE+=("$b")
  done

  log "${#TO_DELETE[@]} backup(s) à supprimer:"
  for b in "${TO_DELETE[@]}"; do
    echo "  → $b"
    if [ "$DRY_RUN" -eq 0 ]; then
      git branch -D "$b" 2>/dev/null && ok "    supprimée" || warn "    échec"
    fi
  done
else
  ok "Toutes les backups sont conservées (≤ $KEEP_BACKUPS)"
fi
echo ""

# ─── 5. Branches distantes temporaires ─────────────────────────────────────
if [ "$CLEAN_REMOTE" -eq 1 ]; then
  sep
  echo "  5. BRANCHES DISTANTES TEMPORAIRES"
  sep
  echo ""

  log "Fetch origin…"
  git fetch origin --prune 2>/dev/null || warn "Fetch échoué"

  REMOTE_TEMP=()
  while IFS= read -r b; do
    [ -z "$b" ] && continue
    case "$b" in
      *sync-tmp-*|*align-tmp-*|*push-tmp-*|*mod-tmp-*|*/test-*|*/test-sync|*/merge-test)
        REMOTE_TEMP+=("$b")
        ;;
    esac
  done < <(git ls-remote --heads origin 2>/dev/null | awk -F'refs/heads/' '{print $2}')

  if [ "${#REMOTE_TEMP[@]}" -eq 0 ]; then
    ok "Aucune branche distante temporaire"
  else
    log "${#REMOTE_TEMP[@]} branche(s) distante(s) à supprimer:"
    for b in "${REMOTE_TEMP[@]}"; do
      echo "  → origin/$b"
      if [ "$DRY_RUN" -eq 0 ]; then
        git push origin --delete "$b" 2>&1 | tail -1 || warn "    échec"
      fi
    done
  fi
  echo ""
else
  info "  (Nettoyage distant désactivé — utilise --remote pour l'activer)"
  echo ""
fi

# ─── 6. Fichiers non traqués parasites ─────────────────────────────────────
sep
echo "  6. FICHIERS NON TRAQUÉS PARASITES"
sep
echo ""

PARASITE_COUNT=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in
    '?? '*'TEST_SYNC.txt'*|'?? '*.bak|'?? '*.log|'?? '*.tmp|'?? '*.swp|'?? '*~|'?? '.sync-worktrees/'*|'?? '.align-worktrees/'*|'?? '.push-worktrees/'*|'?? '.modify-worktrees/'*)
      FILE="${line#\?\? }"
      echo "  → $FILE"
      PARASITE_COUNT=$((PARASITE_COUNT+1))
      if [ "$DRY_RUN" -eq 0 ]; then
        rm -rf "$FILE" && ok "    supprimé"
      fi
      ;;
  esac
done < <(git status --porcelain 2>/dev/null | grep '^??' || true)

if [ "$PARASITE_COUNT" -eq 0 ]; then
  ok "Aucun fichier parasite non traqué"
else
  log "$PARASITE_COUNT fichier(s) à nettoyer"
fi
echo ""

# ─── État final ────────────────────────────────────────────────────────────
sep
echo "  ÉTAT FINAL"
sep
echo ""

if [ "$DRY_RUN" -eq 1 ]; then
  info "  (Mode dry-run: rien n'a été modifié)"
  info "  Lance avec --yes pour exécuter le nettoyage"
else
  echo "Branches locales restantes:"
  git branch --list | sed 's/^/  /'
  echo ""
  echo "Worktrees:"
  git worktree list | sed 's/^/  /'
  echo ""
  echo "Working tree:"
  if [ -z "$(git status --porcelain)" ]; then
    ok "  clean"
  else
    git status --short 2>/dev/null | head_n 10 | sed 's/^/  /'
  fi
fi
echo ""

# ─── Résumé ────────────────────────────────────────────────────────────────
sep
if [ "$DRY_RUN" -eq 1 ]; then
  warn "DRY-RUN — aucune modification effectuée"
  info ""
  info "Pour exécuter:"
  info "  ./scripts/cleanup-branches.sh --yes"
  info ""
  info "Pour inclure le nettoyage des branches distantes:"
  info "  ./scripts/cleanup-branches.sh --yes --remote"
  info ""
  info "Pour garder seulement N backups:"
  info "  ./scripts/cleanup-branches.sh --yes --keep-backups 3"
else
  ok "Nettoyage terminé"
fi
sep