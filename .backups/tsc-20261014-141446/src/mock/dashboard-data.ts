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
