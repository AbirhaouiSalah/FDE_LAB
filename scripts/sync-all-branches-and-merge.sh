#!/usr/bin/env bash
# scripts/sync-all-branches-and-merge.sh
#
# Propage les développements de la branche courante (par défaut: main)
# sur toutes les branches ats-lab/*, puis merge toutes les ats-lab/* dans main.
#
# Usage:
#   ./scripts/sync-all-branches-and-merge.sh [--dry-run] [--yes] [--source main] [--no-merge]
#
# Options:
#   --dry-run       Affiche ce qui serait fait, ne push rien
#   --yes, -y       Pas de confirmation interactive
#   --source <b>    Branche source (défaut: main)
#   --no-merge      Propage seulement, ne merge pas dans main
#   -h, --help      Affiche cette aide

set -euo pipefail

# ─── Config ────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

FILES_TO_PROPAGATE=(
  "scripts/run.sh"
  "scripts/run.ps1"
  ".npmrc"
  "package.json"
  "pnpm-lock.yaml"
  "index.html"
  "tsconfig.json"
  "vite.config.ts"
  "vitest.config.ts"
  "vitest.setup.ts"
  "eslint.config.js"
  "src/vite-env.d.ts"
  "src/app/main.tsx"
  ".github/workflows/dashboard-ci.yml"
)

# ─── CLI ──────────────────────────────────────────────────────────────────
DRY_RUN=0
ASSUME_YES=0
SKIP_MERGE=0
SOURCE_BRANCH="main"

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)  DRY_RUN=1 ;;
    --yes|-y)   ASSUME_YES=1 ;;
    --no-merge) SKIP_MERGE=1 ;;
    --source)   shift; SOURCE_BRANCH="${1:?--source requiert une valeur}" ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Argument inconnu: $1" >&2; exit 1 ;;
  esac
  shift
done

# ─── Couleurs ─────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_DIM=$'\033[2m';    C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_DIM=""; C_RST=""
fi
log()  { printf '%s[sync]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok  ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
die()  { printf '%s[err ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; exit 1; }

# ─── Préflight ────────────────────────────────────────────────────────────
[ -d .git ] || die "Pas dans un dépôt git (ou .git absent)"

if [ -n "$(git status --porcelain)" ]; then
  die "Working tree non propre. Commit ou stash d'abord:
$(git status --short)"
fi

git rev-parse --verify "$SOURCE_BRANCH" >/dev/null 2>&1 \
  || die "Branche source '$SOURCE_BRANCH' introuvable"

log "Fetch origin…"
git fetch origin --prune

BACKUP_BRANCH="backup/pre-merge-$(date +%Y%m%d-%H%M%S)"
log "Création de la branche de sauvegarde: $BACKUP_BRANCH"
if [ "$DRY_RUN" -eq 0 ]; then
  git branch "$BACKUP_BRANCH" "$SOURCE_BRANCH"
  git push origin "$BACKUP_BRANCH" 2>&1 | tail -3
  ok "Backup poussé sur origin/$BACKUP_BRANCH"
else
  log "[dry-run] aurait créé $BACKUP_BRANCH"
fi

# ─── Liste des branches ats-lab/* ─────────────────────────────────────────
mapfile_compat() {
  # bash 3.2 n'a pas mapfile
  local __var="$1"; shift
  local __line
  eval "$__var=()"
  while IFS= read -r __line; do
    [ -n "$__line" ] || continue
    eval "$__var+=(\"\$__line\")"
  done
}

mapfile_compat BRANCHES < <(
  git ls-remote --heads origin 'refs/heads/ats-lab/*' \
    | awk -F'refs/heads/' '{print $2}' | sort -u
)

if [ "${#BRANCHES[@]}" -eq 0 ]; then
  warn "Aucune branche ats-lab/* trouvée sur origin"
else
  log "Branches détectées: ${#BRANCHES[@]}"
  for b in "${BRANCHES[@]}"; do
    printf '  %s- %s%s\n' "$C_DIM" "$b" "$C_RST"
  done
fi

# ─── Confirmation ─────────────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 0 ] && [ "$ASSUME_YES" -eq 0 ]; then
  echo ""
  warn "Cette opération va:"
  warn "  1. Propager les fichiers depuis '$SOURCE_BRANCH' vers ${#BRANCHES[@]} branches ats-lab/*"
  if [ "$SKIP_MERGE" -eq 0 ]; then
    warn "  2. Merger toutes les ats-lab/* dans '$SOURCE_BRANCH' (avec --allow-unrelated-histories -X theirs)"
  fi
  warn "  3. Pousser le résultat sur origin"
  echo ""
  read -r -p "Continuer ? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { echo "Abort."; exit 0; }
fi

# ─── Phase 1 : propagation sur les branches ───────────────────────────────
CURRENT_BRANCH="$(git branch --show-current)"
log "Branche courante: $CURRENT_BRANCH (sera restaurée à la fin)"
log "Passage sur '$SOURCE_BRANCH'…"
git checkout "$SOURCE_BRANCH"

FAILED_PROPAGATE=()
SUCCESS_PROPAGATE=()
NOOP_PROPAGATE=()

for b in "${BRANCHES[@]+"${BRANCHES[@]}"}"; do
  echo ""
  echo "════════════════════════════════════════════════════════════"
  log "▶ Propagation → $b"
  echo "════════════════════════════════════════════════════════════"

  if ! git checkout -B "$b" "origin/$b" 2>/dev/null; then
    warn "checkout origin/$b impossible — skip"
    FAILED_PROPAGATE+=("$b (checkout)")
    continue
  fi

  CHANGED=0
  for f in "${FILES_TO_PROPAGATE[@]}"; do
    if git show "$SOURCE_BRANCH:$f" > "$f" 2>/dev/null; then
      if ! git diff --quiet -- "$f" 2>/dev/null; then
        CHANGED=1
      fi
    fi
  done

  if [ "$CHANGED" -eq 0 ]; then
    log "  Rien à changer — branche déjà à jour"
    NOOP_PROPAGATE+=("$b")
    continue
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log "  [dry-run] git diff --stat:"
    git --no-pager diff --stat
    continue
  fi

  git add "${FILES_TO_PROPAGATE[@]}"
  git commit -m "chore(sync): propagate toolchain from $SOURCE_BRANCH [skip ci]" \
    || { warn "  commit échoué"; FAILED_PROPAGATE+=("$b (commit)"); continue; }

  if git push origin "HEAD:refs/heads/$b" 2>&1 | tail -3; then
    ok "  poussé: $b"
    SUCCESS_PROPAGATE+=("$b")
  else
    warn "  push échoué: $b"
    FAILED_PROPAGATE+=("$b (push)")
  fi
done

# Retour sur la branche source
git checkout "$SOURCE_BRANCH"

# ─── Phase 2 : merge des branches dans main ───────────────────────────────
if [ "$SKIP_MERGE" -eq 0 ]; then
  echo ""
  echo "════════════════════════════════════════════════════════════"
  log "▶ Merge des ats-lab/* dans $SOURCE_BRANCH"
  echo "════════════════════════════════════════════════════════════"

  FAILED_MERGE=()
  SUCCESS_MERGE=()
  NOOP_MERGE=()

  for b in "${BRANCHES[@]+"${BRANCHES[@]}"}"; do
    echo ""
    log "▶ Merge $b → $SOURCE_BRANCH"

    git fetch origin "$b" >/dev/null 2>&1 || true

    # Si déjà ancêtre → rien à faire
    if git merge-base --is-ancestor "origin/$b" "$SOURCE_BRANCH" 2>/dev/null; then
      log "  Déjà dans $SOURCE_BRANCH — skip"
      NOOP_MERGE+=("$b")
      continue
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
      log "  [dry-run] aurait mergé origin/$b dans $SOURCE_BRANCH"
      continue
    fi

    if git merge --no-ff --allow-unrelated-histories -X theirs \
        -m "merge: sync $b into $SOURCE_BRANCH [skip ci]" \
        "origin/$b" >/dev/null 2>&1; then
      ok "  mergé: $b"
      SUCCESS_MERGE+=("$b")
    else
      warn "  conflit sur $b — merge --abort"
      git merge --abort 2>/dev/null || true
      FAILED_MERGE+=("$b")
    fi
  done

  # Push final de main
  if [ "$DRY_RUN" -eq 0 ]; then
    echo ""
    log "Push final de $SOURCE_BRANCH…"
    git push origin "$SOURCE_BRANCH"
  fi
fi

# ─── Retour à la branche initiale ─────────────────────────────────────────
if [ "$CURRENT_BRANCH" != "$(git branch --show-current)" ]; then
  git checkout "$CURRENT_BRANCH" 2>/dev/null || true
fi

# ─── Résumé ───────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════"
echo "  RÉSUMÉ"
echo "════════════════════════════════════════════════════════════"

report() {
  local label="$1"; shift
  local arr=("$@")
  echo ""
  printf '%s%s%s\n' "$C_BLU" "$label" "$C_RST"
  if [ "${#arr[@]}" -eq 0 ]; then
    printf '  %s(aucune)%s\n' "$C_DIM" "$C_RST"
  else
    for x in "${arr[@]}"; do echo "  - $x"; done
  fi
}

echo ""
printf '%sPropagation%s\n' "$C_BLU" "$C_RST"
report "  ✅ succès (${#SUCCESS_PROPAGATE[@]})"   "${SUCCESS_PROPAGATE[@]+"${SUCCESS_PROPAGATE[@]}"}"
report "  ⏭ déjà à jour (${#NOOP_PROPAGATE[@]})" "${NOOP_PROPAGATE[@]+"${NOOP_PROPAGATE[@]}"}"
report "  ❌ échecs (${#FAILED_PROPAGATE[@]})"    "${FAILED_PROPAGATE[@]+"${FAILED_PROPAGATE[@]}"}"

if [ "$SKIP_MERGE" -eq 0 ]; then
  echo ""
  printf '%sMerge dans %s%s\n' "$C_BLU" "$SOURCE_BRANCH" "$C_RST"
  report "  ✅ mergées (${#SUCCESS_MERGE[@]})"     "${SUCCESS_MERGE[@]+"${SUCCESS_MERGE[@]}"}"
  report "  ⏭ déjà présentes (${#NOOP_MERGE[@]})" "${NOOP_MERGE[@]+"${NOOP_MERGE[@]}"}"
  report "  ❌ échecs (${#FAILED_MERGE[@]})"       "${FAILED_MERGE[@]+"${FAILED_MERGE[@]}"}"
fi

echo ""
ok "Sauvegarde disponible: origin/$BACKUP_BRANCH"
echo ""