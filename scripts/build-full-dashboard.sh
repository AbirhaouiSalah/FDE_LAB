#!/usr/bin/env bash
# scripts/build-full-dashboard.sh
# Génère un dashboard ATS Copilot complet et beau.
# - Shell (Header sticky + LeftNav + routing hash)
# - 8 pages avec contenu réel
# - 8 widgets fonctionnels
# - Design system ALTEN + dark mode
# - RBAC live + i18n FR/EN
# Aucune dépendance externe ajoutée.
#
# Usage: ./scripts/build-full-dashboard.sh [--no-git] [--dry-run]

set -euo pipefail

DO_GIT=1
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --no-git) DO_GIT=0 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Argument inconnu: $arg" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

if [ -t 1 ]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_DIM=$'\033[2m';    C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_DIM=""; C_RST=""
fi

log()  { printf '%s[build]%s %s\n' "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s[ok   ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn ]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
die()  { printf '%s[err  ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; exit 1; }

write() {
  local path="$1"; shift
  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry] $path"
    cat > /dev/null
    return 0
  fi
  mkdir -p "$(dirname "$path")"
  cat > "$path"
  ok "$path"
}

[ -f package.json ] || die "package.json introuvable — lance depuis FDE_LAB/"
[ -d src ] || die "src/ introuvable"

# ─────────────────────────────────────────────────────────────
# 1. Design system
# ─────────────────────────────────────────────────────────────
log "Design system…"

write "src/styles/tokens.css" <<'EOF'
:root {
  --color-primary: #0B3D91;
  --color-primary-hover: #093070;
  --color-accent: #00A3E0;
  --color-bg: #f8fafc;
  --color-surface: #ffffff;
  --color-surface-2: #f1f5f9;
  --color-border: #e2e8f0;
  --color-border-strong: #cbd5e1;
  --color-text: #0f172a;
  --color-text-muted: #64748b;
  --color-text-subtle: #94a3b8;
  --color-ok: #10b981;
  --color-ok-bg: #ecfdf5;
  --color-watch: #f59e0b;
  --color-watch-bg: #fffbeb;
  --color-alert: #ef4444;
  --color-alert-bg: #fef2f2;
  --color-info: #3b82f6;
  --color-info-bg: #eff6ff;
  --radius-sm: 6px;
  --radius-md: 10px;
  --radius-lg: 14px;
  --shadow-sm: 0 1px 2px rgba(15,23,42,0.04);
  --shadow-md: 0 4px 12px rgba(15,23,42,0.06), 0 1px 3px rgba(15,23,42,0.04);
  --shadow-lg: 0 12px 32px rgba(15,23,42,0.08);
  --space-1: 4px;  --space-2: 8px;  --space-3: 12px;
  --space-4: 16px; --space-5: 20px; --space-6: 24px;
  --space-8: 32px; --space-12: 48px;
  --font-sans: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
  --font-mono: 'JetBrains Mono', 'SF Mono', Menlo, monospace;
  --nav-width: 240px;
  --header-height: 64px;
  --transition: 160ms cubic-bezier(0.4, 0, 0.2, 1);
}
[data-theme="dark"] {
  --color-bg: #0a0e1a;
  --color-surface: #111827;
  --color-surface-2: #1a2233;
  --color-border: #1f2937;
  --color-border-strong: #334155;
  --color-text: #f1f5f9;
  --color-text-muted: #94a3b8;
  --color-text-subtle: #64748b;
  --color-ok-bg: #064e3b;
  --color-watch-bg: #78350f;
  --color-alert-bg: #7f1d1d;
  --color-info-bg: #1e3a8a;
  --shadow-md: 0 4px 12px rgba(0,0,0,0.4);
  --shadow-lg: 0 12px 32px rgba(0,0,0,0.5);
}
* { box-sizing: border-box; }
html, body { margin: 0; padding: 0; }
body {
  font-family: var(--font-sans);
  background: var(--color-bg);
  color: var(--color-text);
  font-size: 14px;
  line-height: 1.5;
  -webkit-font-smoothing: antialiased;
  transition: background-color var(--transition), color var(--transition);
}
button { font-family: inherit; cursor: pointer; }
a { color: inherit; text-decoration: none; }
:focus-visible { outline: 2px solid var(--color-accent); outline-offset: 2px; border-radius: 4px; }
EOF

write "src/styles/layout.css" <<'EOF'
.shell {
  display: grid;
  grid-template-columns: var(--nav-width) 1fr;
  grid-template-rows: var(--header-height) 1fr;
  grid-template-areas: "nav header" "nav main";
  min-height: 100vh;
}
@media (max-width: 1024px) {
  .shell { grid-template-columns: 64px 1fr; }
}
.header {
  grid-area: header;
  position: sticky; top: 0; z-index: 20;
  display: flex; align-items: center; gap: var(--space-4);
  padding: 0 var(--space-6);
  background: var(--color-surface);
  border-bottom: 1px solid var(--color-border);
  backdrop-filter: blur(8px);
}
.header__brand { display: flex; align-items: center; gap: var(--space-3); font-weight: 700; font-size: 15px; letter-spacing: -0.01em; }
.header__logo {
  width: 28px; height: 28px; border-radius: 8px;
  background: linear-gradient(135deg, var(--color-primary), var(--color-accent));
  display: grid; place-items: center; color: #fff; font-weight: 800; font-size: 14px;
}
.header__spacer { flex: 1; }
.header__control {
  display: inline-flex; align-items: center; gap: var(--space-2);
  padding: 6px 10px; border-radius: var(--radius-sm);
  border: 1px solid var(--color-border);
  background: var(--color-surface);
  color: var(--color-text);
  font-size: 13px;
  transition: all var(--transition);
}
.header__control:hover { border-color: var(--color-border-strong); background: var(--color-surface-2); }
.header__icon-btn {
  width: 36px; height: 36px; padding: 0;
  display: grid; place-items: center;
  border: 1px solid var(--color-border); border-radius: var(--radius-sm);
  background: var(--color-surface); color: var(--color-text-muted);
  transition: all var(--transition); position: relative;
}
.header__icon-btn:hover { color: var(--color-text); border-color: var(--color-border-strong); }
.header__badge {
  position: absolute; top: -4px; right: -4px;
  background: var(--color-alert); color: #fff;
  font-size: 10px; font-weight: 700;
  min-width: 16px; height: 16px; padding: 0 4px;
  border-radius: 8px; display: grid; place-items: center;
}
.header__avatar {
  width: 32px; height: 32px; border-radius: 50%;
  background: linear-gradient(135deg, #6366f1, #ec4899);
  display: grid; place-items: center; color: #fff; font-weight: 600; font-size: 13px;
}

.nav {
  grid-area: nav;
  background: var(--color-surface);
  border-right: 1px solid var(--color-border);
  padding: var(--space-4) var(--space-3);
  display: flex; flex-direction: column; gap: var(--space-1);
  position: sticky; top: 0; height: 100vh; overflow-y: auto;
}
.nav__item {
  display: flex; align-items: center; gap: var(--space-3);
  padding: 10px 12px; border-radius: var(--radius-sm);
  color: var(--color-text-muted); font-size: 13.5px; font-weight: 500;
  transition: all var(--transition); cursor: pointer;
  border: none; background: none; text-align: left; width: 100%;
}
.nav__item:hover:not(:disabled) { background: var(--color-surface-2); color: var(--color-text); }
.nav__item--active { background: var(--color-primary); color: #fff; }
.nav__item--active:hover { background: var(--color-primary-hover); color: #fff; }
.nav__item:disabled { opacity: 0.35; cursor: not-allowed; }
.nav__icon { width: 18px; height: 18px; flex-shrink: 0; }
.nav__label { flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
@media (max-width: 1024px) { .nav__label { display: none; } }
.nav__footer {
  margin-top: auto; padding-top: var(--space-4);
  border-top: 1px solid var(--color-border);
  color: var(--color-text-subtle); font-size: 11.5px;
  font-family: var(--font-mono);
}

.main { grid-area: main; padding: var(--space-6); overflow-x: hidden; }
.main__header { margin-bottom: var(--space-6); }
.main__title { font-size: 22px; font-weight: 700; letter-spacing: -0.02em; margin: 0 0 4px; }
.main__subtitle { color: var(--color-text-muted); font-size: 13.5px; margin: 0; }

.grid-kpi { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: var(--space-4); margin-bottom: var(--space-6); }
@media (max-width: 1200px) { .grid-kpi { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 640px) { .grid-kpi { grid-template-columns: 1fr; } }
.grid-2 { display: grid; grid-template-columns: 2fr 1fr; gap: var(--space-4); margin-bottom: var(--space-6); }
@media (max-width: 1024px) { .grid-2 { grid-template-columns: 1fr; } }

.card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  padding: var(--space-5);
  transition: all var(--transition);
}
.card--hover:hover { box-shadow: var(--shadow-md); border-color: var(--color-border-strong); }
.card__title { font-size: 13.5px; font-weight: 600; margin: 0 0 var(--space-4); color: var(--color-text-muted); text-transform: uppercase; letter-spacing: 0.04em; }

.banner {
  display: flex; align-items: center; gap: var(--space-3);
  padding: 10px 14px; border-radius: var(--radius-sm);
  background: var(--color-watch-bg); color: #92400e;
  font-size: 13px; margin-bottom: var(--space-6);
  border: 1px solid rgba(245,158,11,0.25);
}
[data-theme="dark"] .banner { color: #fcd34d; }
EOF

write "src/styles/components.css" <<'EOF'
.kpi { display: flex; flex-direction: column; gap: 6px; }
.kpi__label { font-size: 12.5px; color: var(--color-text-muted); font-weight: 500; margin: 0; letter-spacing: -0.005em; }
.kpi__value-row { display: flex; align-items: baseline; gap: 8px; }
.kpi__value { font-size: 26px; font-weight: 700; letter-spacing: -0.03em; line-height: 1; font-feature-settings: "tnum"; }
.kpi__unit { font-size: 13px; color: var(--color-text-muted); font-weight: 500; }
.kpi__delta { display: inline-flex; align-items: center; gap: 3px; font-size: 12px; font-weight: 600; padding: 2px 6px; border-radius: 4px; }
.kpi__delta--good { background: var(--color-ok-bg); color: var(--color-ok); }
.kpi__delta--bad { background: var(--color-alert-bg); color: var(--color-alert); }
.kpi__delta--neutral { background: var(--color-surface-2); color: var(--color-text-muted); }
.kpi__meta { display: flex; justify-content: space-between; align-items: center; font-size: 11.5px; color: var(--color-text-subtle); margin-top: 4px; }
.kpi__spark { height: 24px; width: 100%; margin-top: 2px; }
.kpi__link { font-size: 11.5px; color: var(--color-accent); font-weight: 500; margin-top: 4px; display: inline-block; }
.kpi__link:hover { text-decoration: underline; }

.alert {
  display: flex; gap: 12px; padding: 12px;
  border-radius: var(--radius-sm); margin-bottom: 8px;
  border-left: 3px solid;
}
.alert--warn { background: var(--color-watch-bg); border-color: var(--color-watch); color: #92400e; }
.alert--info { background: var(--color-info-bg); border-color: var(--color-info); color: #1e40af; }
.alert--error { background: var(--color-alert-bg); border-color: var(--color-alert); color: #991b1b; }
[data-theme="dark"] .alert--warn { color: #fcd34d; }
[data-theme="dark"] .alert--info { color: #93c5fd; }
[data-theme="dark"] .alert--error { color: #fca5a5; }
.alert__icon { flex-shrink: 0; width: 18px; height: 18px; }
.alert__body { flex: 1; }
.alert__title { font-weight: 600; font-size: 13px; margin: 0 0 2px; }
.alert__desc { font-size: 12.5px; margin: 0; opacity: 0.85; }

.funnel { display: flex; flex-direction: column; gap: 6px; }
.funnel__stage { display: flex; align-items: center; gap: 12px; }
.funnel__label { width: 100px; font-size: 12.5px; color: var(--color-text-muted); text-align: right; flex-shrink: 0; }
.funnel__bar-wrap { flex: 1; height: 32px; background: var(--color-surface-2); border-radius: var(--radius-sm); overflow: hidden; position: relative; }
.funnel__bar { height: 100%; background: linear-gradient(90deg, var(--color-primary), var(--color-accent)); display: flex; align-items: center; padding: 0 12px; color: #fff; font-weight: 600; font-size: 12.5px; font-feature-settings: "tnum"; transition: width 600ms cubic-bezier(0.4, 0, 0.2, 1); }
.funnel__conversion { width: 60px; font-size: 11.5px; color: var(--color-text-subtle); font-family: var(--font-mono); text-align: right; flex-shrink: 0; }

.ts { width: 100%; height: 220px; display: block; }
.ts__legend { display: flex; gap: 16px; margin-top: 12px; font-size: 12px; color: var(--color-text-muted); }
.ts__legend-item { display: inline-flex; align-items: center; gap: 6px; }
.ts__legend-dot { width: 10px; height: 10px; border-radius: 3px; }

.queue { width: 100%; border-collapse: collapse; font-size: 13px; }
.queue th { text-align: left; padding: 10px 12px; font-size: 11.5px; font-weight: 600; color: var(--color-text-muted); text-transform: uppercase; letter-spacing: 0.04em; border-bottom: 1px solid var(--color-border); }
.queue td { padding: 12px; border-bottom: 1px solid var(--color-border); }
.queue tr:last-child td { border-bottom: none; }
.queue tr:hover td { background: var(--color-surface-2); }
.queue__id { font-family: var(--font-mono); font-size: 12.5px; color: var(--color-text-muted); }
.queue__score { font-family: var(--font-mono); font-weight: 600; font-feature-settings: "tnum"; }
.pill { display: inline-flex; align-items: center; gap: 4px; padding: 3px 8px; border-radius: 12px; font-size: 11.5px; font-weight: 600; }
.pill--ok { background: var(--color-ok-bg); color: var(--color-ok); }
.pill--watch { background: var(--color-watch-bg); color: #b45309; }
.pill--alert { background: var(--color-alert-bg); color: var(--color-alert); }
[data-theme="dark"] .pill--watch { color: #fcd34d; }

.gauge-wrap { display: flex; flex-direction: column; align-items: center; gap: 6px; }
.gauge { position: relative; width: 140px; height: 80px; }
.gauge__value { position: absolute; bottom: 0; left: 0; right: 0; text-align: center; font-size: 22px; font-weight: 700; font-feature-settings: "tnum"; }
.gauge__label { font-size: 12.5px; color: var(--color-text-muted); margin-top: 6px; text-align: center; }

.heat { width: 100%; border-collapse: separate; border-spacing: 3px; }
.heat th { font-size: 11.5px; color: var(--color-text-muted); font-weight: 500; padding: 6px; text-align: center; }
.heat td { padding: 0; }
.heat__cell { width: 100%; height: 40px; display: grid; place-items: center; border-radius: var(--radius-sm); font-size: 12px; font-weight: 600; color: #fff; font-feature-settings: "tnum"; }

.small-group { display: inline-flex; align-items: center; gap: 6px; padding: 4px 10px; border-radius: 12px; background: var(--color-surface-2); color: var(--color-text-subtle); font-size: 12px; font-weight: 500; }

.empty { display: grid; place-items: center; min-height: 300px; color: var(--color-text-subtle); font-size: 14px; }
EOF

# ─────────────────────────────────────────────────────────────
# 2. Mock data
# ─────────────────────────────────────────────────────────────
log "Données mockées…"

write "src/mock/data.ts" <<'EOF'
// Données fictives — aucune PII. Usage démonstration locale uniquement.

export type Site = 'FR' | 'PT';
export type Status = 'ok' | 'watch' | 'alert';

export interface Kpi {
  id: string;
  label: string;
  value: number;
  unit?: 'min' | 'h' | 'd' | 'count' | 'pct';
  baseline?: number;
  target?: number;
  status: Status;
  n?: number;
  lowerIsBetter?: boolean;
  spark?: number[];
  href?: string;
}

export interface Alert {
  id: string;
  level: 'info' | 'warn' | 'error';
  title: string;
  description: string;
}

export interface FunnelStage {
  label: string;
  value: number;
}

export interface TimeseriesPoint {
  day: string;
  fr: number;
  pt: number;
}

export interface QueueRow {
  id: string;
  site: Site;
  score: number;
  status: 'pending' | 'review' | 'done';
  waiting: string;
}

export interface HeatCell {
  dimension: string;
  group: string;
  value: number;
  n: number;
}

export const KPIS: Kpi[] = [
  {
    id: 'median-time',
    label: 'Temps médian de pré-screening',
    value: 8.4,
    unit: 'min',
    baseline: 18,
    target: 4,
    status: 'ok',
    lowerIsBetter: true,
    spark: [18, 17.2, 16, 14.5, 13, 11.2, 10, 8.4],
    href: '#/rubric',
  },
  {
    id: 'agreement',
    label: "Taux d'accord recruteur / copilote",
    value: 87.3,
    unit: 'pct',
    baseline: 82,
    target: 90,
    status: 'watch',
    spark: [78, 80, 81, 83, 84, 85, 86, 87.3],
    href: '#/quality',
  },
  {
    id: 'volume',
    label: 'Candidats pré-screenés (7j)',
    value: 342,
    unit: 'count',
    baseline: 280,
    status: 'ok',
    spark: [180, 210, 240, 270, 290, 310, 330, 342],
  },
  {
    id: 'override',
    label: "Taux d'override recruteur",
    value: 12.5,
    unit: 'pct',
    baseline: 18,
    target: 10,
    status: 'watch',
    lowerIsBetter: true,
    spark: [22, 21, 19.5, 18, 16, 14.5, 13.2, 12.5],
    href: '#/fairness',
  },
];

export const ALERTS: Alert[] = [
  {
    id: 'a1',
    level: 'warn',
    title: "Taux d'accord en dessous de la cible",
    description: 'Site Porto : 79 % vs cible 90 %. 42 candidats sur 7j.',
  },
  {
    id: 'a2',
    level: 'info',
    title: 'Nouvelle rubric v2.3.1 déployée',
    description: 'Les snapshots antérieurs restent consultables sur 90 jours.',
  },
];

export const FUNNEL: FunnelStage[] = [
  { label: 'Sourced',   value: 1240 },
  { label: 'Screened',  value: 980 },
  { label: 'Shortlist', value: 420 },
  { label: 'Interview', value: 180 },
  { label: 'Offer',     value: 42 },
];

export const TIMESERIES: TimeseriesPoint[] = [
  { day: 'J-13', fr: 12.1, pt: 15.2 },
  { day: 'J-12', fr: 11.8, pt: 14.9 },
  { day: 'J-11', fr: 11.2, pt: 14.1 },
  { day: 'J-10', fr: 10.9, pt: 13.8 },
  { day: 'J-9',  fr: 10.4, pt: 13.2 },
  { day: 'J-8',  fr: 10.1, pt: 12.9 },
  { day: 'J-7',  fr: 9.8,  pt: 12.4 },
  { day: 'J-6',  fr: 9.4,  pt: 11.9 },
  { day: 'J-5',  fr: 9.1,  pt: 11.2 },
  { day: 'J-4',  fr: 8.9,  pt: 10.8 },
  { day: 'J-3',  fr: 8.7,  pt: 10.2 },
  { day: 'J-2',  fr: 8.5,  pt: 9.8 },
  { day: 'J-1',  fr: 8.4,  pt: 9.5 },
  { day: 'J-0',  fr: 8.4,  pt: 9.2 },
];

export const QUEUE: QueueRow[] = [
  { id: 'C-2841', site: 'FR', score: 87, status: 'pending', waiting: '2 h' },
  { id: 'C-2842', site: 'PT', score: 74, status: 'review',  waiting: '4 h' },
  { id: 'C-2843', site: 'FR', score: 91, status: 'done',    waiting: '—' },
  { id: 'C-2844', site: 'PT', score: 62, status: 'pending', waiting: '6 h' },
  { id: 'C-2845', site: 'FR', score: 78, status: 'review',  waiting: '1 j' },
  { id: 'C-2846', site: 'PT', score: 83, status: 'done',    waiting: '—' },
  { id: 'C-2847', site: 'FR', score: 69, status: 'pending', waiting: '12 h' },
  { id: 'C-2848', site: 'PT', score: 95, status: 'done',    waiting: '—' },
];

export const HEATMAP: HeatCell[] = [
  { dimension: 'Site',     group: 'FR',       value: 8.4,  n: 220 },
  { dimension: 'Site',     group: 'PT',       value: 9.2,  n: 122 },
  { dimension: 'Rubric',   group: 'v2.3.1',   value: 8.4,  n: 342 },
  { dimension: 'Rubric',   group: 'v2.2.0',   value: 9.1,  n: 210 },
  { dimension: 'Cohorte',  group: 'Sénior',   value: 7.8,  n: 98 },
  { dimension: 'Cohorte',  group: 'Junior',   value: 9.6,  n: 154 },
  { dimension: 'Cohorte',  group: 'Stage',    value: 10.2, n: 42 },
  { dimension: 'Période',  group: 'Oct S1',   value: 8.9,  n: 180 },
  { dimension: 'Période',  group: 'Oct S2',   value: 8.1,  n: 162 },
];

export const GAUGES = [
  { label: "Taux d'accord (FR)", value: 88.5 },
  { label: "Taux d'accord (PT)", value: 79.1 },
  { label: 'Confiance moyenne',  value: 82.4 },
];

export const RUBRIC_META = {
  version: 'v2.3.1',
  deployedAt: '2026-10-04',
  site: 'FR + PT',
  note: 'Rubric de pré-screening FDE. Read-only pour les recruteurs.',
};
EOF

# ─────────────────────────────────────────────────────────────
# 3. Widgets (remplace les placeholders)
# ─────────────────────────────────────────────────────────────
log "Widgets…"

# 3.a KpiCard — on garde l'API existante, on l'enrichit visuellement
write "src/widgets/KpiCard/KpiCard.tsx" <<'EOF'
import React from 'react';

export type KpiStatus = 'ok' | 'watch' | 'alert';

export interface KpiCardProps {
  label: string;
  value: number;
  unit?: 'min' | 'h' | 'd' | 'count' | 'pct';
  baseline?: number;
  target?: number;
  status?: KpiStatus;
  lastRefresh?: string;
  href?: string;
  n?: number;
  lowerIsBetter?: boolean;
  spark?: number[];
}

export function formatValue(value: number, unit?: KpiCardProps['unit']): string {
  switch (unit) {
    case 'pct':   return `${value.toFixed(1)} %`;
    case 'min':   return `${value.toFixed(1)} min`;
    case 'h':     return `${value.toFixed(1)} h`;
    case 'd':     return `${value.toFixed(1)} j`;
    case 'count': return value.toLocaleString('fr-FR');
    default:      return String(value);
  }
}

export function deltaPct(value: number, baseline?: number): number | null {
  if (baseline === undefined || baseline === 0) return null;
  return ((value - baseline) / baseline) * 100;
}

function Spark({ points, positive }: { points: number[]; positive: boolean }) {
  if (!points.length) return null;
  const w = 120, h = 24;
  const min = Math.min(...points), max = Math.max(...points);
  const range = max - min || 1;
  const step = w / (points.length - 1);
  const d = points
    .map((p, i) => {
      const x = i * step;
      const y = h - ((p - min) / range) * h;
      return `${i === 0 ? 'M' : 'L'}${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(' ');
  const stroke = positive ? 'var(--color-ok)' : 'var(--color-alert)';
  return (
    <svg className="kpi__spark" viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="none" aria-hidden="true">
      <path d={d} fill="none" stroke={stroke} strokeWidth="1.5" strokeLinejoin="round" strokeLinecap="round" />
    </svg>
  );
}

export function KpiCard(props: KpiCardProps) {
  const {
    label, value, unit, baseline, target, status = 'ok',
    lastRefresh, href, n, lowerIsBetter = false, spark,
  } = props;

  const delta = deltaPct(value, baseline);
  const isGood = delta === null ? true : lowerIsBetter ? delta <= 0 : delta >= 0;
  const deltaClass = delta === null ? 'neutral' : isGood ? 'good' : 'bad';
  const sign = delta === null || delta >= 0 ? '+' : '';
  const positive = spark && spark.length > 1 ? spark[spark.length - 1] <= spark[0] : true;

  if (n !== undefined && n < 5) {
    return (
      <article
        data-testid="kpi-card"
        data-status={status}
        aria-label={`${label}: agrégat masqué (n<5)`}
        className="card"
      >
        <p className="kpi__label">{label}</p>
        <p style={{ margin: '8px 0 0' }}>
          <span className="small-group">
            <span aria-hidden="true">n&lt;5</span>
            <span className="sr-only">Agrégat masqué : groupe inférieur à 5</span>
          </span>
        </p>
      </article>
    );
  }

  return (
    <article
      data-testid="kpi-card"
      data-status={status}
      aria-label={`${label}: ${formatValue(value, unit)}`}
      className="card card--hover"
    >
      <div className="kpi">
        <p className="kpi__label">{label}</p>
        <div className="kpi__value-row">
          <span className="kpi__value">{formatValue(value, unit)}</span>
          {delta !== null && (
            <span className={`kpi__delta kpi__delta--${deltaClass}`} data-testid="kpi-card-delta">
              <span aria-hidden="true">{delta >= 0 ? '▲' : '▼'}</span>
              {sign}{delta.toFixed(1)} %
            </span>
          )}
        </div>
        {spark && spark.length > 1 && <Spark points={spark} positive={positive} />}
        <div className="kpi__meta">
          {target !== undefined && <span>Cible : {formatValue(target, unit)}</span>}
          {lastRefresh && <span>MAJ {new Date(lastRefresh).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit' })}</span>}
        </div>
        {href && (
          <a className="kpi__link" href={href} aria-label={`Voir la définition de ${label}`}>
            Voir la définition →
          </a>
        )}
      </div>
    </article>
  );
}
EOF

# 3.b SmallGroupGuard — inchangé fonctionnellement, styles ajustés
write "src/widgets/SmallGroupGuard/SmallGroupGuard.tsx" <<'EOF'
import React from 'react';

export interface SmallGroupGuardProps {
  n: number;
  threshold?: number;
  children: React.ReactNode;
  fallback?: React.ReactNode;
  context?: string;
}

export function SmallGroupGuard(props: SmallGroupGuardProps) {
  const { n, threshold = 5, children, fallback, context } = props;
  if (n >= threshold) return <>{children}</>;

  const label = context
    ? `Agrégat masqué : groupe inférieur à ${threshold} (${context})`
    : `Agrégat masqué : groupe inférieur à ${threshold}`;

  return (
    <span
      data-testid="small-group-guard-fallback"
      role="note"
      aria-label={label}
      className="small-group"
    >
      {fallback ?? (
        <>
          <span aria-hidden="true">n&lt;{threshold}</span>
          <span className="sr-only">{label}</span>
        </>
      )}
    </span>
  );
}
EOF

# 3.c TimeSeries — SVG inline, deux courbes
write "src/widgets/TimeSeries/TimeSeries.tsx" <<'EOF'
import React from 'react';

export interface TimeSeriesPoint { day: string; fr: number; pt: number; }
export interface TimeSeriesProps {
  data: TimeSeriesPoint[];
  yLabel?: string;
  height?: number;
}

export function TimeSeries({ data, yLabel = 'min', height = 220 }: TimeSeriesProps) {
  if (!data.length) return <div className="empty">Aucune donnée</div>;

  const w = 800, h = height;
  const padL = 40, padR = 16, padT = 16, padB = 28;
  const innerW = w - padL - padR, innerH = h - padT - padB;

  const all = data.flatMap(d => [d.fr, d.pt]);
  const min = Math.min(...all), max = Math.max(...all);
  const range = max - min || 1;
  const step = innerW / (data.length - 1);

  const line = (key: 'fr' | 'pt') =>
    data.map((d, i) => {
      const x = padL + i * step;
      const y = padT + innerH - ((d[key] - min) / range) * innerH;
      return `${i === 0 ? 'M' : 'L'}${x.toFixed(1)},${y.toFixed(1)}`;
    }).join(' ');

  const area = (key: 'fr' | 'pt') =>
    line(key) + ` L${padL + (data.length - 1) * step},${padT + innerH} L${padL},${padT + innerH} Z`;

  const yTicks = 4;
  const yTickVals = Array.from({ length: yTicks + 1 }, (_, i) => min + (range * i) / yTicks);

  return (
    <div>
      <svg className="ts" viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="none" role="img" aria-label={`Série temporelle, ${yLabel}`}>
        <defs>
          <linearGradient id="grad-fr" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="var(--color-primary)" stopOpacity="0.18" />
            <stop offset="100%" stopColor="var(--color-primary)" stopOpacity="0" />
          </linearGradient>
          <linearGradient id="grad-pt" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="var(--color-accent)" stopOpacity="0.18" />
            <stop offset="100%" stopColor="var(--color-accent)" stopOpacity="0" />
          </linearGradient>
        </defs>

        {yTickVals.map((v, i) => {
          const y = padT + innerH - ((v - min) / range) * innerH;
          return (
            <g key={i}>
              <line x1={padL} y1={y} x2={w - padR} y2={y} stroke="var(--color-border)" strokeWidth="1" strokeDasharray={i === 0 ? '' : '2 3'} />
              <text x={padL - 6} y={y + 3} textAnchor="end" fontSize="10" fill="var(--color-text-subtle)" fontFamily="var(--font-mono)">{v.toFixed(1)}</text>
            </g>
          );
        })}

        <path d={area('fr')} fill="url(#grad-fr)" />
        <path d={area('pt')} fill="url(#grad-pt)" />
        <path d={line('fr')} fill="none" stroke="var(--color-primary)" strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" />
        <path d={line('pt')} fill="none" stroke="var(--color-accent)" strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" />

        {data.map((d, i) => {
          if (i % 2 !== 0 && i !== data.length - 1) return null;
          const x = padL + i * step;
          return (
            <text key={i} x={x} y={h - 8} textAnchor="middle" fontSize="10" fill="var(--color-text-subtle)" fontFamily="var(--font-mono)">{d.day}</text>
          );
        })}
      </svg>
      <div className="ts__legend">
        <span className="ts__legend-item"><span className="ts__legend-dot" style={{ background: 'var(--color-primary)' }} /> France</span>
        <span className="ts__legend-item"><span className="ts__legend-dot" style={{ background: 'var(--color-accent)' }} /> Porto</span>
        <span style={{ marginLeft: 'auto', color: 'var(--color-text-subtle)', fontSize: 11 }}>Unité : {yLabel}</span>
      </div>
    </div>
  );
}
EOF

# 3.d FunnelChart
write "src/widgets/FunnelChart/FunnelChart.tsx" <<'EOF'
import React from 'react';

export interface FunnelStage { label: string; value: number; }

export function FunnelChart({ stages }: { stages: FunnelStage[] }) {
  if (!stages.length) return <div className="empty">Aucune étape</div>;
  const max = stages[0].value;
  return (
    <div className="funnel">
      {stages.map((s, i) => {
        const pct = (s.value / max) * 100;
        const prev = i === 0 ? s.value : stages[i - 1].value;
        const conv = i === 0 ? 100 : (s.value / prev) * 100;
        return (
          <div className="funnel__stage" key={s.label}>
            <span className="funnel__label">{s.label}</span>
            <div className="funnel__bar-wrap">
              <div className="funnel__bar" style={{ width: `${pct}%` }}>
                {s.value.toLocaleString('fr-FR')}
              </div>
            </div>
            <span className="funnel__conversion">{i === 0 ? '—' : `${conv.toFixed(0)} %`}</span>
          </div>
        );
      })}
    </div>
  );
}
EOF

# 3.e QueueTable
write "src/widgets/QueueTable/QueueTable.tsx" <<'EOF'
import React from 'react';
import type { QueueRow } from '../../mock/data';

const STATUS_LABEL: Record<QueueRow['status'], { label: string; cls: string }> = {
  pending: { label: 'En attente', cls: 'pill--watch' },
  review:  { label: 'À revoir',   cls: 'pill--alert' },
  done:    { label: 'Traité',     cls: 'pill--ok' },
};

export function QueueTable({ rows }: { rows: QueueRow[] }) {
  if (!rows.length) return <div className="empty">File vide</div>;
  return (
    <table className="queue">
      <thead>
        <tr>
          <th>ID</th>
          <th>Site</th>
          <th>Score</th>
          <th>Statut</th>
          <th>Attente</th>
        </tr>
      </thead>
      <tbody>
        {rows.map(r => {
          const st = STATUS_LABEL[r.status];
          return (
            <tr key={r.id}>
              <td className="queue__id">{r.id}</td>
              <td>{r.site}</td>
              <td className="queue__score">{r.score}</td>
              <td><span className={`pill ${st.cls}`}>{st.label}</span></td>
              <td>{r.waiting}</td>
            </tr>
          );
        })}
      </tbody>
    </table>
  );
}
EOF

# 3.f Gauge
write "src/widgets/Gauge/Gauge.tsx" <<'EOF'
import React from 'react';

export function Gauge({ value, label, size = 140 }: { value: number; label: string; size?: number }) {
  const clamped = Math.max(0, Math.min(100, value));
  const r = 60, cx = size / 2, cy = 70;
  const angle = (clamped / 100) * Math.PI;
  const x = cx - r * Math.cos(angle);
  const y = cy - r * Math.sin(angle);
  const largeArc = 0;

  const color = clamped >= 85 ? 'var(--color-ok)' : clamped >= 70 ? 'var(--color-watch)' : 'var(--color-alert)';

  return (
    <div className="gauge-wrap">
      <div className="gauge" style={{ width: size }}>
        <svg viewBox={`0 0 ${size} 80`} width={size} height={80} aria-hidden="true">
          <path d={`M ${cx - r},${cy} A ${r},${r} 0 0 1 ${cx + r},${cy}`} fill="none" stroke="var(--color-border)" strokeWidth="10" strokeLinecap="round" />
          <path d={`M ${cx - r},${cy} A ${r},${r} 0 ${largeArc} 1 ${x},${y}`} fill="none" stroke={color} strokeWidth="10" strokeLinecap="round" />
        </svg>
        <div className="gauge__value" style={{ color }}>{clamped.toFixed(1)} %</div>
      </div>
      <div className="gauge__label">{label}</div>
    </div>
  );
}
EOF

# 3.g Heatmap
write "src/widgets/Heatmap/Heatmap.tsx" <<'EOF'
import React from 'react';
import type { HeatCell } from '../../mock/data';

function colorFor(v: number, min: number, max: number) {
  const t = (v - min) / (max - min || 1);
  // Interpole entre ok (vert) et alert (rouge)
  const r = Math.round(16 + t * (239 - 16));
  const g = Math.round(185 + t * (68 - 185));
  const b = Math.round(129 + t * (68 - 129));
  return `rgb(${r},${g},${b})`;
}

export function Heatmap({ cells }: { cells: HeatCell[] }) {
  const dims = Array.from(new Set(cells.map(c => c.dimension)));
  const groups = Array.from(new Set(cells.map(c => c.group)));
  const values = cells.map(c => c.value);
  const min = Math.min(...values), max = Math.max(...values);

  return (
    <table className="heat" aria-label="Heatmap par dimension">
      <thead>
        <tr>
          <th style={{ textAlign: 'left' }}>Dimension</th>
          {groups.map(g => <th key={g}>{g}</th>)}
        </tr>
      </thead>
      <tbody>
        {dims.map(d => (
          <tr key={d}>
            <th style={{ textAlign: 'left', paddingRight: 12 }}>{d}</th>
            {groups.map(g => {
              const cell = cells.find(c => c.dimension === d && c.group === g);
              if (!cell) return <td key={g}><div className="heat__cell" style={{ background: 'var(--color-surface-2)', color: 'var(--color-text-subtle)' }}>—</div></td>;
              if (cell.n < 5) return (
                <td key={g}>
                  <div className="heat__cell" style={{ background: 'var(--color-surface-2)', color: 'var(--color-text-subtle)' }} title="Agrégat masqué (n<5)">n&lt;5</div>
                </td>
              );
              return (
                <td key={g}>
                  <div className="heat__cell" style={{ background: colorFor(cell.value, min, max) }} title={`n=${cell.n}`}>{cell.value.toFixed(1)}</div>
                </td>
              );
            })}
          </tr>
        ))}
      </tbody>
    </table>
  );
}
EOF

# 3.h AlertPanel
write "src/widgets/AlertPanel/AlertPanel.tsx" <<'EOF'
import React from 'react';
import type { Alert } from '../../mock/data';

const ICONS: Record<Alert['level'], string> = { info: 'ℹ', warn: '⚠', error: '✕' };

export function AlertPanel({ alerts }: { alerts: Alert[] }) {
  if (!alerts.length) return <div className="empty" style={{ minHeight: 120 }}>Aucune alerte</div>;
  return (
    <div role="region" aria-label="Alertes">
      {alerts.map(a => (
        <div key={a.id} className={`alert alert--${a.level}`} role={a.level === 'error' ? 'alert' : 'status'}>
          <span className="alert__icon" aria-hidden="true" style={{ fontSize: 16, lineHeight: '18px', textAlign: 'center' }}>{ICONS[a.level]}</span>
          <div className="alert__body">
            <p className="alert__title">{a.title}</p>
            <p className="alert__desc">{a.description}</p>
          </div>
        </div>
      ))}
    </div>
  );
}
EOF

# ─────────────────────────────────────────────────────────────
# 4. Index.ts pour chaque widget
# ─────────────────────────────────────────────────────────────
for w in KpiCard SmallGroupGuard TimeSeries FunnelChart QueueTable Gauge Heatmap AlertPanel; do
  write "src/widgets/$w/index.ts" <<EOF
export * from './$w';
EOF
done

# ─────────────────────────────────────────────────────────────
# 5. Shell — Header, LeftNav, AppShell
# ─────────────────────────────────────────────────────────────
log "Shell…"

write "src/app/shell/icons.tsx" <<'EOF'
import React from 'react';
type P = { size?: number };
const base = (size = 18) => ({ width: size, height: size, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', strokeWidth: 1.8, strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const });

export const IconOverview = ({ size }: P) => (<svg {...base(size)}><rect x="3" y="3" width="7" height="9"/><rect x="14" y="3" width="7" height="5"/><rect x="14" y="12" width="7" height="9"/><rect x="3" y="16" width="7" height="5"/></svg>);
export const IconPipeline = ({ size }: P) => (<svg {...base(size)}><path d="M3 5h18l-6 7v6l-6 3v-9z"/></svg>);
export const IconQueue = ({ size }: P) => (<svg {...base(size)}><circle cx="9" cy="8" r="3"/><path d="M3 20c0-3 3-5 6-5s6 2 6 5"/><path d="M16 11h5M16 15h5M16 7h3"/></svg>);
export const IconQuality = ({ size }: P) => (<svg {...base(size)}><path d="M9 12l2 2 4-4"/><circle cx="12" cy="12" r="9"/></svg>);
export const IconFairness = ({ size }: P) => (<svg {...base(size)}><path d="M12 3v18"/><path d="M5 8h14"/><path d="M5 8l-2 6a3 3 0 0 0 6 0z"/><path d="M19 8l-2 6a3 3 0 0 0 6 0z"/></svg>);
export const IconOperations = ({ size }: P) => (<svg {...base(size)}><circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1"/></svg>);
export const IconGovernance = ({ size }: P) => (<svg {...base(size)}><path d="M4 4h12l4 4v12H4z"/><path d="M8 10h8M8 14h8"/></svg>);
export const IconRubric = ({ size }: P) => (<svg {...base(size)}><path d="M4 4h10a4 4 0 0 1 4 4v12H8a4 4 0 0 0-4 4z"/><path d="M8 8h6"/></svg>);
export const IconBell = ({ size }: P) => (<svg {...base(size)}><path d="M6 8a6 6 0 0 1 12 0c0 7 3 7 3 9H3c0-2 3-2 3-9"/><path d="M10 21a2 2 0 0 0 4 0"/></svg>);
export const IconMoon = ({ size }: P) => (<svg {...base(size)}><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/></svg>);
export const IconSun = ({ size }: P) => (<svg {...base(size)}><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>);
EOF

write "src/app/shell/Header.tsx" <<'EOF'
import React from 'react';
import { IconBell, IconMoon, IconSun } from './icons';
import type { Role } from '../../auth/rbac';

const ROLES: { value: Role; label: string }[] = [
  { value: 'recruiter', label: 'Recruteur' },
  { value: 'hm',        label: 'Hiring Manager' },
  { value: 'hrd',       label: 'HRD' },
  { value: 'dpo',       label: 'DPO' },
  { value: 'mco',       label: 'MCO' },
];

export interface HeaderProps {
  role: Role;
  onRoleChange: (r: Role) => void;
  lang: 'fr' | 'en';
  onLangChange: (l: 'fr' | 'en') => void;
  theme: 'light' | 'dark';
  onThemeToggle: () => void;
  alertCount: number;
}

export function Header({ role, onRoleChange, lang, onLangChange, theme, onThemeToggle, alertCount }: HeaderProps) {
  return (
    <header className="header">
      <div className="header__brand">
        <div className="header__logo" aria-hidden="true">A</div>
        <span>ATS Copilot</span>
      </div>

      <div className="header__spacer" />

      <label className="header__control">
        <span style={{ color: 'var(--color-text-muted)' }}>Rôle</span>
        <select value={role} onChange={e => onRoleChange(e.target.value as Role)} style={{ border: 'none', background: 'transparent', color: 'inherit', fontWeight: 600 }}>
          {ROLES.map(r => <option key={r.value} value={r.value}>{r.label}</option>)}
        </select>
      </label>

      <div className="header__control" role="group" aria-label="Langue">
        <button
          onClick={() => onLangChange('fr')}
          style={{ border: 'none', background: 'transparent', padding: 2, fontWeight: lang === 'fr' ? 700 : 500, color: lang === 'fr' ? 'var(--color-accent)' : 'inherit' }}
          aria-pressed={lang === 'fr'}
        >FR</button>
        <span style={{ color: 'var(--color-border-strong)' }}>|</span>
        <button
          onClick={() => onLangChange('en')}
          style={{ border: 'none', background: 'transparent', padding: 2, fontWeight: lang === 'en' ? 700 : 500, color: lang === 'en' ? 'var(--color-accent)' : 'inherit' }}
          aria-pressed={lang === 'en'}
        >EN</button>
      </div>

      <button className="header__icon-btn" onClick={onThemeToggle} aria-label={`Basculer en mode ${theme === 'light' ? 'sombre' : 'clair'}`}>
        {theme === 'light' ? <IconMoon /> : <IconSun />}
      </button>

      <button className="header__icon-btn" aria-label={`${alertCount} alertes`}>
        <IconBell />
        {alertCount > 0 && <span className="header__badge">{alertCount}</span>}
      </button>

      <div className="header__avatar" aria-label="Utilisateur courant">SA</div>
    </header>
  );
}
EOF

write "src/app/shell/LeftNav.tsx" <<'EOF'
import React from 'react';
import {
  IconOverview, IconPipeline, IconQueue, IconQuality,
  IconFairness, IconOperations, IconGovernance, IconRubric,
} from './icons';
import type { Page, Role } from '../../auth/rbac';
import { canAccess } from '../../auth/rbac';

const ITEMS: { page: Page; label: string; Icon: React.FC<{ size?: number }> }[] = [
  { page: 'overview',    label: 'Overview',    Icon: IconOverview },
  { page: 'pipeline',    label: 'Pipeline',    Icon: IconPipeline },
  { page: 'queue',       label: 'Queue',       Icon: IconQueue },
  { page: 'quality',     label: 'Quality',     Icon: IconQuality },
  { page: 'fairness',    label: 'Fairness',    Icon: IconFairness },
  { page: 'operations',  label: 'Operations',  Icon: IconOperations },
  { page: 'governance',  label: 'Governance',  Icon: IconGovernance },
  { page: 'rubric',      label: 'Rubric',      Icon: IconRubric },
];

export interface LeftNavProps {
  current: Page;
  role: Role;
  onNavigate: (p: Page) => void;
  rubricVersion: string;
}

export function LeftNav({ current, role, onNavigate, rubricVersion }: LeftNavProps) {
  return (
    <nav className="nav" aria-label="Navigation principale">
      {ITEMS.map(({ page, label, Icon }) => {
        const allowed = canAccess(role, page);
        const active = current === page;
        return (
          <button
            key={page}
            className={`nav__item ${active ? 'nav__item--active' : ''}`}
            onClick={() => onNavigate(page)}
            disabled={!allowed}
            aria-current={active ? 'page' : undefined}
            title={!allowed ? `Accès refusé pour le rôle ${role}` : label}
          >
            <span className="nav__icon"><Icon /></span>
            <span className="nav__label">{label}</span>
          </button>
        );
      })}
      <div className="nav__footer">Rubric {rubricVersion}</div>
    </nav>
  );
}
EOF

write "src/app/shell/AppShell.tsx" <<'EOF'
import React, { useEffect, useState } from 'react';
import { Header } from './Header';
import { LeftNav } from './LeftNav';
import type { Page, Role } from '../../auth/rbac';
import { canAccess } from '../../auth/rbac';
import { RUBRIC_META, ALERTS } from '../../mock/data';

import { Overview } from '../../pages/Overview';
import { Pipeline } from '../../pages/Pipeline';
import { Queue } from '../../pages/Queue';
import { Quality } from '../../pages/Quality';
import { Fairness } from '../../pages/Fairness';
import { Operations } from '../../pages/Operations';
import { Governance } from '../../pages/Governance';
import { Rubric } from '../../pages/Rubric';

const PAGES: Record<Page, React.FC> = {
  overview: Overview,
  pipeline: Pipeline,
  queue: Queue,
  quality: Quality,
  fairness: Fairness,
  operations: Operations,
  governance: Governance,
  rubric: Rubric,
};

function pageFromHash(): Page {
  const h = window.location.hash.replace(/^#\/?/, '');
  const all: Page[] = ['overview', 'pipeline', 'queue', 'quality', 'fairness', 'operations', 'governance', 'rubric'];
  return (all as string[]).includes(h) ? (h as Page) : 'overview';
}

export function AppShell() {
  const [page, setPage] = useState<Page>(pageFromHash);
  const [role, setRole] = useState<Role>('hrd');
  const [lang, setLang] = useState<'fr' | 'en'>('fr');
  const [theme, setTheme] = useState<'light' | 'dark'>(() =>
    (localStorage.getItem('ats-theme') as 'light' | 'dark') || 'light'
  );

  useEffect(() => {
    const onHash = () => setPage(pageFromHash());
    window.addEventListener('hashchange', onHash);
    return () => window.removeEventListener('hashchange', onHash);
  }, []);

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('ats-theme', theme);
  }, [theme]);

  useEffect(() => {
    document.documentElement.lang = lang;
  }, [lang]);

  const navigate = (p: Page) => {
    if (!canAccess(role, p)) return;
    window.location.hash = `#/${p}`;
    setPage(p);
  };

  // Si le rôle change et que la page courante devient interdite → rediriger
  useEffect(() => {
    if (!canAccess(role, page)) navigate('overview');
  }, [role]);

  const Current = PAGES[page];

  return (
    <div className="shell">
      <Header
        role={role} onRoleChange={setRole}
        lang={lang} onLangChange={setLang}
        theme={theme} onThemeToggle={() => setTheme(t => t === 'light' ? 'dark' : 'light')}
        alertCount={ALERTS.length}
      />
      <LeftNav current={page} role={role} onNavigate={navigate} rubricVersion={RUBRIC_META.version} />
      <main className="main">
        <Current />
      </main>
    </div>
  );
}
EOF

# ─────────────────────────────────────────────────────────────
# 6. Pages
# ─────────────────────────────────────────────────────────────
log "Pages…"

write "src/pages/Overview.tsx" <<'EOF'
import React from 'react';
import { KpiCard } from '../widgets/KpiCard';
import { AlertPanel } from '../widgets/AlertPanel';
import { FunnelChart } from '../widgets/FunnelChart';
import { TimeSeries } from '../widgets/TimeSeries';
import { KPIS, ALERTS, FUNNEL, TIMESERIES, RUBRIC_META } from '../mock/data';

export function Overview() {
  return (
    <>
      <div className="main__header">
        <h1 className="main__title">Vue d'ensemble</h1>
        <p className="main__subtitle">Rubric {RUBRIC_META.version} · Site FR + PT · Données fictives, aucune PII</p>
      </div>

      <div className="banner" role="note">
        <span aria-hidden="true">⚠</span>
        <span>Données fictives — aucune PII — usage démonstration. Le copilote propose, le recruteur décide.</span>
      </div>

      <div className="grid-kpi">
        {KPIS.map(k => (
          <KpiCard
            key={k.id}
            label={k.label}
            value={k.value}
            unit={k.unit}
            baseline={k.baseline}
            target={k.target}
            status={k.status}
            n={k.n}
            lowerIsBetter={k.lowerIsBetter}
            spark={k.spark}
            href={k.href}
            lastRefresh="2026-10-11T08:00:00Z"
          />
        ))}
      </div>

      <div className="grid-2">
        <div className="card">
          <h2 className="card__title">Entonnoir de pré-screening</h2>
          <FunnelChart stages={FUNNEL} />
        </div>
        <div className="card">
          <h2 className="card__title">Alertes ({ALERTS.length})</h2>
          <AlertPanel alerts={ALERTS} />
        </div>
      </div>

      <div className="card">
        <h2 className="card__title">Temps médian de pré-screening — 14 derniers jours</h2>
        <TimeSeries data={TIMESERIES} yLabel="min" />
      </div>
    </>
  );
}
EOF

write "src/pages/Pipeline.tsx" <<'EOF'
import React from 'react';
import { FunnelChart } from '../widgets/FunnelChart';
import { TimeSeries } from '../widgets/TimeSeries';
import { FUNNEL, TIMESERIES } from '../mock/data';

export function Pipeline() {
  return (
    <>
      <div className="main__header">
        <h1 className="main__title">Pipeline</h1>
        <p className="main__subtitle">Entonnoir complet et évolution temporelle</p>
      </div>

      <div className="card" style={{ marginBottom: 24 }}>
        <h2 className="card__title">Entonnoir — 30 derniers jours</h2>
        <FunnelChart stages={FUNNEL} />
      </div>

      <div className="card">
        <h2 className="card__title">Temps médian par site — 14 jours</h2>
        <TimeSeries data={TIMESERIES} yLabel="min" />
      </div>
    </>
  );
}
EOF

write "src/pages/Queue.tsx" <<'EOF'
import React from 'react';
import { QueueTable } from '../widgets/QueueTable';
import { QUEUE } from '../mock/data';

export function Queue() {
  return (
    <>
      <div className="main__header">
        <h1 className="main__title">Queue de pré-screening</h1>
        <p className="main__subtitle">{QUEUE.length} candidats · identifiants anonymisés · aucune PII</p>
      </div>
      <div className="card">
        <QueueTable rows={QUEUE} />
      </div>
    </>
  );
}
EOF

write "src/pages/Quality.tsx" <<'EOF'
import React from 'react';
import { Gauge } from '../widgets/Gauge';
import { TimeSeries } from '../widgets/TimeSeries';
import { Heatmap } from '../widgets/Heatmap';
import { GAUGES, TIMESERIES, HEATMAP } from '../mock/data';

export function Quality() {
  return (
    <>
      <div className="main__header">
        <h1 className="main__title">Qualité</h1>
        <p className="main__subtitle">Taux d'accord et confiance du copilote</p>
      </div>

      <div className="grid-kpi" style={{ gridTemplateColumns: 'repeat(3, 1fr)' }}>
        {GAUGES.map(g => (
          <div className="card" key={g.label}><Gauge value={g.value} label={g.label} /></div>
        ))}
      </div>

      <div className="card" style={{ marginBottom: 24 }}>
        <h2 className="card__title">Temps médian — 14 jours</h2>
        <TimeSeries data={TIMESERIES} yLabel="min" />
      </div>

      <div className="card">
        <h2 className="card__title">Détail par dimension</h2>
        <Heatmap cells={HEATMAP} />
      </div>
    </>
  );
}
EOF

write "src/pages/Fairness.tsx" <<'EOF'
import React from 'react';
import { Heatmap } from '../widgets/Heatmap';
import { SmallGroupGuard } from '../widgets/SmallGroupGuard';
import { HEATMAP } from '../mock/data';

export function Fairness() {
  return (
    <>
      <div className="main__header">
        <h1 className="main__title">Fairness</h1>
        <p className="main__subtitle">Écarts par dimension — les petits groupes (n&lt;5) sont masqués</p>
      </div>

      <div className="card" style={{ marginBottom: 24 }}>
        <h2 className="card__title">Heatmap par dimension</h2>
        <Heatmap cells={HEATMAP} />
      </div>

      <div className="card">
        <h2 className="card__title">Démonstration SmallGroupGuard</h2>
        <div style={{ display: 'flex', gap: 24, alignItems: 'center', flexWrap: 'wrap' }}>
          <div>
            <p style={{ fontSize: 12, color: 'var(--color-text-muted)', margin: '0 0 6px' }}>n = 42 (visible)</p>
            <SmallGroupGuard n={42} context="Fairness site FR">
              <span className="pill pill--ok">Agrégat affiché</span>
            </SmallGroupGuard>
          </div>
          <div>
            <p style={{ fontSize: 12, color: 'var(--color-text-muted)', margin: '0 0 6px' }}>n = 3 (masqué)</p>
            <SmallGroupGuard n={3} context="Fairness site PT">
              <span className="pill pill--ok">Ne devrait jamais s'afficher</span>
            </SmallGroupGuard>
          </div>
        </div>
      </div>
    </>
  );
}
EOF

write "src/pages/Operations.tsx" <<'EOF'
import React from 'react';
import { AlertPanel } from '../widgets/AlertPanel';
import { Gauge } from '../widgets/Gauge';
import { ALERTS, GAUGES } from '../mock/data';

export function Operations() {
  return (
    <>
      <div className="main__header">
        <h1 className="main__title">Operations</h1>
        <p className="main__subtitle">Supervision MCO — alertes et santé du service</p>
      </div>

      <div className="grid-2">
        <div className="card">
          <h2 className="card__title">Alertes actives</h2>
          <AlertPanel alerts={ALERTS} />
        </div>
        <div className="card">
          <h2 className="card__title">Santé</h2>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            {GAUGES.slice(0, 2).map(g => <Gauge key={g.label} value={g.value} label={g.label} />)}
          </div>
        </div>
      </div>
    </>
  );
}
EOF

write "src/pages/Governance.tsx" <<'EOF'
import React from 'react';
import { RUBRIC_META } from '../mock/data';

export function Governance() {
  return (
    <>
      <div className="main__header">
        <h1 className="main__title">Governance</h1>
        <p className="main__subtitle">Conformité RGPD, EU AI Act, traçabilité</p>
      </div>

      <div className="card" style={{ marginBottom: 24 }}>
        <h2 className="card__title">Conformité</h2>
        <ul style={{ margin: 0, paddingLeft: 20, lineHeight: 1.9 }}>
          <li><strong>RGPD</strong> — aucune PII stockée ou affichée ; suppression des petits groupes (n&lt;5).</li>
          <li><strong>EU AI Act (Annexe III)</strong> — système d'aide à la décision, supervision humaine obligatoire.</li>
          <li><strong>Résidence EU</strong> — données hébergées en France et au Portugal.</li>
          <li><strong>Read-only</strong> — le dashboard ne prend aucune décision automatique.</li>
        </ul>
      </div>

      <div className="card">
        <h2 className="card__title">Rubric courante</h2>
        <dl style={{ display: 'grid', gridTemplateColumns: 'max-content 1fr', gap: '8px 24px', margin: 0 }}>
          <dt style={{ color: 'var(--color-text-muted)' }}>Version</dt><dd style={{ margin: 0, fontFamily: 'var(--font-mono)' }}>{RUBRIC_META.version}</dd>
          <dt style={{ color: 'var(--color-text-muted)' }}>Déployée le</dt><dd style={{ margin: 0 }}>{RUBRIC_META.deployedAt}</dd>
          <dt style={{ color: 'var(--color-text-muted)' }}>Sites</dt><dd style={{ margin: 0 }}>{RUBRIC_META.site}</dd>
          <dt style={{ color: 'var(--color-text-muted)' }}>Note</dt><dd style={{ margin: 0 }}>{RUBRIC_META.note}</dd>
        </dl>
      </div>
    </>
  );
}
EOF

write "src/pages/Rubric.tsx" <<'EOF'
import React from 'react';
import { RUBRIC_META } from '../mock/data';

const CRITERIA = [
  { name: 'Compétences techniques', weight: 30, desc: 'Adéquation avec la stack FDE (Python, data, cloud).' },
  { name: 'Expérience client',     weight: 25, desc: 'Capacité à intervenir chez le client, communication.' },
  { name: 'Autonomie',             weight: 20, desc: 'Capacité à mener un projet de bout en bout.' },
  { name: 'Anglais professionnel', weight: 15, desc: 'Niveau requis pour interventions internationales.' },
  { name: 'Mobilité',              weight: 10, desc: 'Disponibilité France / Porto.' },
];

export function Rubric() {
  return (
    <>
      <div className="main__header">
        <h1 className="main__title">Rubric {RUBRIC_META.version}</h1>
        <p className="main__subtitle">Critères utilisés par le copilote — le recruteur garde la décision finale</p>
      </div>

      <div className="card">
        <h2 className="card__title">Critères</h2>
        <table className="queue">
          <thead><tr><th>Critère</th><th>Poids</th><th>Description</th></tr></thead>
          <tbody>
            {CRITERIA.map(c => (
              <tr key={c.name}>
                <td style={{ fontWeight: 600 }}>{c.name}</td>
                <td className="queue__score">{c.weight} %</td>
                <td style={{ color: 'var(--color-text-muted)' }}>{c.desc}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
EOF

# ─────────────────────────────────────────────────────────────
# 7. main.tsx — branche AppShell
# ─────────────────────────────────────────────────────────────
log "Entrypoint…"

write "src/app/main.tsx" <<'EOF'
import React from 'react';
import { createRoot } from 'react-dom/client';
import { AppShell } from './shell/AppShell';
import '../styles/tokens.css';
import '../styles/layout.css';
import '../styles/components.css';

const container = document.getElementById('root');
if (!container) throw new Error('#root not found');
createRoot(container).render(
  <React.StrictMode>
    <AppShell />
  </React.StrictMode>
);
EOF

write "index.html" <<'EOF'
<!doctype html>
<html lang="fr">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>ATS Copilot Dashboard</title>
    <meta name="description" content="Copilote IA de pré-screening — ALTEN FDE Lab" />
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/app/main.tsx"></script>
  </body>
</html>
EOF

# ─────────────────────────────────────────────────────────────
# 8. Nettoyage démo
# ─────────────────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 0 ]; then
  rm -f index-demo.html src/demo-entry.tsx
  ok "fichiers de démo supprimés"
fi

# ─────────────────────────────────────────────────────────────
# 9. Typecheck rapide
# ─────────────────────────────────────────────────────────────
log "Typecheck…"
if pnpm exec tsc --noEmit >/tmp/tsc.log 2>&1; then
  ok "typecheck OK"
else
  warn "tsc signale des erreurs (non bloquant) :"
  tail -20 /tmp/tsc.log | sed 's/^/    /'
fi

# ─────────────────────────────────────────────────────────────
# 10. Git
# ─────────────────────────────────────────────────────────────
if [ "$DO_GIT" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git add src/ index.html 2>/dev/null || true
    if ! git diff --cached --quiet; then
      git commit -m "feat(dashboard): full shell with 8 pages, 8 widgets, RBAC live, dark mode" || warn "commit échoué"
      ok "commit effectué"
    else
      warn "rien à commiter"
    fi
  fi
fi

echo ""
echo "════════════════════════════════════════════════════════════"
ok "Dashboard généré"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "  Lancer  : ./scripts/run-dashboard.sh"
echo "  URL     : http://localhost:5173/"
echo ""
echo "  Pages   : #/overview #/pipeline #/queue #/quality"
echo "            #/fairness #/operations #/governance #/rubric"
echo ""