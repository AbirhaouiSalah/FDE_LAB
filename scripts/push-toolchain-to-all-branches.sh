#!/usr/bin/env bash
# scripts/push-toolchain-to-all-branches.sh
# Propage la toolchain minimale + run.sh sur toutes les branches ats-lab/*
# Usage: ./scripts/push-toolchain-to-all-branches.sh [--dry-run] [--yes]

set -euo pipefail

DRY_RUN=0
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --yes|-y)  ASSUME_YES=1 ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done

# Fichiers à propager
FILES=(
  "scripts/run.sh"
  "scripts/run.ps1"
  ".npmrc"
  "package.json"
  "index.html"
  "tsconfig.json"
  "vite.config.ts"
  "vitest.config.ts"
  "vitest.setup.ts"
  "src/vite-env.d.ts"
  "src/app/main.tsx"
  ".github/workflows/dashboard-ci.yml"
)

BRANCHES=(
  $(git ls-remote --heads origin 'refs/heads/ats-lab/*' \
    | awk -F'refs/heads/' '{print $2}' | sort -u)
)

echo "Branches détectées: ${#BRANCHES[@]}"
if [ "$ASSUME_YES" -eq 0 ]; then
  printf '%s\n' "${BRANCHES[@]}"
  read -r -p "Continuer ? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { echo "Abort"; exit 0; }
fi

CURRENT_BRANCH="$(git branch --show-current)"
echo "Branche courante: $CURRENT_BRANCH (sera restaurée à la fin)"

FAILED=()

for b in "${BRANCHES[@]}"; do
  echo ""
  echo "════════════════════════════════════════"
  echo "▶ $b"
  echo "════════════════════════════════════════"

  # checkout la branche distante localement
  if ! git checkout -B "$b" "origin/$b" 2>/dev/null; then
    echo "  ❌ impossible de checkout origin/$b"
    FAILED+=("$b (checkout)")
    continue
  fi

  # copie les fichiers depuis main (sans changer d'historique)
  for f in "${FILES[@]}"; do
    if git show "main:$f" > "$f" 2>/dev/null; then
      echo "  ✓ $f"
    else
      echo "  ⚠ $f absent sur main — skip"
    fi
  done

  # status
  if git diff --quiet && git diff --cached --quiet; then
    echo "  ⏭ rien à committer"
    continue
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] git diff:"
    git --no-pager diff --stat
    continue
  fi

  git add "${FILES[@]}"
  git commit -m "chore(toolchain): propagate run.sh + minimal frontend toolchain [skip ci]"

  if git push origin "HEAD:refs/heads/$b" 2>&1 | tail -5; then
    echo "  ✅ poussé"
  else
    echo "  ❌ push échoué"
    FAILED+=("$b (push)")
  fi
done

# restaure la branche initiale
git checkout "$CURRENT_BRANCH"

echo ""
echo "════════════════════════════════════════"
if [ "${#FAILED[@]}" -eq 0 ]; then
  echo "✅ Propagation terminée sans erreur"
else
  echo "⚠ Échecs: ${#FAILED[@]}"
  printf '  - %s\n' "${FAILED[@]}"
fi