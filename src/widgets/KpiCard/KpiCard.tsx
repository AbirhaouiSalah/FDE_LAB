// src/widgets/KpiCard/KpiCard.tsx
// Carte KPI read-only. Aucune décision automatique : affichage uniquement.
import { type ReactNode } from "react";
import { SmallGroupGuard } from "../SmallGroupGuard";
import styles from "./KpiCard.module.css";

export type KpiTrend = "up" | "down" | "flat";

export interface KpiCardProps {
  /** Libellé court, déjà traduit par l'appelant. */
  label: string;
  /** Valeur numérique principale (agrégat). */
  value: number | null | undefined;
  /** Variation optionnelle (ex. +3.2 pour +3.2%). */
  delta?: number;
  /** Tendance visuelle (accessoire, sans sémantique de décision). */
  trend?: KpiTrend;
  /** Effectif de l'agrégat — déclenche le masquage RGPD si < k. */
  sampleSize?: number | null;
  /** Seuil de masquage (défaut 5). */
  k?: number;
  /** Unité affichée (%, pts, etc.). */
  unit?: string;
  /** Contenu additionnel (footer). */
  footer?: ReactNode;
}

function fmt(v: number | null | undefined, unit?: string): string {
  if (v === null || v === undefined || !Number.isFinite(v)) return "—";
  const s = Math.abs(v) >= 100 ? v.toFixed(0) : v.toFixed(1);
  return unit ? `${s}${unit}` : s;
}

export function KpiCard({
  label, value, delta, trend = "flat", sampleSize, k = 5, unit, footer,
}: KpiCardProps) {
  const body = (
    <div className={styles.card} data-widget="kpi-card">
      <div className={styles.label}>{label}</div>
      <div className={styles.value} aria-live="polite">{fmt(value, unit)}</div>
      {typeof delta === "number" && Number.isFinite(delta) && (
        <div className={styles.delta} data-trend={trend}>
          {delta > 0 ? "+" : ""}{delta.toFixed(1)}
        </div>
      )}
      {footer && <div className={styles.footer}>{footer}</div>}
    </div>
  );

  if (sampleSize === undefined) return body;

  return (
    <SmallGroupGuard n={sampleSize} k={k} label={label}>
      {body}
    </SmallGroupGuard>
  );
}
