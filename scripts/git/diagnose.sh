#!/usr/bin/env bash
# scripts/diagnose.sh (v3)
# Diagnostic détaillé de l'état des branches ats-lab/*
#
# Usage:
#   ./scripts/diagnose.sh               # résumé compact (tableau)
#   ./scripts/diagnose.sh --full        # détail sur chaque branche
#   ./scripts/diagnose.sh --files       # liste des fichiers manquants par branche
#   ./scripts/diagnose.sh --commits     # détail des commits uniques
#   ./scripts/diagnose.sh --branch <b>  # détail sur une seule branche
#   ./scripts/diagnose.sh --all         # tout

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT_DIR"

# Force l'utilisation du head BSD (macOS) pour éviter les conflits
HEAD_BIN="/usr/bin/head"
[ -x "$HEAD_BIN" ] || HEAD_BIN="head"

# ─── Couleurs ──────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_CYA=$'\033[0;36m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_CYA=""; C_DIM=""; C_RST=""
fi
log()  { printf '%s[diag]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok  ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
err()  { printf '%s[err ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; }
sep()  { printf '%s%s%s\n' "$C_DIM" "════════════════════════════════════════════════════════════════" "$C_RST"; }
sub()  { printf '%s%s%s\n' "$C_DIM" "────────────────────────────────────────────────────────────────" "$C_RST"; }
head_n() { "$HEAD_BIN" -n "$1"; }

# ─── Options ───────────────────────────────────────────────────────────────
MODE="compact"
FOCUS_BRANCH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --full)    MODE="full" ;;
    --files)   MODE="files" ;;
    --commits) MODE="commits" ;;
    --all)     MODE="all" ;;
    --branch)  shift; FOCUS_BRANCH="${1:-}"; MODE="branch" ;;
    -h|--help)
      sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) printf 'Option inconnue: %s\n' "$1" >&2; exit 1 ;;
  esac
  shift
done

# ─── Préflight ─────────────────────────────────────────────────────────────
[ -d .git ] || { err "Pas dans un dépôt git"; exit 1; }

log "Fetch origin…"
git fetch origin --prune 2>/dev/null || true

SOURCE_BRANCH="main"
CURRENT_BRANCH="$(git branch --show-current)"

# ─── Fichiers toolchain à vérifier ─────────────────────────────────────────
TOOLCHAIN_FILES=(
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
TOTAL_FILES="${#TOOLCHAIN_FILES[@]}"

# ─── Fonctions utilitaires ─────────────────────────────────────────────────
branch_file_matches_main() {
  local b="$1" f="$2"
  local main_hash branch_hash
  main_hash="$(git rev-parse "$SOURCE_BRANCH:$f" 2>/dev/null || echo "")"
  branch_hash="$(git rev-parse "origin/$b:$f" 2>/dev/null || echo "")"
  [ -n "$main_hash" ] && [ "$main_hash" = "$branch_hash" ]
}

# ─── Liste des branches ────────────────────────────────────────────────────
BRANCHES=()
while IFS= read -r b; do
  [ -n "$b" ] && BRANCHES+=("$b")
done < <(git ls-remote --heads origin 'refs/heads/ats-lab/*' \
         | awk -F'refs/heads/' '{print $2}' | sort -u)

TOTAL="${#BRANCHES[@]}"

# ─── Mode focus sur une seule branche ──────────────────────────────────────
if [ "$MODE" = "branch" ] && [ -n "$FOCUS_BRANCH" ]; then
  B="$FOCUS_BRANCH"
  [ "${B#ats-lab/}" = "$B" ] && B="ats-lab/$B"

  sep
  echo "  FOCUS: $B"
  sep
  echo ""

  if ! git rev-parse --verify "origin/$B" >/dev/null 2>&1; then
    err "Branche origin/$B introuvable"
    exit 1
  fi

  echo "Derniers commits:"
  git log "origin/$B" --oneline -5 2>/dev/null
  echo ""

  AHEAD=$(git rev-list --count "$SOURCE_BRANCH..origin/$B" 2>/dev/null || echo "?")
  BEHIND=$(git rev-list --count "origin/$B..$SOURCE_BRANCH" 2>/dev/null || echo "?")
  echo "Écart avec $SOURCE_BRANCH:"
  echo "  $AHEAD commits uniques sur $B"
  echo "  $BEHIND commits de $SOURCE_BRANCH absents de $B"
  echo ""

  PRESENT=0
  MISSING=()
  for f in "${TOOLCHAIN_FILES[@]}"; do
    if git cat-file -e "origin/$B:$f" 2>/dev/null; then
      PRESENT=$((PRESENT+1))
    else
      MISSING+=("$f")
    fi
  done
  echo "Toolchain: $PRESENT/$TOTAL_FILES"
  if [ "${#MISSING[@]}" -gt 0 ]; then
    echo "Fichiers MANQUANTS:"
    for f in "${MISSING[@]}"; do echo "  ✗ $f"; done
  fi
  echo ""

  echo "Fichiers présents mais DIFFÉRENTS de $SOURCE_BRANCH:"
  DIFF_COUNT=0
  for f in "${TOOLCHAIN_FILES[@]}"; do
    if git cat-file -e "origin/$B:$f" 2>/dev/null; then
      if ! branch_file_matches_main "$B" "$f"; then
        echo "  ⚠ $f"
        DIFF_COUNT=$((DIFF_COUNT+1))
      fi
    fi
  done
  [ "$DIFF_COUNT" -eq 0 ] && echo "  (aucun)"
  echo ""

  echo "Résumé du diff $SOURCE_BRANCH → $B:"
  git diff --stat "$SOURCE_BRANCH" "origin/$B" 2>/dev/null | tail -20 || echo "  (erreur)"
  echo ""
  exit 0
fi

# ─── Mode standard ─────────────────────────────────────────────────────────
sep
echo "  ÉTAT GÉNÉRAL"
sep
echo ""
echo "Branche courante : $CURRENT_BRANCH"
echo "Working tree     :"
if [ -z "$(git status --porcelain)" ]; then
  echo "  clean"
else
  git status --short 2>/dev/null | head_n 20
fi
echo ""

echo "Synchronisation $SOURCE_BRANCH:"
LM="$(git rev-parse "$SOURCE_BRANCH" 2>/dev/null || echo 'absent')"
RM="$(git rev-parse "origin/$SOURCE_BRANCH" 2>/dev/null || echo 'absent')"
if [ "$LM" = "$RM" ]; then
  ok "$SOURCE_BRANCH local == origin/$SOURCE_BRANCH ($(printf '%.7s' "$LM"))"
else
  warn "$SOURCE_BRANCH local != origin/$SOURCE_BRANCH"
  echo "  local : $LM"
  echo "  remote: $RM"
fi
echo ""

# ─── Tableau principal ─────────────────────────────────────────────────────
sep
echo "  TABLEAU — $TOTAL branches ats-lab/*"
sep
echo ""

printf '%-42s %6s %6s %10s %8s %s\n' \
  "BRANCHE" "AHEAD" "BEHIND" "TOOLCHAIN" "SYNC" "DERNIER COMMIT"
sub

SUMMARY_OK=0
SUMMARY_PARTIAL=0
SUMMARY_EMPTY=0

for b in "${BRANCHES[@]}"; do
  [ "$b" = "ats-lab/main" ] && continue

  AHEAD=$(git rev-list --count "$SOURCE_BRANCH..origin/$b" 2>/dev/null || echo "?")
  BEHIND=$(git rev-list --count "origin/$b..$SOURCE_BRANCH" 2>/dev/null || echo "?")

  PRESENT=0
  for f in "${TOOLCHAIN_FILES[@]}"; do
    git cat-file -e "origin/$b:$f" 2>/dev/null && PRESENT=$((PRESENT+1))
  done

  SYNC="✗"
  if git log "origin/$b" --oneline --all --grep="propagate toolchain" -1 2>/dev/null | grep -q .; then
    SYNC="✓"
  fi

  if [ "$PRESENT" -eq "$TOTAL_FILES" ]; then
    TC="${C_GRN}${PRESENT}/${TOTAL_FILES}${C_RST}"
    SUMMARY_OK=$((SUMMARY_OK+1))
  elif [ "$PRESENT" -eq 0 ]; then
    TC="${C_RED}${PRESENT}/${TOTAL_FILES}${C_RST}"
    SUMMARY_EMPTY=$((SUMMARY_EMPTY+1))
  else
    TC="${C_YEL}${PRESENT}/${TOTAL_FILES}${C_RST}"
    SUMMARY_PARTIAL=$((SUMMARY_PARTIAL+1))
  fi

  LAST=$(git log "origin/$b" --oneline -1 2>/dev/null | cut -c1-50)

  printf '%-42s %6s %6s %20s %8s %s\n' \
    "$b" "$AHEAD" "$BEHIND" "$TC" "$SYNC" "$LAST"
done

# ─── Résumé ────────────────────────────────────────────────────────────────
echo ""
sep
echo "  RÉSUMÉ"
sep
echo ""
printf '  Total                         : %d\n' "$TOTAL"
printf '  ✅ Toolchain complète          : %d\n' "$SUMMARY_OK"
printf '  ⚠  Toolchain partielle         : %d\n' "$SUMMARY_PARTIAL"
printf '  ❌ Toolchain vide              : %d\n' "$SUMMARY_EMPTY"
echo ""

# ─── Détail des fichiers manquants ─────────────────────────────────────────
if [ "$MODE" = "files" ] || [ "$MODE" = "all" ]; then
  sep
  echo "  FICHIERS MANQUANTS PAR BRANCHE"
  sep
  echo ""

  for b in "${BRANCHES[@]}"; do
    [ "$b" = "ats-lab/main" ] && continue

    MISSING=()
    for f in "${TOOLCHAIN_FILES[@]}"; do
      git cat-file -e "origin/$b:$f" 2>/dev/null || MISSING+=("$f")
    done

    if [ "${#MISSING[@]}" -eq 0 ]; then
      printf '%s ✅ %s%s\n' "$C_GRN" "$b" "$C_RST"
    else
      printf '%s%s%s\n' "$C_YEL" "$b" "$C_RST"
      for f in "${MISSING[@]}"; do
        printf '    ✗ %s\n' "$f"
      done
    fi
  done
  echo ""
fi

# ─── Détail des commits uniques ────────────────────────────────────────────
if [ "$MODE" = "commits" ] || [ "$MODE" = "all" ]; then
  sep
  echo "  COMMITS UNIQUES PAR BRANCHE"
  sep
  echo ""

  for b in "${BRANCHES[@]}"; do
    [ "$b" = "ats-lab/main" ] && continue

    UNIQUE=$(git rev-list --count "$SOURCE_BRANCH..origin/$b" 2>/dev/null || echo "0")

    if [ "$UNIQUE" -eq 0 ]; then
      printf '%s ⏭  %-45s (0 unique)%s\n' "$C_DIM" "$b" "$C_RST"
    else
      printf '%s%s%s (%d commits uniques):\n' "$C_CYA" "$b" "$C_RST" "$UNIQUE"
      git log "$SOURCE_BRANCH..origin/$b" --oneline 2>/dev/null | head_n 10 | sed 's/^/    /'
    fi
  done
  echo ""
fi

# ─── Détail complet ────────────────────────────────────────────────────────
if [ "$MODE" = "full" ] || [ "$MODE" = "all" ]; then
  sep
  echo "  DÉTAIL COMPLET PAR BRANCHE"
  sep
  echo ""

  for b in "${BRANCHES[@]}"; do
    [ "$b" = "ats-lab/main" ] && continue

    echo ""
    printf '%s▶ %s%s\n' "$C_BLU" "$b" "$C_RST"
    sub

    AHEAD=$(git rev-list --count "$SOURCE_BRANCH..origin/$b" 2>/dev/null || echo "?")
    BEHIND=$(git rev-list --count "origin/$b..$SOURCE_BRANCH" 2>/dev/null || echo "?")
    echo "  Écart: $AHEAD ahead, $BEHIND behind"

    PRESENT=0
    for f in "${TOOLCHAIN_FILES[@]}"; do
      git cat-file -e "origin/$b:$f" 2>/dev/null && PRESENT=$((PRESENT+1))
    done
    echo "  Toolchain: $PRESENT/$TOTAL_FILES"

    echo "  Derniers commits:"
    git log "origin/$b" --oneline -3 2>/dev/null | sed 's/^/    /'
  done
fi

# ─── Branches locales sans remote ──────────────────────────────────────────
sep
echo "  BRANCHES LOCALES SANS REMOTE"
sep
echo ""
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
  for b in "${LOCAL_ONLY[@]}"; do echo "  - $b"; done
fi
echo ""

# ─── Backups sur origin ────────────────────────────────────────────────────
sep
echo "  BACKUPS SUR ORIGIN"
sep
echo ""
BACKUPS=$(git ls-remote --heads origin 'refs/heads/backup/*' 2>/dev/null \
          | awk -F'refs/heads/' '{print $2}' || echo "")
if [ -z "$BACKUPS" ]; then
  echo "  (aucune)"
else
  echo "$BACKUPS" | sed 's/^/  - /'
fi
echo ""

# ─── Conclusion ────────────────────────────────────────────────────────────
sep
if [ "$SUMMARY_OK" -eq "$((TOTAL-1))" ]; then
  ok "Toutes les branches ont la toolchain ✅"
elif [ "$SUMMARY_EMPTY" -gt 0 ]; then
  err "$SUMMARY_EMPTY branche(s) n'ont AUCUN fichier toolchain"
elif [ "$SUMMARY_PARTIAL" -gt 0 ]; then
  warn "$SUMMARY_PARTIAL branche(s) ont une toolchain partielle"
else
  ok "Diagnostic terminé"
fi
sep