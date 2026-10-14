// src/widgets/FunnelChart/FunnelChart.tsx
// Entonnoir de conversion (read-only). Chaque étape = un agrégat.
import { SmallGroupGuard } from "../SmallGroupGuard";
import styles from "./FunnelChart.module.css";

export interface FunnelStage {
  /** Libellé déjà traduit. */
  label: string;
  /** Effectif de l'étape. */
  count: number;
}

export interface FunnelChartProps {
  label: string;
  stages: readonly FunnelStage[];
  minSampleSize?: number | null;
  k?: number;
}

export function FunnelChart({
  label, stages, minSampleSize, k = 5,
}: FunnelChartProps) {
  if (stages.length === 0) {
    return <div className={styles.empty} role="status">Aucune donnée</div>;
  }
  const max = Math.max(...stages.map((s) => s.count), 1);

  const body = (
    <section className={styles.wrap} data-widget="funnel-chart" aria-label={label}>
      <h4 className={styles.title}>{label}</h4>
      <ol className={styles.list}>
        {stages.map((s) => {
          const pct = (s.count / max) * 100;
          const total = stages[0].count || 1;
          const rate = (s.count / total) * 100;
          return (
            <li key={s.label} className={styles.item}>
              <span className={styles.stageLabel}>{s.label}</span>
              <span className={styles.barWrap}>
                <span className={styles.bar} style={{ width: `${pct}%` }} />
              </span>
              <span className={styles.value}>
                {s.count} <span className={styles.rate}>({rate.toFixed(0)}%)</span>
              </span>
            </li>
          );
        })}
      </ol>
    </section>
  );

  if (minSampleSize === undefined || minSampleSize === null) return body;
  return (
    <SmallGroupGuard n={minSampleSize} k={k} label={label}>
      {body}
    </SmallGroupGuard>
  );
}
