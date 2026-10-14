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
