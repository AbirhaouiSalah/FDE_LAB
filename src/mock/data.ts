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

// ─── Mappers : mock data → props widgets L3 ─────────────────────────────

export function toTimeSeriesPoints(
  pts: TimeseriesPoint[],
): { t: string; v: number }[] {
  return pts.map((p) => ({ t: p.day, v: p.fr }));
}

export function toFunnelStages(
  stages: FunnelStage[],
): { label: string; count: number }[] {
  return stages.map((s) => ({ label: s.label, count: s.value }));
}

export function toHeatmapCells(
  cells: HeatCell[],
): { row: string; col: string; value: number | null; sampleSize?: number | null }[] {
  return cells.map((c) => ({
    row: c.dimension,
    col: c.group,
    value: c.value,
    sampleSize: c.n,
  }));
}

export function toAlertLevel(
  level: string,
): "info" | "warning" | "critical" {
  if (level === "warn") return "warning";
  if (level === "error") return "critical";
  return "info";
}

export function toQueueRows(
  rows: QueueRow[],
): { id: string; label: string; status: string; priority?: number; updatedAt?: string }[] {
  return rows.map((r) => ({
    id: r.id,
    label: r.id,
    status: r.status,
    priority: undefined,
    updatedAt: undefined,
  }));
}
