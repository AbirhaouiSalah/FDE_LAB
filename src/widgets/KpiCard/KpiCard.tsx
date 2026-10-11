import React from 'react';
import { SmallGroupGuard } from '../SmallGroupGuard';

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
  /** Nombre de candidats dans le groupe. Si < 5, l'agrégat est masqué (RGPD). */
  n?: number;
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

function KpiCardInner(props: KpiCardProps) {
  const {
    label, value, unit, baseline, target,
    status = 'ok', lastRefresh, href,
  } = props;

  const delta = deltaPct(value, baseline);
  const sign  = delta === null ? '' : delta >= 0 ? '+' : '';

  return (
    <article
      data-testid="kpi-card"
      data-status={status}
      aria-label={`${label}: ${formatValue(value, unit)}`}
      className={`kpi-card kpi-card--${status}`}
    >
      <h3 className="kpi-card__label">{label}</h3>
      <p className="kpi-card__value">{formatValue(value, unit)}</p>

      {delta !== null && (
        <p className="kpi-card__delta" data-testid="kpi-card-delta">
          {sign}{delta.toFixed(1)} % vs baseline
        </p>
      )}

      {target !== undefined && (
        <p className="kpi-card__target" data-testid="kpi-card-target">
          Cible : {formatValue(target, unit)}
        </p>
      )}

      {lastRefresh && (
        <p className="kpi-card__refresh">
          Dernière mise à jour : {lastRefresh}
        </p>
      )}

      {href && (
        <a
          className="kpi-card__link"
          href={href}
          aria-label={`Voir la définition de ${label}`}
        >
          Définition
        </a>
      )}
    </article>
  );
}

export function KpiCard(props: KpiCardProps) {
  const { n, label } = props;
  if (n !== undefined && n < 5) {
    return (
      <SmallGroupGuard n={n} context={label}>
        {null}
      </SmallGroupGuard>
    );
  }
  return <KpiCardInner {...props} />;
}
