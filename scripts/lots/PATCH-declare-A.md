# Patch manuel : remplacer `declare -A` (bash 3.2)

Généré le 2026-10-14T17:38:13Z

## Fichiers concernés

### `scripts/lots/build-lot-3.sh`

```bash
```

**Remplacement type :**

```bash
# Avant :
declare -A MAP=(
  [key1]="val1"
  [key2]="val2"
)
echo "${MAP[$k]}"

# Après (bash 3.2 safe) :
lookup_map() {
  case "$1" in
    key1) echo "val1" ;;
    key2) echo "val2" ;;
    *) echo "$1" ;;
  esac
}
echo "$(lookup_map "$k")"
```


## Ligne exacte à modifier dans build-lot-3.sh

```
53:declare -A SUB_LOT_FILES
```

## Contexte (lignes 45-70)

```bash
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
```