// src/widgets/Heatmap/Heatmap.tsx
// Carte de chaleur (read-only). Cellules = agrégats ; RGPD : masque si < k.
import { SmallGroupGuard } from "../SmallGroupGuard";
import styles from "./Heatmap.module.css";

export interface HeatmapCell {
  row: string;
  col: string;
  /** Valeur numérique. `null` => cellule non disponible. */
  value: number | null;
  /** Effectif de l'agrégat — si < k, la cellule est masquée. */
  sampleSize?: number | null;
}

export interface HeatmapProps {
  label: string;
  rows: readonly string[];
  cols: readonly string[];
  cells: readonly HeatmapCell[];
  k?: number;
  /** Format affiché pour la valeur (défaut : toFixed(1)). */
  formatValue?: (v: number) => string;
}

function pickColor(value: number | null, min: number, max: number): string {
  if (value === null) return "var(--c-border, #e3e6eb)";
  const t = max > min ? (value - min) / (max - min) : 0.5;
  // Échelle simple : accent du plus clair au plus saturé
  const alpha = 0.15 + 0.85 * Math.max(0, Math.min(1, t));
  return `color-mix(in oklab, var(--c-accent, #2f6feb) ${(alpha * 100).toFixed(0)}%, #fff)`;
}

export function Heatmap({
  label, rows, cols, cells, k = 5, formatValue,
}: HeatmapProps) {
  const byKey = new Map<string, HeatmapCell>();
  for (const c of cells) byKey.set(`${c.row}|${c.col}`, c);

  const values = cells
    .map((c) => c.value)
    .filter((v): v is number => typeof v === "number" && Number.isFinite(v));
  const min = values.length ? Math.min(...values) : 0;
  const max = values.length ? Math.max(...values) : 1;
  const fmt = formatValue ?? ((v: number) => v.toFixed(1));

  const hasSmall = cells.some(
    (c) => typeof c.sampleSize === "number" && c.sampleSize < k,
  );

  const body = (
    <section className={styles.wrap} data-widget="heatmap" aria-label={label}>
      <h4 className={styles.title}>{label}</h4>
      <table className={styles.grid}>
        <thead>
          <tr>
            <th aria-hidden />
            {cols.map((c) => (
              <th key={c} scope="col" className={styles.colHead}>{c}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r}>
              <th scope="row" className={styles.rowHead}>{r}</th>
              {cols.map((c) => {
                const cell = byKey.get(`${r}|${c}`);
                const masked =
                  !cell ||
                  (typeof cell.sampleSize === "number" && cell.sampleSize < k);
                const v = cell?.value ?? null;
                if (masked) {
                  return (
                    <td
                      key={c}
                      className={styles.cell}
                      data-masked="true"
                      aria-label="Donnée masquée"
                    >
                      —
                    </td>
                  );
                }
                return (
                  <td
                    key={c}
                    className={styles.cell}
                    style={{ background: pickColor(v, min, max) }}
                    title={v === null ? "n/a" : fmt(v)}
                  >
                    {v === null ? "—" : fmt(v)}
                  </td>
                );
              })}
            </tr>
          ))}
        </tbody>
      </table>
      {hasSmall && (
        <p className={styles.note}>
          Certaines cellules sont masquées (effectif &lt; {k}).
        </p>
      )}
    </section>
  );

  return body;
}
