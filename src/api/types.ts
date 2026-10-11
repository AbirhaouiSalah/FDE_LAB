export type Site = 'FR' | 'PT';
export type Confidence = 'low' | 'medium' | 'high';
export interface KpiSnapshot {
  metric_name: string;
  value: number;
  unit: 'seconds'|'hours'|'days'|'count'|'ratio'|'percent';
  period: string;
  site?: Site;
  rubric_version: string;
  baseline?: number;
  target?: number;
  status: 'ok'|'watch'|'alert';
  last_refresh: string;
}
