#!/usr/bin/env bash
# scripts/diagnose.sh — Diagnostic de l'état des branches ats-lab/*
# Usage: ./scripts/diagnose.sh [--full]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_DIM=$'\033[2m';    C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_DIM=""; C_RST=""
fi
log()  { printf '%s[diag]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok  ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
err()  { printf '%s[err ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; }
sep()  { printf '%s%s%s\n' "$C_DIM" "────────────────────────────────────────────────────────" "$C_RST"; }

# ─── Préflight ─────────────────────────────────────────────────────────────
[ -d .git ] || { err "Pas dans un dépôt git"; exit 1; }

log "Fetch origin…"
git fetch origin --prune 2>/dev/null || true

CURRENT_BRANCH="$(git branch --show-current)"
log "Branche courante: $CURRENT_BRANCH"

# ─── État général ──────────────────────────────────────────────────────────
sep
echo "  1. ÉTAT GÉNÉRAL"
sep

echo ""
echo "Working tree:"
git status --short || true
echo ""

echo "Commits locaux non poussés (toutes branches):"
git log --oneline @{u}..HEAD 2>/dev/null | head -10 || echo "  (aucun)"

echo ""
echo "Synchronisation avec origin/main:"
LOCAL_MAIN="$(git rev-parse main 2>/dev/null || echo 'absent')"
REMOTE_MAIN="$(git rev-parse origin/main 2>/dev/null || echo 'absent')"
if [ "$LOCAL_MAIN" = "$REMOTE_MAIN" ]; then
  ok "main local == origin/main ($(git rev-parse --short main))"
else
  warn "main local != origin/main"
  echo "  local : $LOCAL_MAIN"
  echo "  remote: $REMOTE_MAIN"
  echo ""
  echo "  Commits en avance (local):"
  git log --oneline origin/main..main 2>/dev/null | head -5 || echo "  (aucun)"
  echo "  Commits en retard (remote):"
  git log --oneline main..origin/main 2>/dev/null | head -5 || echo "  (aucun)"
fi

# ─── Branches ats-lab/* ────────────────────────────────────────────────────
sep
echo "  2. BRANCHES ats-lab/*"
sep

BRANCHES=()
while IFS= read -r b; do
  [ -n "$b" ] && BRANCHES+=("$b")
done < <(git ls-remote --heads origin 'refs/heads/ats-lab/*' \
         | awk -F'refs/heads/' '{print $2}' | sort -u)

TOTAL="${#BRANCHES[@]}"
echo ""
echo "Branches détectées: $TOTAL"
echo ""

# En-têtes du tableau
printf '%-45s %-10s %-10s %-10s %-10s %s\n' "BRANCHE" "AHEAD" "BEHIND" "TOOLCHAIN" "WF" "DERNIER COMMIT"
sep

# Fichiers de la toolchain à vérifier
TOOLCHAIN_FILES=(
  "scripts/run.sh"
  ".npmrc"
  "package.json"
  "index.html"
  "tsconfig.json"
  "vite.config.ts"
  "vitest.config.ts"
  "vitest.setup.ts"
  "eslint.config.js"
  "src/vite-env.d.ts"
  "src/app/main.tsx"
)

SUMMARY_UP_TO_DATE=0
SUMMARY_NEEDS_SYNC=0
SUMMARY_DIVERGENT=0
SUMMARY_FAILED=0

for b in "${BRANCHES[@]}"; do
  SAFE_NAME="${b//\//_}"

  # Combien de commits d'avance / de retard ?
  AHEAD=0
  BEHIND=0

  if git rev-parse --verify "origin/$b" >/dev/null 2>&1; then
    AHEAD=$(git rev-list --count "origin/$b..$CURRENT_BRANCH" 2>/dev/null || echo "?")
    BEHIND=$(git rev-list --count "$CURRENT_BRANCH..origin/$b" 2>/dev/null || echo "?")
  fi

  # Combien de fichiers toolchain présents ?
  TOOLCHAIN_COUNT=0
  for f in "${TOOLCHAIN_FILES[@]}"; do
    if git cat-file -e "origin/$b:$f" 2>/dev/null; then
      TOOLCHAIN_COUNT=$((TOOLCHAIN_COUNT+1))
    fi
  done

  # Le workflow CI existe ?
  WF="✗"
  if git cat-file -e "origin/$b:.github/workflows/dashboard-ci.yml" 2>/dev/null; then
    WF="✓"
  fi

  # Dernier commit
  LAST_COMMIT=$(git log "origin/$b" --oneline -1 2>/dev/null | cut -c1-60 || echo "?")

  # Marquage couleur
  TC_MARK=""
  if [ "$TOOLCHAIN_COUNT" -eq "${#TOOLCHAIN_FILES[@]}" ]; then
    TC_MARK="${C_GRN}${TOOLCHAIN_COUNT}/${#TOOLCHAIN_FILES[@]}${C_RST}"
  elif [ "$TOOLCHAIN_COUNT" -gt 0 ]; then
    TC_MARK="${C_YEL}${TOOLCHAIN_COUNT}/${#TOOLCHAIN_FILES[@]}${C_RST}"
  else
    TC_MARK="${C_RED}0/${#TOOLCHAIN_FILES[@]}${C_RST}"
  fi

  printf '%-45s %-10s %-10s %-20s %-10s %s\n' \
    "$b" "$AHEAD" "$BEHIND" "$(printf '%s' "$TC_MARK")" "$WF" "$LAST_COMMIT"

  # Comptage résumé
  if [ "$TOOLCHAIN_COUNT" -eq "${#TOOLCHAIN_FILES[@]}" ] && [ "$BEHIND" = "0" ]; then
    SUMMARY_UP_TO_DATE=$((SUMMARY_UP_TO_DATE+1))
  elif [ "$BEHIND" != "0" ] && [ "$AHEAD" = "0" ]; then
    SUMMARY_NEEDS_SYNC=$((SUMMARY_NEEDS_SYNC+1))
  else
    SUMMARY_DIVERGENT=$((SUMMARY_DIVERGENT+1))
  fi
done

# ─── Résumé ────────────────────────────────────────────────────────────────
sep
echo "  3. RÉSUMÉ"
sep
echo ""
echo "  Total branches              : $TOTAL"
echo "  ✅ Déjà à jour (toolchain + 0 behind) : $SUMMARY_UP_TO_DATE"
echo "  ⚠  À synchroniser (behind)   : $SUMMARY_NEEDS_SYNC"
echo "  ❌ Divergentes / partielles   : $SUMMARY_DIVERGENT"
echo ""

# ─── Détail sur une branche de référence ───────────────────────────────────
if [ "${1:-}" = "--full" ] && [ "$TOTAL" -gt 0 ]; then
  REF="${BRANCHES[0]}"
  sep
  echo "  4. DÉTAIL: $REF"
  sep
  echo ""
  echo "Derniers commits:"
  git log "origin/$REF" --oneline -10 2>/dev/null || echo "  (indisponible)"
  echo ""
  echo "Fichiers toolchain présents:"
  for f in "${TOOLCHAIN_FILES[@]}"; do
    if git cat-file -e "origin/$REF:$f" 2>/dev/null; then
      echo "  ✓ $f"
    else
      echo "  ✗ $f"
    fi
  done
fi

# ─── Branches locales orphelines ───────────────────────────────────────────
sep
echo "  5. BRANCHES LOCALES SANS REMOTE"
sep
LOCAL_ONLY=()
while IFS= read -r b; do
  [ -z "$b" ] && continue
  if ! git ls-remote --exit-code --heads origin "$b" >/dev/null 2>&1; then
    LOCAL_ONLY+=("$b")
  fi
done < <(git for-each-ref --format='%(refname:short)' refs/heads/)

if [ "${#LOCAL_ONLY[@]}" -eq 0 ]; then
  echo "  (aucune)"
else
  for b in "${LOCAL_ONLY[@]}"; do
    echo "  - $b"
  done
fi
echo ""

# ─── Backups ───────────────────────────────────────────────────────────────
sep
echo "  6. BACKUPS"
sep
git ls-remote --heads origin 'refs/heads/backup/*' 2>/dev/null | awk -F'refs/heads/' '{print "  - " $2}' || echo "  (aucune)"
echo ""

# ─── Fin ───────────────────────────────────────────────────────────────────
sep
if [ "$SUMMARY_DIVERGENT" -gt 0 ]; then
  err "Diagnostic terminé — $SUMMARY_DIVERGENT branche(s) en état divergent"
elif [ "$SUMMARY_NEEDS_SYNC" -gt 0 ]; then
  warn "Diagnostic terminé — $SUMMARY_NEEDS_SYNC branche(s) à synchroniser"
else
  ok "Diagnostic terminé — tout est cohérent"
fi