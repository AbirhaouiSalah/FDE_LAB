
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
      <article data-status={status} aria-label={`: agrégat masqué (n<5)`}
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
          {target !== undefined && <span data-testid="kpi-card-target">Cible : {formatValue(target, unit)}</span>}
          {lastRefresh && <span>Dernière mise à jour : {new Date(lastRefresh).toLocaleDateString("fr-FR")}</span>}
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
