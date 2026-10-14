#!/usr/bin/env bash
# scripts/quality/patch.sh
# Applique les correctifs post-refacto :
#   1. Ajoute .backups/** aux ignores d'ESLint
#   2. Réécrit les 6 tests de widgets affaiblis (AlertPanel, FunnelChart, Gauge, Heatmap, QueueTable, TimeSeries)
#   3. Retire l'import 'screen' inutilisé des tests concernés
#   4. Relance le check complet
#
# Idempotent. Backup horodaté dans .backups/patch-<ts>/.
#
# Usage:
#   ./scripts/quality/patch.sh --dry-run     # affiche sans modifier
#   ./scripts/quality/patch.sh               # applique
#   ./scripts/quality/patch.sh --no-check    # applique sans relancer check
#   ./scripts/quality/patch.sh --rollback    # restaure le dernier backup

set -euo pipefail

DRY_RUN=0
RUN_CHECK=1
ROLLBACK=0
for arg in "$@"; do
  case "$arg" in
    --dry-run)  DRY_RUN=1 ;;
    --no-check) RUN_CHECK=0 ;;
    --rollback) ROLLBACK=1 ;;
    -h|--help)  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Argument inconnu: $arg" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT_DIR"

# Couleurs
if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_DIM=$'\033[2m';    C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_DIM=""; C_RST=""
fi

log()  { printf '%s[patch]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok   ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn ]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
die()  { printf '%s[err  ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; exit 1; }

BACKUP_DIR=".backups/patch-$(date +%Y%m%d-%H%M%S)"

# ─────────────────────────────────────────────────────────────
# Rollback
# ─────────────────────────────────────────────────────────────
if [ "$ROLLBACK" -eq 1 ]; then
  LAST="$(ls -1dt .backups/patch-* 2>/dev/null | head -n 1 || true)"
  [ -n "$LAST" ] || die "aucun backup .backups/patch-*"
  log "Restauration depuis $LAST"
  for f in $(cd "$LAST" && find . -type f | sed 's|^\./||'); do
    mkdir -p "$(dirname "$f")"
    cp "$LAST/$f" "$f"
    ok "restauré $f"
  done
  exit 0
fi

# ─────────────────────────────────────────────────────────────
# Pré-vol
# ─────────────────────────────────────────────────────────────
[ -f package.json ] || die "package.json introuvable — es-tu à la racine ?"
[ -f eslint.config.js ] || die "eslint.config.js introuvable"
[ -d src/widgets ] || die "src/widgets introuvable"

# ─────────────────────────────────────────────────────────────
# Backup ciblé
# ─────────────────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 0 ]; then
  mkdir -p "$BACKUP_DIR"

  cp eslint.config.js "$BACKUP_DIR/eslint.config.js"

  for w in AlertPanel FunnelChart Gauge Heatmap QueueTable TimeSeries; do
    f="src/widgets/${w}/${w}.test.tsx"
    if [ -f "$f" ]; then
      mkdir -p "$BACKUP_DIR/src/widgets/${w}"
      cp "$f" "$BACKUP_DIR/$f"
    fi
  done

  ok "backup → $BACKUP_DIR"
fi

# Helper d'écriture
write() {
  local path="$1"; shift
  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry] écrirait $path"
    cat > /dev/null
    return 0
  fi
  mkdir -p "$(dirname "$path")"
  cat > "$path"
  ok "$path"
}

# ─────────────────────────────────────────────────────────────
# 1. Patch eslint.config.js — ajouter .backups/** aux ignores
# ─────────────────────────────────────────────────────────────
log "1/3 — Patch eslint.config.js (ignores .backups/**)…"

if grep -q "'.backups/\*\*'" eslint.config.js; then
  ok "déjà patché — skip"
else
  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry] ajouterait '.backups/**' aux ignores"
  else
    # Insérer la ligne juste après "ignores: ["
    perl -i -pe "s/(ignores:\s*\[)/\$1\n    '.backups\/**',/" eslint.config.js
    ok ".backups/** ajouté aux ignores"
  fi
fi

# Vérification syntaxique
if [ "$DRY_RUN" -eq 0 ]; then
  if node --input-type=module -e "import('./eslint.config.js').then(()=>process.exit(0)).catch(e=>{console.error(e.message);process.exit(1)})" 2>/dev/null; then
    ok "eslint.config.js valide"
  else
    warn "eslint.config.js invalide — restauration"
    cp "$BACKUP_DIR/eslint.config.js" eslint.config.js
    die "config restaurée — vérifie manuellement"
  fi
fi

# ─────────────────────────────────────────────────────────────
# 2. Réécriture des 6 tests de widgets affaiblis
# ─────────────────────────────────────────────────────────────
log "2/3 — Réécriture des tests widgets…"

# AlertPanel
write src/widgets/AlertPanel/AlertPanel.test.tsx <<'EOF'
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { AlertPanel } from './AlertPanel';
import type { Alert } from '../../mock/data';

describe('AlertPanel', () => {
  it('renders empty state when no alerts', () => {
    render(<AlertPanel alerts={[]} />);
    expect(screen.getByTestId('alert-panel')).toHaveTextContent(/aucune alerte/i);
  });

  it('renders all alerts with title and description', () => {
    const alerts: Alert[] = [
      { id: '1', level: 'warn', title: 'Alerte A', description: 'Description A' },
      { id: '2', level: 'info', title: 'Alerte B', description: 'Description B' },
    ];
    render(<AlertPanel alerts={alerts} />);
    expect(screen.getByText('Alerte A')).toBeInTheDocument();
    expect(screen.getByText('Alerte B')).toBeInTheDocument();
    expect(screen.getByText('Description A')).toBeInTheDocument();
    expect(screen.getByText('Description B')).toBeInTheDocument();
  });

  it('assigns role=alert to error-level alerts', () => {
    const alerts: Alert[] = [
      { id: '1', level: 'error', title: 'Erreur', description: 'Détail' },
    ];
    render(<AlertPanel alerts={alerts} />);
    expect(screen.getByRole('alert')).toBeInTheDocument();
  });

  it('assigns role=status to non-error alerts', () => {
    const alerts: Alert[] = [
      { id: '1', level: 'warn', title: 'Warn', description: 'Détail' },
    ];
    render(<AlertPanel alerts={alerts} />);
    expect(screen.getByRole('status')).toBeInTheDocument();
  });

  it('exposes region with aria-label', () => {
    const alerts: Alert[] = [
      { id: '1', level: 'info', title: 'Info', description: 'Détail' },
    ];
    render(<AlertPanel alerts={alerts} />);
    expect(screen.getByRole('region', { name: /alertes/i })).toBeInTheDocument();
  });
});
EOF

# FunnelChart
write src/widgets/FunnelChart/FunnelChart.test.tsx <<'EOF'
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { FunnelChart } from './FunnelChart';

describe('FunnelChart', () => {
  it('renders empty state when no stages', () => {
    render(<FunnelChart stages={[]} />);
    expect(screen.getByTestId('funnel-chart')).toHaveTextContent(/aucune étape/i);
  });

  it('renders one row per stage', () => {
    render(<FunnelChart stages={[
      { label: 'Sourced', value: 1000 },
      { label: 'Screened', value: 500 },
      { label: 'Offer', value: 50 },
    ]} />);
    expect(screen.getByText('Sourced')).toBeInTheDocument();
    expect(screen.getByText('Screened')).toBeInTheDocument();
    expect(screen.getByText('Offer')).toBeInTheDocument();
  });

  it('shows the raw value formatted in fr-FR', () => {
    render(<FunnelChart stages={[{ label: 'Sourced', value: 1240 }]} />);
    // 1 240 avec espace fine insécable
    expect(screen.getByText(/1\s*240/)).toBeInTheDocument();
  });

  it('shows conversion percentage for non-first stages', () => {
    render(<FunnelChart stages={[
      { label: 'Sourced', value: 1000 },
      { label: 'Screened', value: 500 },
    ]} />);
    // 500/1000 = 50 %
    expect(screen.getByText(/50\s*%/)).toBeInTheDocument();
  });

  it('shows em dash for the first stage (no conversion)', () => {
    render(<FunnelChart stages={[{ label: 'Sourced', value: 1000 }]} />);
    expect(screen.getByText('—')).toBeInTheDocument();
  });
});
EOF

# Gauge
write src/widgets/Gauge/Gauge.test.tsx <<'EOF'
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { Gauge } from './Gauge';

describe('Gauge', () => {
  it('renders the label', () => {
    render(<Gauge value={88.5} label="Taux d'accord" />);
    expect(screen.getByText("Taux d'accord")).toBeInTheDocument();
  });

  it('formats the value with one decimal and %', () => {
    render(<Gauge value={88.456} label="x" />);
    expect(screen.getByText(/88\.5\s*%/)).toBeInTheDocument();
  });

  it('uses ok color for value >= 85', () => {
    const { container } = render(<Gauge value={90} label="x" />);
    const svg = container.querySelector('svg');
    expect(svg?.innerHTML).toContain('var(--color-ok)');
  });

  it('uses watch color for 70 <= value < 85', () => {
    const { container } = render(<Gauge value={75} label="x" />);
    const svg = container.querySelector('svg');
    expect(svg?.innerHTML).toContain('var(--color-watch)');
  });

  it('uses alert color for value < 70', () => {
    const { container } = render(<Gauge value={50} label="x" />);
    const svg = container.querySelector('svg');
    expect(svg?.innerHTML).toContain('var(--color-alert)');
  });

  it('clamps value to 0-100', () => {
    render(<Gauge value={150} label="x" />);
    expect(screen.getByText(/100\.0\s*%/)).toBeInTheDocument();
  });

  it('wraps in data-testid=gauge', () => {
    render(<Gauge value={50} label="x" />);
    expect(screen.getByTestId('gauge')).toBeInTheDocument();
  });
});
EOF

# Heatmap
write src/widgets/Heatmap/Heatmap.test.tsx <<'EOF'
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { Heatmap } from './Heatmap';
import type { HeatCell } from '../../mock/data';

describe('Heatmap', () => {
  const cells: HeatCell[] = [
    { dimension: 'Site', group: 'FR', value: 8.4, n: 220 },
    { dimension: 'Site', group: 'PT', value: 9.2, n: 122 },
    { dimension: 'Cohorte', group: 'Junior', value: 9.6, n: 154 },
    { dimension: 'Cohorte', group: 'Stage', value: 10.2, n: 42 },
  ];

  it('renders a table with aria-label', () => {
    render(<Heatmap cells={cells} />);
    expect(screen.getByRole('table', { name: /heatmap/i })).toBeInTheDocument();
  });

  it('exposes data-testid=heatmap', () => {
    render(<Heatmap cells={cells} />);
    expect(screen.getByTestId('heatmap')).toBeInTheDocument();
  });

  it('renders one row per dimension', () => {
    render(<Heatmap cells={cells} />);
    expect(screen.getByText('Site')).toBeInTheDocument();
    expect(screen.getByText('Cohorte')).toBeInTheDocument();
  });

  it('renders the value inside each cell', () => {
    render(<Heatmap cells={cells} />);
    expect(screen.getByText('8.4')).toBeInTheDocument();
    expect(screen.getByText('9.2')).toBeInTheDocument();
  });

  it('masks cells with n < 5 with n<5', () => {
    const small: HeatCell[] = [
      { dimension: 'Site', group: 'FR', value: 8.4, n: 3 },
    ];
    render(<Heatmap cells={small} />);
    expect(screen.getByText('n<5')).toBeInTheDocument();
  });
});
EOF

# QueueTable
write src/widgets/QueueTable/QueueTable.test.tsx <<'EOF'
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { QueueTable } from './QueueTable';
import type { QueueRow } from '../../mock/data';

describe('QueueTable', () => {
  it('renders empty state when no rows', () => {
    render(<QueueTable rows={[]} />);
    expect(screen.getByTestId('queue-table')).toHaveTextContent(/file vide/i);
  });

  it('renders all rows', () => {
    const rows: QueueRow[] = [
      { id: 'C-1', site: 'FR', score: 87, status: 'pending', waiting: '2 h' },
      { id: 'C-2', site: 'PT', score: 74, status: 'review',  waiting: '4 h' },
      { id: 'C-3', site: 'FR', score: 91, status: 'done',    waiting: '—' },
    ];
    render(<QueueTable rows={rows} />);
    expect(screen.getByText('C-1')).toBeInTheDocument();
    expect(screen.getByText('C-2')).toBeInTheDocument();
    expect(screen.getByText('C-3')).toBeInTheDocument();
  });

  it('shows FR / PT sites', () => {
    render(<QueueTable rows={[
      { id: 'C-1', site: 'FR', score: 87, status: 'pending', waiting: '2 h' },
      { id: 'C-2', site: 'PT', score: 74, status: 'review',  waiting: '4 h' },
    ]} />);
    expect(screen.getByText('FR')).toBeInTheDocument();
    expect(screen.getByText('PT')).toBeInTheDocument();
  });

  it('labels statuses correctly', () => {
    render(<QueueTable rows={[
      { id: 'C-1', site: 'FR', score: 87, status: 'pending', waiting: '2 h' },
      { id: 'C-2', site: 'PT', score: 74, status: 'review',  waiting: '4 h' },
      { id: 'C-3', site: 'FR', score: 91, status: 'done',    waiting: '—' },
    ]} />);
    expect(screen.getByText('En attente')).toBeInTheDocument();
    expect(screen.getByText('À revoir')).toBeInTheDocument();
    expect(screen.getByText('Traité')).toBeInTheDocument();
  });

  it('exposes data-testid=queue-table', () => {
    render(<QueueTable rows={[
      { id: 'C-1', site: 'FR', score: 87, status: 'pending', waiting: '2 h' },
    ]} />);
    expect(screen.getByTestId('queue-table')).toBeInTheDocument();
  });
});
EOF

# TimeSeries
write src/widgets/TimeSeries/TimeSeries.test.tsx <<'EOF'
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { TimeSeries } from './TimeSeries';

describe('TimeSeries', () => {
  const data = [
    { day: 'J-2', fr: 9.8, pt: 12.4 },
    { day: 'J-1', fr: 8.4, pt: 9.5 },
    { day: 'J-0', fr: 8.4, pt: 9.2 },
  ];

  it('renders empty state when no data', () => {
    render(<TimeSeries data={[]} />);
    expect(screen.getByTestId('time-series')).toHaveTextContent(/aucune donnée/i);
  });

  it('renders the SVG with an aria-label', () => {
    render(<TimeSeries data={data} yLabel="min" />);
    expect(screen.getByRole('img', { name: /série temporelle/i })).toBeInTheDocument();
  });

  it('renders the legend with both sites', () => {
    render(<TimeSeries data={data} />);
    expect(screen.getByText('France')).toBeInTheDocument();
    expect(screen.getByText('Porto')).toBeInTheDocument();
  });

  it('exposes data-testid=time-series', () => {
    render(<TimeSeries data={data} />);
    expect(screen.getByTestId('time-series')).toBeInTheDocument();
  });

  it('shows the unit in the legend', () => {
    render(<TimeSeries data={data} yLabel="min" />);
    expect(screen.getByText(/unité :\s*min/i)).toBeInTheDocument();
  });
});
EOF

# ─────────────────────────────────────────────────────────────
# 3. Vérification du test:a11y + relance check
# ─────────────────────────────────────────────────────────────
log "3/3 — Vérification + relance check…"

# Vérifier que les widgets ont bien un data-testid racine (peut être manquant dans certains)
check_testid() {
  local f="$1" testid="$2"
  if ! grep -q "data-testid=\"$testid\"" "$f"; then
    warn "$f ne définit pas data-testid=\"$testid\" — un test peut échouer"
  fi
}

check_testid src/widgets/AlertPanel/AlertPanel.tsx    alert-panel
check_testid src/widgets/FunnelChart/FunnelChart.tsx  funnel-chart
check_testid src/widgets/Gauge/Gauge.tsx              gauge
check_testid src/widgets/Heatmap/Heatmap.tsx          heatmap
check_testid src/widgets/QueueTable/QueueTable.tsx    queue-table
check_testid src/widgets/TimeSeries/TimeSeries.tsx    time-series

if [ "$RUN_CHECK" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
  echo ""
  log "Relance ./scripts/quality/check.sh…"
  echo ""
  if ./scripts/quality/check.sh; then
    ok "✅ check complet passé"
  else
    warn "check a échoué — relance ./scripts/quality/check.sh pour le détail"
    warn "rollback : ./scripts/quality/patch.sh --rollback"
    exit 1
  fi
fi

echo ""
echo "════════════════════════════════════════════════════════════"
if [ "$DRY_RUN" -eq 1 ]; then
  ok "dry-run terminé — rien n'a été modifié"
else
  ok "Patch appliqué"
  echo "  Backup : $BACKUP_DIR"
  echo "  Rollback : ./scripts/quality/patch.sh --rollback"
fi
echo "════════════════════════════════════════════════════════════"