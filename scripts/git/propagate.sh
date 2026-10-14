#!/usr/bin/env bash
# scripts/push-modification-to-all-branches.sh (v1)
#
# Propage une modification locale (working tree) sur toutes les branches ats-lab/*.
#
# Workflow:
#   1. Récupère la liste des fichiers modifiés sur la branche courante
#   2. Pour chaque branche ats-lab/*:
#      - Crée un worktree
#      - Applique les mêmes modifications
#      - Commit + push
#   3. Ne touche PAS à main (à faire après avec merge-all-into-main.sh)
#
# Usage:
#   ./scripts/push-modification-to-all-branches.sh [OPTIONS]
#
# Options:
#   --yes, -y            Exécute (sinon dry-run)
#   --dry-run            Simulation (défaut)
#   --message MSG        Message de commit (obligatoire)
#   --files "f1 f2"      Fichiers à propager (défaut: tous les modifiés)
#   --branch-source BR   Branche contenant les modifs (défaut: branche courante)
#   --help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT_DIR"

HEAD_BIN="/usr/bin/head"
[ -x "$HEAD_BIN" ] || HEAD_BIN="head"
head_n() { "$HEAD_BIN" -n "$1"; }

GIT_NAME="AbirhaouiSalah"
GIT_EMAIL="sabirhaouipro@gmail.com"

# ─── Options ───────────────────────────────────────────────────────────────
DRY_RUN=1
COMMIT_MSG=""
FILES_ARG=""
SOURCE_BRANCH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y)         DRY_RUN=0 ;;
    --dry-run)        DRY_RUN=1 ;;
    --message)        shift; COMMIT_MSG="${1:?--message requiert un texte}" ;;
    --files)          shift; FILES_ARG="${1:?--files requiert une liste}" ;;
    --branch-source)  shift; SOURCE_BRANCH="${1:?--branch-source requiert une branche}" ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) printf 'Argument inconnu: %s\n' "$1" >&2; exit 1 ;;
  esac
  shift
done

if [ -z "$COMMIT_MSG" ]; then
  printf 'Erreur: --message est obligatoire\n' >&2
  printf 'Exemple: %s --message "chore: apply change" --yes\n' "$0" >&2
  exit 1
fi

# ─── Couleurs ──────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_CYA=$'\033[0;36m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_CYA=""; C_DIM=""; C_RST=""
fi
log()  { printf '%s[push]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok  ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
err()  { printf '%s[err ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; }
info() { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RST"; }
sep()  { printf '%s%s%s\n' "$C_DIM" "════════════════════════════════════════════════════════════════" "$C_RST"; }
sub()  { printf '%s%s%s\n' "$C_DIM" "────────────────────────────────────────────────────────────────" "$C_RST"; }

# ─── Préflight ─────────────────────────────────────────────────────────────
[ -d .git ] || { err "Pas dans un dépôt git"; exit 1; }

# Branche source
if [ -z "$SOURCE_BRANCH" ]; then
  SOURCE_BRANCH="$(git branch --show-current)"
fi
git rev-parse --verify "$SOURCE_BRANCH" >/dev/null 2>&1 \
  || { err "Branche source '$SOURCE_BRANCH' introuvable"; exit 1; }

log "Branche source: $SOURCE_BRANCH"
log "Message de commit: $COMMIT_MSG"

# ─── Détection des modifications ──────────────────────────────────────────
sep
echo "  DÉTECTION DES MODIFICATIONS"
sep
echo ""

MODIFIED=$(git status --porcelain 2>/dev/null || true)
if [ -z "$MODIFIED" ]; then
  err "Aucune modification dans le working tree"
  err "Modifie d'abord des fichiers sur '$SOURCE_BRANCH'"
  exit 1
fi

echo "Modifications détectées:"
printf '%s\n' "$MODIFIED" | sed 's/^/  /'
echo ""

# Filtrer selon --files
if [ -n "$FILES_ARG" ]; then
  FILES=""
  for f in $FILES_ARG; do
    if printf '%s\n' "$MODIFIED" | grep -q "$f"; then
      FILES="$FILES $f"
    else
      warn "Fichier '$f' non détecté dans les modifs — ignoré"
    fi
  done
  FILES="${FILES# }"
else
  FILES=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in
      '?? '*) continue ;;  # skip untracked
    esac
    F="${line:3}"
    FILES="$FILES $F"
  done <<< "$MODIFIED"
  FILES="${FILES# }"
fi

if [ -z "$FILES" ]; then
  err "Aucun fichier à propager"
  exit 1
fi

echo "Fichiers à propager:"
for f in $FILES; do
  echo "  - $f"
done
echo ""

# ─── Créer un patch ────────────────────────────────────────────────────────
PATCH_FILE="/tmp/push-patch-$$.patch"
git diff HEAD -- $FILES > "$PATCH_FILE" 2>/dev/null || true

if [ ! -s "$PATCH_FILE" ]; then
  # Fallback : pas de diff (fichiers untracked ou nouveaux)
  warn "git diff vide — fallback: copie des fichiers depuis '$SOURCE_BRANCH'"
  PATCH_MODE="copy"
else
  PATCH_MODE="apply"
  log "Patch créé: $PATCH_FILE ($(wc -l < "$PATCH_FILE" | tr -d ' ') lignes)"
fi
echo ""

cleanup() { rm -f "$PATCH_FILE" 2>/dev/null || true; }
trap cleanup EXIT

# ─── Confirmation ─────────────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 0 ]; then
  warn "Cette opération va commiter '$COMMIT_MSG' sur les 23 branches ats-lab/*"
  printf '\nContinuer ? [y/N] '
  read -r ans
  [ "${ans:-N}" = "y" ] || [ "${ans:-N}" = "Y" ] || { echo "Abort."; exit 0; }
fi

# ─── Fetch + liste branches ────────────────────────────────────────────────
log "Fetch origin…"
git fetch origin --prune 2>/dev/null || { err "Fetch échoué"; exit 1; }

BRANCHES=()
while IFS= read -r b; do
  [ -n "$b" ] && BRANCHES+=("$b")
done < <(git ls-remote --heads origin 'refs/heads/ats-lab/*' \
         | awk -F'refs/heads/' '{print $2}' | sort -u)

TOTAL="${#BRANCHES[@]}"
[ "$TOTAL" -eq 0 ] && { err "Aucune branche ats-lab/*"; exit 1; }
log "Branches détectées: $TOTAL"

# ─── Worktrees ─────────────────────────────────────────────────────────────
WORKTREE_BASE=".push-worktrees"
mkdir -p "$WORKTREE_BASE"

cleanup_worktrees() {
  if [ -d "$WORKTREE_BASE" ]; then
    for d in "$WORKTREE_BASE"/*; do
      [ -d "$d" ] || continue
      git worktree remove --force "$d" 2>/dev/null || rm -rf "$d"
    done
    rm -rf "$WORKTREE_BASE"
  fi
  rm -f "$PATCH_FILE" 2>/dev/null || true
}
trap cleanup_worktrees EXIT

# ─── Propagation ───────────────────────────────────────────────────────────
sep
echo "  PROPAGATION → $TOTAL branches"
sep

P_OK=0; P_FAIL=0
FAILED_LIST=()

for b in "${BRANCHES[@]}"; do
  [ "$b" = "ats-lab/main" ] && { log "  skip ats-lab/main"; continue; }

  SAFE="${b//\//_}"
  WT="$WORKTREE_BASE/$SAFE"
  TMP_BRANCH="push-tmp-$$-$SAFE"

  echo ""
  log "▶ $b"

  if ! git worktree add --detach "$WT" "origin/$b" >/dev/null 2>&1; then
    warn "  worktree add échoué"
    P_FAIL=$((P_FAIL+1)); FAILED_LIST+=("$b (worktree)"); continue
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log "  [dry-run] skip apply+commit+push"
    git worktree remove --force "$WT" 2>/dev/null || rm -rf "$WT"
    continue
  fi

  RC=0
  PUSHED_SHA=$(
    cd "$WT" || exit 1

    git checkout -b "$TMP_BRANCH" >/dev/null 2>&1 || exit 1

    if [ "$PATCH_MODE" = "apply" ]; then
      if ! git apply --3way "$PATCH_FILE" 2>/dev/null; then
        # Fallback par fichier
        for f in $FILES; do
          SRC="$(git show "$SOURCE_BRANCH:$f" 2>/dev/null || echo "")"
          [ -z "$SRC" ] && continue
          mkdir -p "$(dirname "$f")"
          printf '%s' "$SRC" > "$f"
        done
      fi
    else
      # Mode copie
      for f in $FILES; do
        SRC="$(git show "$SOURCE_BRANCH:$f" 2>/dev/null || echo "")"
        [ -z "$SRC" ] && continue
        mkdir -p "$(dirname "$f")"
        printf '%s' "$SRC" > "$f"
      done
    fi

    # Add
    for f in $FILES; do
      [ -e "$f" ] && git add "$f" 2>/dev/null || true
    done

    if git diff --cached --quiet; then
      echo "COMMIT_EMPTY" >&2
      exit 2
    fi

    if ! git -c user.name="$GIT_NAME" -c user.email="$GIT_EMAIL" \
         commit -m "$COMMIT_MSG" >/dev/null 2>&1; then
      echo "COMMIT_FAILED" >&2
      exit 2
    fi

    LOCAL_SHA="$(git rev-parse HEAD)"

    if ! git push origin "HEAD:refs/heads/$b" >/dev/null 2>&1; then
      echo "PUSH_FAILED" >&2
      exit 3
    fi

    REMOTE_SHA="$(git ls-remote origin "refs/heads/$b" 2>/dev/null | awk '{print $1}')"
    if [ "$REMOTE_SHA" != "$LOCAL_SHA" ]; then
      echo "MISMATCH" >&2
      exit 4
    fi

    echo "$LOCAL_SHA"
  ) || RC=$?

  if [ "$RC" -eq 0 ]; then
    ok "  poussé (sha=$(printf '%.7s' "$PUSHED_SHA"))"
    P_OK=$((P_OK+1))
  else
    case "$RC" in
      2) warn "  commit vide ou échoué" ;;
      3) warn "  push échoué" ;;
      4) warn "  remote mismatch" ;;
      *) warn "  échec (code $RC)" ;;
    esac
    P_FAIL=$((P_FAIL+1)); FAILED_LIST+=("$b (rc=$RC)")
  fi

  git branch -D "$TMP_BRANCH" >/dev/null 2>&1 || true
  git worktree remove --force "$WT" 2>/dev/null || rm -rf "$WT"
done

# ─── Résumé ────────────────────────────────────────────────────────────────
echo ""
sep
echo "  RÉSUMÉ"
sep
echo ""

if [ "$DRY_RUN" -eq 1 ]; then
  info "  [DRY-RUN] Aucune modification effectuée"
  info "  Lance avec --yes pour exécuter"
else
  printf '  ✅ %d poussées\n' "$P_OK"
  printf '  ❌ %d échecs\n' "$P_FAIL"
fi

if [ "${#FAILED_LIST[@]}" -gt 0 ]; then
  echo ""
  printf '  Échecs:\n'
  for f in "${FAILED_LIST[@]}"; do
    printf '    - %s\n' "$f"
  done
fi

echo ""
info "  Prochaine étape : ./scripts/merge-all-into-main.sh"
echo ""
sep