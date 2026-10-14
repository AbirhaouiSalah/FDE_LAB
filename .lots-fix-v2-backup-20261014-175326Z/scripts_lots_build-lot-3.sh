#!/usr/bin/env bash
# scripts/lots/build-lot-3.sh
#
# Lot L3 — Widgets Visualisation
# Branche pivot : ats-lab/comp/widgets/time-series
# Sous-lots :
#   - ats-lab/comp/widgets/time-series  (pivot)
#   - ats-lab/comp/widgets/funnel-chart
#   - ats-lab/comp/widgets/gauge
#   - ats-lab/comp/widgets/heatmap
#
# Usage:
#   ./scripts/lots/build-lot-3.sh                 # dry-run
#   ./scripts/lots/build-lot-3.sh --yes           # exécute
#   ./scripts/lots/build-lot-3.sh --branch-only   # reste sur la branche pivot

set -euo pipefail

LOT_TAG="L3"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"

cd "$ROOT_DIR"

# ─── Options ───────────────────────────────────────────────────────────────
DRY_RUN=1
BRANCH_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y)       DRY_RUN=0 ;;
    --dry-run)      DRY_RUN=1 ;;
    --branch-only)  BRANCH_ONLY=1 ;;
    -h|--help)      sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Argument inconnu: $1" >&2; exit 1 ;;
  esac
  shift
done

# ─── Configuration du lot ─────────────────────────────────────────────────
PIVOT_BRANCH="ats-lab/comp/widgets/time-series"

SUB_LOTS=(
  "ats-lab/comp/widgets/time-series"
  "ats-lab/comp/widgets/funnel-chart"
  "ats-lab/comp/widgets/gauge"
  "ats-lab/comp/widgets/heatmap"
)

# Fichiers attendus dans chaque sous-lot
declare -A SUB_LOT_FILES
SUB_LOT_FILES["ats-lab/comp/widgets/time-series"]="src/widgets/TimeSeries/"
SUB_LOT_FILES["ats-lab/comp/widgets/funnel-chart"]="src/widgets/FunnelChart/"
SUB_LOT_FILES["ats-lab/comp/widgets/gauge"]="src/widgets/Gauge/"
SUB_LOT_FILES["ats-lab/comp/widgets/heatmap"]="src/widgets/Heatmap/"

MODE_LABEL="[DRY-RUN]"
[ "$DRY_RUN" -eq 0 ] && MODE_LABEL="[EXECUTE]"

# ─── Bannière ──────────────────────────────────────────────────────────────
sep
log "Lot L3 — Widgets Visualisation"
log "Mode: $MODE_LABEL"
log "Branche pivot: $PIVOT_BRANCH"
sep
echo ""

# ─── Préflight ─────────────────────────────────────────────────────────────
[ -d .git ] || { err "Pas dans un dépôt git"; exit 1; }
require_clean_tree || exit 1

log "Fetch origin…"
git fetch origin --prune 2>/dev/null || true

# ─── Vérifier les branches sous-lots ──────────────────────────────────────
h1 "Vérification des sous-lots"

MISSING=()
for b in "${SUB_LOTS[@]}"; do
  printf '%-45s ' "$b"
  if remote_branch_exists "$b"; then
    echo "✓"
  else
    echo "✗ MANQUANTE"
    MISSING+=("$b")
  fi
done

if [ "${#MISSING[@]}" -gt 0 ]; then
  err "${#MISSING[@]} sous-lot(s) manquant(s) sur origin"
  exit 1
fi
echo ""

# ─── Se placer sur la branche pivot ───────────────────────────────────────
h1 "Placement sur la branche pivot"

if [ "$DRY_RUN" -eq 1 ]; then
  info "  [dry-run] git checkout $PIVOT_BRANCH"
  info "  [dry-run] git pull origin $PIVOT_BRANCH"
else
  git checkout "$PIVOT_BRANCH" 2>/dev/null || git checkout -b "$PIVOT_BRANCH" "origin/$PIVOT_BRANCH"
  git pull origin "$PIVOT_BRANCH" 2>/dev/null || true
  ok "Sur $PIVOT_BRANCH ($(git rev-parse --short HEAD))"
fi
echo ""

# ─── Fusion des sous-lots ─────────────────────────────────────────────────
h1 "Fusion des sous-lots dans la branche pivot"

TOTAL_COPIED=0
for b in "${SUB_LOTS[@]}"; do
  [ "$b" = "$PIVOT_BRANCH" ] && { info "  ⏭ $b (pivot)"; continue; }

  SCOPE="${SUB_LOT_FILES[$b]}"
  echo ""
  log "▶ $b → $SCOPE"

  # Lister les fichiers dans la branche
  FILES=$(git ls-tree -r "origin/$b" --name-only 2>/dev/null | grep "^$SCOPE" || true)

  if [ -z "$FILES" ]; then
    warn "  aucun fichier trouvé dans $SCOPE sur $b"
    continue
  fi

  COUNT=$(echo "$FILES" | wc -l | tr -d ' ')
  log "  $COUNT fichier(s) à copier"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "$FILES" | head_n 5 | sed 's/^/    /'
    [ "$COUNT" -gt 5 ] && info "    … et $((COUNT-5)) autres"
    TOTAL_COPIED=$((TOTAL_COPIED + COUNT))
    continue
  fi

  # Copier chaque fichier
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    mkdir -p "$(dirname "$f")"
    git show "origin/$b:$f" > "$f"
    TOTAL_COPIED=$((TOTAL_COPIED + 1))
  done <<< "$FILES"

  ok "  $COUNT fichier(s) copiés"
done

echo ""
log "$TOTAL_COPIED fichier(s) au total"
echo ""

# ─── Résumé ────────────────────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 0 ]; then
  h1 "Résumé des modifications"

  if [ -n "$(git status --porcelain)" ]; then
    git status --short | head_n 30 | sed 's/^/  /'
    echo ""
    TOTAL=$(git status --porcelain | wc -l | tr -d ' ')
    log "$TOTAL fichier(s) modifiés/ajoutés"
  else
    warn "Aucune modification détectée"
  fi
fi

echo ""
sep
if [ "$DRY_RUN" -eq 1 ]; then
  warn "DRY-RUN — aucune modification effectuée"
  info ""
  info "Pour exécuter: ./scripts/lots/build-lot-3.sh --yes"
else
  ok "Lot L3 construit"
  info ""
  info "Prochaines étapes:"
  info "  1. Valider: ./scripts/quality/check.sh"
  info "  2. Push: ./scripts/lots/push-lot.sh --lot $PIVOT_BRANCH --files 'src/widgets/TimeSeries/ src/widgets/FunnelChart/ src/widgets/Gauge/ src/widgets/Heatmap/' --message 'feat(L3): widgets visualization' --yes"
fi
sep