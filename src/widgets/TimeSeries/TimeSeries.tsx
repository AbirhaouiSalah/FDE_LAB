// src/widgets/TimeSeries/TimeSeries.tsx
// Courbe temporelle read-only. Aucune décision automatique.
import { useMemo } from "react";
import { SmallGroupGuard } from "../SmallGroupGuard";
import styles from "./TimeSeries.module.css";

export interface TimeSeriesPoint {
  /** Date ISO (YYYY-MM-DD ou ISO 8601 complet). */
  t: string;
  /** Valeur numérique. */
  v: number;
}

export interface TimeSeriesProps {
  label: string;
  points: readonly TimeSeriesPoint[];
  /** Effectif par point — si < k, on masque tout le graphe. */
  minSampleSize?: number | null;
  k?: number;
  /** Unité affichée à droite du dernier point. */
  unit?: string;
  /** Hauteur SVG en pixels (défaut 120). */
  height?: number;
}

const PADDING = 8;

function buildPath(points: readonly TimeSeriesPoint[], w: number, h: number): string {
  if (points.length === 0) return "";
  const vs = points.map((p) => p.v);
  const minV = Math.min(...vs);
  const maxV = Math.max(...vs);
  const range = maxV - minV || 1;
  const innerW = w - PADDING * 2;
  const innerH = h - PADDING * 2;
  return points
    .map((p, i) => {
      const x = PADDING + (i / Math.max(points.length - 1, 1)) * innerW;
      const y = PADDING + innerH - ((p.v - minV) / range) * innerH;
      return `${i === 0 ? "M" : "L"}${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(" ");
}

export function TimeSeries({
  label, points, minSampleSize, k = 5, unit, height = 120,
}: TimeSeriesProps) {
  const w = 320;
  const path = useMemo(() => buildPath(points, w, height), [points, height]);
  const last = points[points.length - 1];

  const body = (
    <figure className={styles.figure} data-widget="time-series">
      <figcaption className={styles.caption}>
        {label}
        {last && (
          <span className={styles.lastValue}>
            {" "}
            — {Number.isFinite(last.v) ? last.v.toFixed(1) : "—"}{unit ?? ""}
          </span>
        )}
      </figcaption>
      <svg
        className={styles.svg}
        role="img"
        aria-label={`Série temporelle : ${label}`}
        viewBox={`0 0 ${w} ${height}`}
        preserveAspectRatio="none"
      >
        <path d={path} fill="none" stroke="currentColor" strokeWidth="1.5" />
      </svg>
    </figure>
  );

  if (minSampleSize === undefined || minSampleSize === null) return body;
  return (
    <SmallGroupGuard n={minSampleSize} k={k} label={label}>
      {body}
    </SmallGroupGuard>
  );
}
