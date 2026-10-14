// src/widgets/Gauge/Gauge.tsx
// Jauge demi-cercle (read-only). Affiche un score dans [0,100].
import { SmallGroupGuard } from "../SmallGroupGuard";
import styles from "./Gauge.module.css";

export interface GaugeProps {
  label: string;
  /** Valeur 0..100. */
  value: number | null | undefined;
  minSampleSize?: number | null;
  k?: number;
  /** Unité affichée (%, pts, ...). Défaut "%". */
  unit?: string;
}

function polar(cx: number, cy: number, r: number, angleDeg: number) {
  const rad = ((angleDeg - 180) * Math.PI) / 180;
  return { x: cx + r * Math.cos(rad), y: cy + r * Math.sin(rad) };
}

function arc(cx: number, cy: number, r: number, start: number, end: number): string {
  const s = polar(cx, cy, r, start);
  const e = polar(cx, cy, r, end);
  const large = end - start > 180 ? 1 : 0;
  return `M${s.x.toFixed(1)},${s.y.toFixed(1)} A${r},${r} 0 ${large} 1 ${e.x.toFixed(1)},${e.y.toFixed(1)}`;
}

export function Gauge({
  label, value, minSampleSize, k = 5, unit = "%",
}: GaugeProps) {
  const safeVal =
    typeof value === "number" && Number.isFinite(value)
      ? Math.max(0, Math.min(100, value))
      : null;

  const body = (
    <figure className={styles.figure} data-widget="gauge">
      <svg
        viewBox="0 0 120 70"
        className={styles.svg}
        role="img"
        aria-label={`${label} : ${safeVal === null ? "non disponible" : `${safeVal.toFixed(0)}${unit}`}`}
      >
        <path d={arc(60, 60, 50, 0, 180)} fill="none" stroke="var(--c-border, #e3e6eb)" strokeWidth="10" />
        {safeVal !== null && (
          <path
            d={arc(60, 60, 50, 0, (safeVal / 100) * 180)}
            fill="none"
            stroke="var(--c-accent, #2f6feb)"
            strokeWidth="10"
            strokeLinecap="round"
          />
        )}
      </svg>
      <figcaption className={styles.caption}>
        <span className={styles.label}>{label}</span>
        <span className={styles.value}>
          {safeVal === null ? "—" : `${safeVal.toFixed(0)}${unit}`}
        </span>
      </figcaption>
    </figure>
  );

  if (minSampleSize === undefined || minSampleSize === null) return body;
  return (
    <SmallGroupGuard n={minSampleSize} k={k} label={label}>
      {body}
    </SmallGroupGuard>
  );
}
