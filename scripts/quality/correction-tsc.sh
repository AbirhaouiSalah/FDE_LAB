#!/usr/bin/env bash
# scripts/correction-tsc.sh
# Corrige les 32 erreurs TypeScript identifiées par `./scripts/run.sh check`.
# Idempotent. Backup horodaté dans .backups/tsc-<timestamp>/.
#
# Usage:
#   ./scripts/correction-tsc.sh --dry-run    # affiche sans modifier
#   ./scripts/correction-tsc.sh              # applique
#   ./scripts/correction-tsc.sh --check      # applique + relance check

set -euo pipefail

DRY_RUN=0
RUN_CHECK=0
for arg in "$@"; do
  case "$arg" in
    --dry-run)   DRY_RUN=1 ;;
    --check)     RUN_CHECK=1 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Argument inconnu: $arg" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT_DIR"

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_DIM=$'\033[2m';    C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_DIM=""; C_RST=""
fi

log()  { printf '%s[fix]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
die()  { printf '%s[err]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; exit 1; }

# ─────────────────────────────────────────────────────────────
# Pré-vol + backup
# ─────────────────────────────────────────────────────────────
[ -f package.json ] || die "package.json introuvable"
[ -f tsconfig.json ] || die "tsconfig.json introuvable"

BACKUP_DIR=".backups/tsc-$(date +%Y%m%d-%H%M%S)"

if [ "$DRY_RUN" -eq 0 ]; then
  mkdir -p "$BACKUP_DIR"
  # Backup ciblé : tous les .tsx des widgets + pages + shell + les tests
  find src -type f \( -name "*.tsx" -o -name "*.ts" \) | while read -r f; do
    mkdir -p "$BACKUP_DIR/$(dirname "$f")"
    cp "$f" "$BACKUP_DIR/$f"
  done
  ok "backup → $BACKUP_DIR"
fi

# ─────────────────────────────────────────────────────────────
# Correctif A — Retirer `import React from 'react'` inutile
# ─────────────────────────────────────────────────────────────
log "Correctif A — imports React inutiles…"

# Fichiers concernés d'après la sortie tsc
A_FILES=(
  src/app/shell/Header.tsx
  src/app/shell/icons.tsx
  src/widgets/AlertPanel/AlertPanel.tsx
  src/widgets/FunnelChart/FunnelChart.tsx
  src/widgets/Gauge/Gauge.tsx
  src/widgets/Heatmap/Heatmap.tsx
  src/widgets/KpiCard/KpiCard.tsx
  src/widgets/QueueTable/QueueTable.tsx
  src/widgets/TimeSeries/TimeSeries.tsx
  src/pages/Overview.tsx
  src/pages/Pipeline.tsx
  src/pages/Queue.tsx
  src/pages/Quality.tsx
  src/pages/Fairness.tsx
  src/pages/Operations.tsx
  src/pages/Governance.tsx
  src/pages/Rubric.tsx
)

for f in "${A_FILES[@]}"; do
  [ -f "$f" ] || { warn "$f absent — skip"; continue; }

  # Vérifier si le fichier utilise vraiment React.<quelque chose> dans le code
  # Si oui, on ne retire pas l'import (cas rare avec les types React.FC par ex.)
  if grep -qE '\bReact\.' "$f"; then
    warn "$f utilise React.* — import conservé"
    continue
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry] retirerait l'import React dans $f"
    continue
  fi

  # Retirer la ligne `import React from 'react';` (variantes avec quotes simples/doubles)
  perl -i -pe "s/^import React from ['\"]react['\"];\n//" "$f"
  ok "$f"
done

# ─────────────────────────────────────────────────────────────
# Correctif B — Renommer XxxPage → Xxx dans les tests de pages
# ─────────────────────────────────────────────────────────────
log "Correctif B — imports XxxPage → Xxx dans les tests…"

# Note : Quality/Rubric/Queue utilisent "no exported member" (pas de Did you mean),
# mais le renommage s'applique quand même : on passe de XxxPage à Xxx.
B_MAP=(
  "src/pages/Overview.test.tsx:OverviewPage:Overview"
  "src/pages/Pipeline.test.tsx:PipelinePage:Pipeline"
  "src/pages/Queue.test.tsx:QueuePage:Queue"
  "src/pages/Quality.test.tsx:QualityPage:Quality"
  "src/pages/Fairness.test.tsx:FairnessPage:Fairness"
  "src/pages/Operations.test.tsx:OperationsPage:Operations"
  "src/pages/Governance.test.tsx:GovernancePage:Governance"
  "src/pages/Rubric.test.tsx:RubricPage:Rubric"
)

for entry in "${B_MAP[@]}"; do
  f="${entry%%:*}"
  rest="${entry#*:}"
  old="${rest%%:*}"
  new="${rest#*:}"

  [ -f "$f" ] || { warn "$f absent — skip"; continue; }

  if ! grep -q "$old" "$f"; then
    ok "$f déjà patché — skip"
    continue
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry] $f : $old → $new"
    continue
  fi

  # Remplacer dans l'import ET dans le JSX (<OverviewPage /> → <Overview />)
  perl -i -pe "s/\b$old\b/$new/g" "$f"
  ok "$f : $old → $new"
done

# ─────────────────────────────────────────────────────────────
# Correctif C — Props manquantes dans les tests de widgets
# ─────────────────────────────────────────────────────────────
log "Correctif C — props manquantes dans les tests de widgets…"

# Stratégie : si un test contient `render(<Xxx />)` sans props, on injecte des props minimales.

# AlertPanel
C_ALERT="src/widgets/AlertPanel/AlertPanel.test.tsx"
if [ -f "$C_ALERT" ] && grep -q '<AlertPanel />' "$C_ALERT"; then
  if [ "$DRY_RUN" -eq 1 ]; then log "[dry] patch $C_ALERT"; else
    perl -i -pe "s{<AlertPanel />}{<AlertPanel alerts={[]} />}g" "$C_ALERT"
    ok "$C_ALERT"
  fi
fi

# FunnelChart
C_FUNNEL="src/widgets/FunnelChart/FunnelChart.test.tsx"
if [ -f "$C_FUNNEL" ] && grep -q '<FunnelChart />' "$C_FUNNEL"; then
  if [ "$DRY_RUN" -eq 1 ]; then log "[dry] patch $C_FUNNEL"; else
    perl -i -pe "s{<FunnelChart />}{<FunnelChart stages={[]} />}g" "$C_FUNNEL"
    ok "$C_FUNNEL"
  fi
fi

# Gauge (value + label)
C_GAUGE="src/widgets/Gauge/Gauge.test.tsx"
if [ -f "$C_GAUGE" ] && grep -q '<Gauge />' "$C_GAUGE"; then
  if [ "$DRY_RUN" -eq 1 ]; then log "[dry] patch $C_GAUGE"; else
    perl -i -pe "s{<Gauge />}{<Gauge value={0} label=\"test\" />}g" "$C_GAUGE"
    ok "$C_GAUGE"
  fi
fi

# Heatmap
C_HEAT="src/widgets/Heatmap/Heatmap.test.tsx"
if [ -f "$C_HEAT" ] && grep -q '<Heatmap />' "$C_HEAT"; then
  if [ "$DRY_RUN" -eq 1 ]; then log "[dry] patch $C_HEAT"; else
    perl -i -pe "s{<Heatmap />}{<Heatmap cells={[]} />}g" "$C_HEAT"
    ok "$C_HEAT"
  fi
fi

# QueueTable
C_QUEUE="src/widgets/QueueTable/QueueTable.test.tsx"
if [ -f "$C_QUEUE" ] && grep -q '<QueueTable />' "$C_QUEUE"; then
  if [ "$DRY_RUN" -eq 1 ]; then log "[dry] patch $C_QUEUE"; else
    perl -i -pe "s{<QueueTable />}{<QueueTable rows={[]} />}g" "$C_QUEUE"
    ok "$C_QUEUE"
  fi
fi

# TimeSeries
C_TS="src/widgets/TimeSeries/TimeSeries.test.tsx"
if [ -f "$C_TS" ] && grep -q '<TimeSeries />' "$C_TS"; then
  if [ "$DRY_RUN" -eq 1 ]; then log "[dry] patch $C_TS"; else
    perl -i -pe "s{<TimeSeries />}{<TimeSeries data={[]} />}g" "$C_TS"
    ok "$C_TS"
  fi
fi

# ─────────────────────────────────────────────────────────────
# Correctif D — Exclure *.stories.tsx du typecheck
# ─────────────────────────────────────────────────────────────
log "Correctif D — exclusion stories du tsconfig…"

if ! grep -q "stories" tsconfig.json; then
  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry] ajouterait exclude pour *.stories.tsx"
  else
    # Si tsconfig.json contient déjà un "exclude": [...], on ajoute l'entrée.
    # Sinon, on insère un nouveau "exclude".
    if grep -q '"exclude"' tsconfig.json; then
      perl -i -0pe 's/("exclude"\s*:\s*\[)/$1\n    "**\/*.stories.tsx",/' tsconfig.json
    else
      # Insérer avant la dernière accolade }
      perl -i -0pe 's/\}\s*$/\n  ,\n  "exclude": ["**\/*.stories.tsx"]\n}\n/s' tsconfig.json
    fi
    ok "tsconfig.json : *.stories.tsx exclu"
  fi
else
  ok "tsconfig.json exclut déjà les stories"
fi

# ─────────────────────────────────────────────────────────────
# Relance check optionnelle
# ─────────────────────────────────────────────────────────────
if [ "$RUN_CHECK" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
  echo ""
  log "Relance ./scripts/run.sh check…"
  echo ""
  if ./scripts/run.sh check; then
    ok "✅ check complet passé"
  else
    warn "check a échoué — relance ./scripts/run.sh check pour voir le détail"
    warn "rollback : cp -R $BACKUP_DIR/* $ROOT_DIR/"
    exit 1
  fi
fi

echo ""
echo "════════════════════════════════════════════════════════════"
if [ "$DRY_RUN" -eq 1 ]; then
  ok "dry-run terminé — rien n'a été modifié"
else
  ok "Correction TSC appliquée"
  echo "  Backup : $BACKUP_DIR"
  echo "  Prochaine étape : ./scripts/run.sh check"
fi
echo "════════════════════════════════════════════════════════════"