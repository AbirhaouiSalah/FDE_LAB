#!/usr/bin/env bash
# scripts/run-dashboard.sh
# Lance le dashboard ATS Copilot en local avec données mockées.
# Usage: ./scripts/run-dashboard.sh [--port 5173] [--no-open] [--build]

set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Options
# ─────────────────────────────────────────────────────────────
PORT=5173
OPEN=1
BUILD=0
for arg in "$@"; do
  case "$arg" in
    --port) PORT="$2"; shift 2 ;;
    --no-open) OPEN=0; shift ;;
    --build) BUILD=1; shift ;;
    -h|--help)
      sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Argument inconnu: $arg" >&2; exit 1 ;;
  esac
done

# ─────────────────────────────────────────────────────────────
# Chemins + couleurs
# ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_DIM=$'\033[2m';    C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_DIM=""; C_RST=""
fi

log()  { printf '%s[dash]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok  ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
die()  { printf '%s[err ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; exit 1; }

# ─────────────────────────────────────────────────────────────
# Pré-vol
# ─────────────────────────────────────────────────────────────
command -v node >/dev/null 2>&1 || die "node introuvable"
command -v pnpm >/dev/null 2>&1 || die "pnpm introuvable (corepack enable)"

[ -f package.json ] || die "package.json introuvable — es-tu dans FDE_LAB/ ?"
[ -d src/widgets/KpiCard ] || die "src/widgets/KpiCard introuvable"
[ -d src/widgets/SmallGroupGuard ] || die "src/widgets/SmallGroupGuard introuvable"

if [ ! -d node_modules ]; then
  warn "node_modules absent — pnpm install"
  pnpm install
fi

# ─────────────────────────────────────────────────────────────
# 1. Données mockées
# ─────────────────────────────────────────────────────────────
MOCK_DIR="src/mock"
MOCK_FILE="$MOCK_DIR/dashboard-data.ts"

log "Génération des données mockées → $MOCK_FILE"
mkdir -p "$MOCK_DIR"

cat > "$MOCK_FILE" <<'EOF'
// AUTO-GENERATED par scripts/run-dashboard.sh — ne pas éditer à la main.
// Données fictives pour la démo locale. Aucune PII.

export interface DemoKpi {
  label: string;
  value: number;
  unit: 'min' | 'h' | 'd' | 'count' | 'pct';
  baseline?: number;
  target?: number;
  status: 'ok' | 'watch' | 'alert';
  lastRefresh: string;
  href?: string;
  n?: number;
}

export const DEMO_KPIS: DemoKpi[] = [
  {
    label: 'Temps médian de pré-screening',
    value: 8.4,
    unit: 'min',
    baseline: 18,
    target: 4,
    status: 'ok',
    lastRefresh: '2026-10-11T08:00:00Z',
    href: '/definitions/median-handling-time',
  },
  {
    label: "Taux d'accord recruteur / copilote",
    value: 87.3,
    unit: 'pct',
    baseline: 82,
    target: 90,
    status: 'watch',
    lastRefresh: '2026-10-11T08:00:00Z',
    href: '/definitions/agreement-rate',
  },
  {
    label: 'Candidats pré-screenés (7j)',
    value: 342,
    unit: 'count',
    baseline: 280,
    status: 'ok',
    lastRefresh: '2026-10-11T08:00:00Z',
  },
  {
    label: 'Taux d’override recruteur',
    value: 12.5,
    unit: 'pct',
    baseline: 18,
    target: 10,
    status: 'watch',
    lastRefresh: '2026-10-11T08:00:00Z',
    href: '/definitions/override-rate',
  },
  {
    label: 'Médiane Porto (groupe réduit)',
    value: 9.2,
    unit: 'min',
    n: 3,
    status: 'ok',
    lastRefresh: '2026-10-11T08:00:00Z',
  },
  {
    label: 'Alertes qualité ouvertes',
    value: 2,
    unit: 'count',
    baseline: 5,
    status: 'alert',
    lastRefresh: '2026-10-11T08:00:00Z',
  },
];

export const DEMO_META = {
  generated_at: '2026-10-11T08:00:00Z',
  site: 'FR' as const,
  rubric_version: 'v2.3.1',
  environment: 'demo' as const,
  warning: 'Données fictives — aucune PII — usage démonstration uniquement.',
};
EOF

ok "données mockées écrites"

# ─────────────────────────────────────────────────────────────
# 2. Page Demo
# ─────────────────────────────────────────────────────────────
DEMO_DIR="src/pages"
DEMO_FILE="$DEMO_DIR/Demo.tsx"

log "Génération de la page démo → $DEMO_FILE"
mkdir -p "$DEMO_DIR"

cat > "$DEMO_FILE" <<'EOF'
// AUTO-GENERATED par scripts/run-dashboard.sh — page de démonstration locale.
import React from 'react';
import { KpiCard } from '../widgets/KpiCard';
import { SmallGroupGuard } from '../widgets/SmallGroupGuard';
import { DEMO_KPIS, DEMO_META } from '../mock/dashboard-data';

const styles: Record<string, React.CSSProperties> = {
  page: {
    fontFamily: 'Inter, system-ui, -apple-system, sans-serif',
    background: '#f9fafb',
    color: '#111827',
    minHeight: '100vh',
    padding: '32px',
    margin: 0,
  },
  header: {
    maxWidth: 1200,
    margin: '0 auto 24px',
  },
  h1: {
    fontSize: 24,
    fontWeight: 700,
    margin: '0 0 8px',
  },
  sub: {
    fontSize: 14,
    color: '#6b7280',
    margin: 0,
  },
  banner: {
    maxWidth: 1200,
    margin: '0 auto 24px',
    padding: '12px 16px',
    background: '#fef3c7',
    border: '1px solid #f59e0b',
    borderRadius: 8,
    fontSize: 14,
    color: '#92400e',
  },
  grid: {
    maxWidth: 1200,
    margin: '0 auto',
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))',
    gap: 24,
  },
  card: {
    background: '#ffffff',
    borderRadius: 8,
    padding: 16,
    boxShadow: '0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04)',
  },
  section: {
    maxWidth: 1200,
    margin: '40px auto 16px',
    fontSize: 18,
    fontWeight: 600,
  },
  footer: {
    maxWidth: 1200,
    margin: '48px auto 0',
    fontSize: 12,
    color: '#9ca3af',
    textAlign: 'center' as const,
  },
};

export function Demo() {
  return (
    <main style={styles.page}>
      <header style={styles.header}>
        <h1 style={styles.h1}>ATS Copilot — Démo locale</h1>
        <p style={styles.sub}>
          Rubric {DEMO_META.rubric_version} · Site {DEMO_META.site} ·
          Généré le {new Date(DEMO_META.generated_at).toLocaleString('fr-FR')}
        </p>
      </header>

      <div style={styles.banner} role="note">
        ⚠️ {DEMO_META.warning}
      </div>

      <h2 style={styles.section}>KPI principaux</h2>
      <section style={styles.grid} aria-label="KPI principaux">
        {DEMO_KPIS.slice(0, 4).map((kpi) => (
          <div key={kpi.label} style={styles.card}>
            <KpiCard
              label={kpi.label}
              value={kpi.value}
              unit={kpi.unit}
              baseline={kpi.baseline}
              target={kpi.target}
              status={kpi.status}
              lastRefresh={kpi.lastRefresh}
              href={kpi.href}
              n={kpi.n}
            />
          </div>
        ))}
      </section>

      <h2 style={styles.section}>Cas limites RGPD</h2>
      <section style={styles.grid} aria-label="Cas limites RGPD">
        <div style={styles.card}>
          <KpiCard
            label="Médiane Porto (n=3, masqué)"
            value={9.2}
            unit="min"
            n={3}
            status="ok"
            lastRefresh="2026-10-11T08:00:00Z"
          />
        </div>

        <div style={styles.card}>
          <SmallGroupGuard n={2} context="Fairness par site">
            <p style={{ margin: 0 }}>Cet agrégat ne devrait jamais apparaître.</p>
          </SmallGroupGuard>
        </div>

        <div style={styles.card}>
          <SmallGroupGuard n={42} context="Fairness par site">
            <p style={{ margin: 0 }}>Agrégat visible (n=42, seuil respecté).</p>
          </SmallGroupGuard>
        </div>
      </section>

      <h2 style={styles.section}>Tous les statuts</h2>
      <section style={styles.grid} aria-label="Tous les statuts">
        {(['ok', 'watch', 'alert'] as const).map((status) => (
          <div key={status} style={styles.card}>
            <KpiCard
              label={`Statut: ${status}`}
              value={status === 'ok' ? 8.4 : status === 'watch' ? 12.5 : 2}
              unit={status === 'alert' ? 'count' : 'pct'}
              status={status}
              baseline={20}
              target={5}
              lastRefresh="2026-10-11T08:00:00Z"
            />
          </div>
        ))}
      </section>

      <footer style={styles.footer}>
        ATS Copilot Dashboard · ALTEN FDE Lab · read-only · aucune décision automatique
      </footer>
    </main>
  );
}
EOF

ok "page démo écrite"

# ─────────────────────────────────────────────────────────────
# 3. Entrée Vite temporaire (si l'entrée actuelle ne sert pas Demo)
# ─────────────────────────────────────────────────────────────
INDEX_FILE="index.html"

if [ -f "$INDEX_FILE" ]; then
  if ! grep -q "Demo" "$INDEX_FILE"; then
    log "index.html ne référence pas Demo — génération d'un index-demo.html"
    cat > "index-demo.html" <<'EOF'
<!doctype html>
<html lang="fr">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>ATS Copilot — Démo locale</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/demo-entry.tsx"></script>
  </body>
</html>
EOF
    cat > "src/demo-entry.tsx" <<'EOF'
import React from 'react';
import { createRoot } from 'react-dom/client';
import { Demo } from './pages/Demo';

const container = document.getElementById('root');
if (!container) throw new Error('#root not found');
createRoot(container).render(
  <React.StrictMode>
    <Demo />
  </React.StrictMode>
);
EOF
    ok "entrée démo créée (index-demo.html)"
    ENTRY="index-demo.html"
  else
    ok "index.html semble déjà pointer sur Demo"
    ENTRY="$INDEX_FILE"
  fi
else
  warn "index.html absent — création d'un index minimal"
  cat > "index-demo.html" <<'EOF'
<!doctype html>
<html lang="fr">
  <head><meta charset="UTF-8" /><title>ATS Copilot</title></head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/demo-entry.tsx"></script>
  </body>
</html>
EOF
  cat > "src/demo-entry.tsx" <<'EOF'
import React from 'react';
import { createRoot } from 'react-dom/client';
import { Demo } from './pages/Demo';
const c = document.getElementById('root');
if (!c) throw new Error('#root not found');
createRoot(c).render(<React.StrictMode><Demo /></React.StrictMode>);
EOF
  ENTRY="index-demo.html"
fi

# ─────────────────────────────────────────────────────────────
# 4. Vérification TypeScript rapide
# ─────────────────────────────────────────────────────────────
log "Vérification TypeScript…"
if ! pnpm exec tsc --noEmit --skipLibCheck >/dev/null 2>&1; then
  warn "tsc a signalé des erreurs — le dashboard peut quand même démarrer"
  warn "relance 'pnpm exec tsc --noEmit' pour voir le détail"
else
  ok "typecheck OK"
fi

# ─────────────────────────────────────────────────────────────
# 5. Mode build (one-shot)
# ─────────────────────────────────────────────────────────────
if [ "$BUILD" -eq 1 ]; then
  log "Build de production…"
  pnpm exec vite build --outDir dist-demo 2>&1 | tail -20
  ok "build terminé → dist-demo/"
  log "Pour servir : pnpm exec vite preview --outDir dist-demo --port $PORT"
  exit 0
fi

# ─────────────────────────────────────────────────────────────
# 6. Lancement Vite dev
# ─────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════"
ok "Dashboard prêt à démarrer"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "  URL   : ${C_BLU}http://localhost:$PORT/${C_RST}"
echo "  Entrée: $ENTRY"
echo "  Quit  : Ctrl+C"
echo ""

URL="http://localhost:$PORT/"

if [ "$OPEN" -eq 1 ]; then
  (sleep 2 && {
    if command -v open >/dev/null 2>&1; then open "$URL"
    elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$URL"
    fi
  }) &
fi

exec pnpm exec vite --port "$PORT" --host 127.0.0.1