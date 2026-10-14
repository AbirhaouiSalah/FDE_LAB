#!/usr/bin/env bash
# scripts/lots/build-lot-3.sh
# L3 — Widgets Visualisation : TimeSeries + FunnelChart + Gauge + Heatmap
# Branche pivot : ats-lab/comp/widgets/time-series
#
# Usage:
#   bash scripts/lots/build-lot-3.sh [--dry-run] [--yes] [--skip-tests] [--skip-push]

set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Source helpers EN PREMIER
# ─────────────────────────────────────────────────────────────
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

# ─────────────────────────────────────────────────────────────
# Config du lot
# ─────────────────────────────────────────────────────────────
LOT_ID="L3"
LOT_TAG="${LOT_ID}"; export LOT_TAG
LOT_NAME="Widgets Visualisation"
PIVOT_BRANCH="ats-lab/comp/widgets/time-series"
SIBLING_BRANCHES=(
  "ats-lab/comp/widgets/funnel-chart"
  "ats-lab/comp/widgets/gauge"
  "ats-lab/comp/widgets/heatmap"
)
LOT_FILES="src/widgets/TimeSeries/ src/widgets/FunnelChart/ src/widgets/Gauge/ src/widgets/Heatmap/"
COMMIT_MSG="feat(L3): widgets visualisation — TimeSeries + FunnelChart + Gauge + Heatmap"

# ─────────────────────────────────────────────────────────────
# Args — ⚠ parse_common_flags renvoie un NOMBRE, pas un code de succès
# ─────────────────────────────────────────────────────────────
parse_common_flags "$@" || true

# ─────────────────────────────────────────────────────────────
# Pré-requis (défensif : check_prereqs peut être absent de _lib.sh)
# ─────────────────────────────────────────────────────────────
if command -v check_prereqs >/dev/null 2>&1; then
  check_prereqs || true
else
  require_repo_root || true
fi

ensure_branch "$PIVOT_BRANCH" || true

log_init "${LOT_ID}"
log_step "${LOT_ID} — ${LOT_NAME}"
log_dim "pivot     : ${PIVOT_BRANCH}"
log_dim "siblings  : ${SIBLING_BRANCHES[*]}"
log_dim "files     : ${LOT_FILES}"
log_dim "mode      : $( [[ "${DRY_RUN}" == "1" ]] && echo DRY-RUN || echo APPLY )"

# ═══════════════════════════════════════════════════════════════════════════
# Utilitaires locaux (compatibles bash 3.2 — pas de declare -A)
# ═══════════════════════════════════════════════════════════════════════════

# Lookup de libellé par clé (équivalent d'un map associatif)
widget_label() {
  case "$1" in
    TimeSeries)  echo "Série temporelle" ;;
    FunnelChart) echo "Entonnoir" ;;
    Gauge)       echo "Jauge" ;;
    Heatmap)     echo "Carte de chaleur" ;;
    *)           echo "$1" ;;
  esac
}

# Liste canonique des widgets du lot
widgets_list() {
  echo "TimeSeries FunnelChart Gauge Heatmap"
}

# ═══════════════════════════════════════════════════════════════════════════
# 1. TimeSeries — courbe temporelle (read-only)
# ═══════════════════════════════════════════════════════════════════════════

write_file "src/widgets/TimeSeries/TimeSeries.tsx" <<'EOF'
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
EOF

write_file "src/widgets/TimeSeries/TimeSeries.module.css" <<'EOF'
/* src/widgets/TimeSeries/TimeSeries.module.css */
.figure {
  margin: 0;
  padding: 12px;
  background: var(--c-surface, #fff);
  border: 1px solid var(--c-border, #e3e6eb);
  border-radius: var(--radius-md, 8px);
  color: var(--c-accent, #2f6feb);
}
.caption {
  font-size: var(--fs-sm, 13px);
  color: var(--c-text-muted, #5b6472);
  margin-bottom: 6px;
}
.lastValue { color: var(--c-text, #1c2024); font-weight: 600; }
.svg { width: 100%; height: 120px; display: block; }
EOF

write_file "src/widgets/TimeSeries/TimeSeries.test.tsx" <<'EOF'
// src/widgets/TimeSeries/TimeSeries.test.tsx
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { TimeSeries } from "./TimeSeries";

const points = [
  { t: "2026-01-01", v: 10 },
  { t: "2026-02-01", v: 20 },
  { t: "2026-03-01", v: 15 },
];

describe("TimeSeries", () => {
  it("affiche un path SVG", () => {
    const { container } = render(<TimeSeries label="Candidats" points={points} />);
    expect(container.querySelector("path")).toBeInTheDocument();
  });

  it("affiche le dernier point", () => {
    render(<TimeSeries label="Candidats" points={points} unit="%" />);
    expect(screen.getByText(/15\.0%/)).toBeInTheDocument();
  });

  it("affiche un path vide si aucun point", () => {
    const { container } = render(<TimeSeries label="Vide" points={[]} />);
    const path = container.querySelector("path");
    expect(path?.getAttribute("d")).toBe("");
  });

  it("masque si minSampleSize < k", () => {
    render(<TimeSeries label="Candidats" points={points} minSampleSize={3} k={5} />);
    expect(screen.queryByRole("img")).not.toBeInTheDocument();
    expect(screen.getByRole("status")).toBeInTheDocument();
  });
});
EOF

write_file "src/widgets/TimeSeries/index.ts" <<'EOF'
export { TimeSeries } from "./TimeSeries";
export type { TimeSeriesProps, TimeSeriesPoint } from "./TimeSeries";
EOF

# ═══════════════════════════════════════════════════════════════════════════
# 2. FunnelChart — entonnoir de conversion
# ═══════════════════════════════════════════════════════════════════════════

write_file "src/widgets/FunnelChart/FunnelChart.tsx" <<'EOF'
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
EOF

write_file "src/widgets/FunnelChart/FunnelChart.module.css" <<'EOF'
/* src/widgets/FunnelChart/FunnelChart.module.css */
.wrap {
  padding: 12px;
  background: var(--c-surface, #fff);
  border: 1px solid var(--c-border, #e3e6eb);
  border-radius: var(--radius-md, 8px);
}
.title { margin: 0 0 8px; font-size: var(--fs-md, 14px); }
.list { list-style: none; margin: 0; padding: 0; display: grid; gap: 4px; }
.item {
  display: grid;
  grid-template-columns: 100px 1fr auto;
  align-items: center;
  gap: 8px;
  font-size: var(--fs-sm, 13px);
}
.stageLabel { color: var(--c-text-muted, #5b6472); }
.barWrap {
  background: var(--c-border, #e3e6eb);
  height: 10px;
  border-radius: 5px;
  overflow: hidden;
}
.bar {
  display: block;
  height: 100%;
  background: var(--c-accent, #2f6feb);
}
.value { font-variant-numeric: tabular-nums; }
.rate { color: var(--c-text-muted, #5b6472); }
.empty {
  padding: 16px;
  text-align: center;
  color: var(--c-text-muted, #5b6472);
  font-size: var(--fs-sm, 13px);
}
EOF

write_file "src/widgets/FunnelChart/FunnelChart.test.tsx" <<'EOF'
// src/widgets/FunnelChart/FunnelChart.test.tsx
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { FunnelChart } from "./FunnelChart";

const stages = [
  { label: "Candidatures", count: 100 },
  { label: "Pré-sélection", count: 60 },
  { label: "Entretien", count: 20 },
];

describe("FunnelChart", () => {
  it("affiche chaque étape", () => {
    render(<FunnelChart label="Entonnoir" stages={stages} />);
    expect(screen.getByText("Candidatures")).toBeInTheDocument();
    expect(screen.getByText("Pré-sélection")).toBeInTheDocument();
    expect(screen.getByText("Entretien")).toBeInTheDocument();
  });

  it("affiche un message vide", () => {
    render(<FunnelChart label="Vide" stages={[]} />);
    expect(screen.getByText("Aucune donnée")).toBeInTheDocument();
  });

  it("calcule les taux par rapport à la 1ère étape", () => {
    render(<FunnelChart label="Entonnoir" stages={stages} />);
    expect(screen.getByText("(60%)")).toBeInTheDocument();
    expect(screen.getByText("(20%)")).toBeInTheDocument();
  });

  it("masque si minSampleSize < k", () => {
    render(<FunnelChart label="Entonnoir" stages={stages} minSampleSize={3} k={5} />);
    expect(screen.queryByText("Candidatures")).not.toBeInTheDocument();
  });
});
EOF

write_file "src/widgets/FunnelChart/index.ts" <<'EOF'
export { FunnelChart } from "./FunnelChart";
export type { FunnelChartProps, FunnelStage } from "./FunnelChart";
EOF

# ═══════════════════════════════════════════════════════════════════════════
# 3. Gauge — jauge demi-cercle
# ═══════════════════════════════════════════════════════════════════════════

write_file "src/widgets/Gauge/Gauge.tsx" <<'EOF'
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
EOF

write_file "src/widgets/Gauge/Gauge.module.css" <<'EOF'
/* src/widgets/Gauge/Gauge.module.css */
.figure {
  margin: 0;
  padding: 12px;
  background: var(--c-surface, #fff);
  border: 1px solid var(--c-border, #e3e6eb);
  border-radius: var(--radius-md, 8px);
  text-align: center;
}
.svg { width: 100%; max-width: 200px; height: auto; display: block; margin: 0 auto; }
.caption { display: flex; flex-direction: column; gap: 2px; margin-top: 6px; }
.label { font-size: var(--fs-sm, 13px); color: var(--c-text-muted, #5b6472); }
.value { font-size: var(--fs-lg, 16px); font-weight: 600; }
EOF

write_file "src/widgets/Gauge/Gauge.test.tsx" <<'EOF'
// src/widgets/Gauge/Gauge.test.tsx
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { Gauge } from "./Gauge";

describe("Gauge", () => {
  it("affiche la valeur formatée", () => {
    render(<Gauge label="Score" value={72.4} />);
    expect(screen.getByText("72%")).toBeInTheDocument();
  });

  it("clampe au-delà de 100", () => {
    render(<Gauge label="Score" value={150} />);
    expect(screen.getByText("100%")).toBeInTheDocument();
  });

  it("clampe en dessous de 0", () => {
    render(<Gauge label="Score" value={-5} />);
    expect(screen.getByText("0%")).toBeInTheDocument();
  });

  it("affiche — si null", () => {
    render(<Gauge label="Score" value={null} />);
    expect(screen.getByText("—")).toBeInTheDocument();
  });

  it("masque si minSampleSize < k", () => {
    render(<Gauge label="Score" value={72} minSampleSize={2} k={5} />);
    expect(screen.queryByRole("img")).not.toBeInTheDocument();
  });
});
EOF

write_file "src/widgets/Gauge/index.ts" <<'EOF'
export { Gauge } from "./Gauge";
export type { GaugeProps } from "./Gauge";
EOF

# ═══════════════════════════════════════════════════════════════════════════
# 4. Heatmap — carte de chaleur (matrice valeurs)
# ═══════════════════════════════════════════════════════════════════════════

write_file "src/widgets/Heatmap/Heatmap.tsx" <<'EOF'
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
EOF

write_file "src/widgets/Heatmap/Heatmap.module.css" <<'EOF'
/* src/widgets/Heatmap/Heatmap.module.css */
.wrap {
  padding: 12px;
  background: var(--c-surface, #fff);
  border: 1px solid var(--c-border, #e3e6eb);
  border-radius: var(--radius-md, 8px);
}
.title { margin: 0 0 8px; font-size: var(--fs-md, 14px); }
.grid { border-collapse: separate; border-spacing: 2px; font-size: var(--fs-sm, 13px); }
.colHead, .rowHead { font-weight: 600; color: var(--c-text-muted, #5b6472); padding: 4px 6px; }
.cell {
  width: 44px;
  height: 28px;
  text-align: center;
  vertical-align: middle;
  border-radius: 3px;
  color: var(--c-text, #1c2024);
  font-variant-numeric: tabular-nums;
}
.cell[data-masked="true"] {
  background: var(--c-bg, #f7f8fa);
  color: var(--c-text-muted, #5b6472);
}
.note { margin: 8px 0 0; font-size: var(--fs-sm, 13px); color: var(--c-text-muted, #5b6472); }
EOF

write_file "src/widgets/Heatmap/Heatmap.test.tsx" <<'EOF'
// src/widgets/Heatmap/Heatmap.test.tsx
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { Heatmap } from "./Heatmap";

const rows = ["Nord", "Sud"];
const cols = ["Q1", "Q2"];
const cells = [
  { row: "Nord", col: "Q1", value: 10, sampleSize: 20 },
  { row: "Nord", col: "Q2", value: 20, sampleSize: 20 },
  { row: "Sud",  col: "Q1", value: 15, sampleSize: 2 }, // trop petit
  { row: "Sud",  col: "Q2", value: 25, sampleSize: 20 },
];

describe("Heatmap", () => {
  it("rend une cellule par case", () => {
    const { container } = render(
      <Heatmap label="Heat" rows={rows} cols={cols} cells={cells} k={5} />
    );
    expect(container.querySelectorAll("td")).toHaveLength(4);
  });

  it("masque les cellules sous le seuil k", () => {
    const { container } = render(
      <Heatmap label="Heat" rows={rows} cols={cols} cells={cells} k={5} />
    );
    expect(container.querySelectorAll("[data-masked='true']")).toHaveLength(1);
  });

  it("affiche une note quand des cellules sont masquées", () => {
    render(<Heatmap label="Heat" rows={rows} cols={cols} cells={cells} k={5} />);
    expect(screen.getByText(/masquées/)).toBeInTheDocument();
  });

  it("affiche une cellule vide si absente", () => {
    const partial = [{ row: "Nord", col: "Q1", value: 10, sampleSize: 20 }];
    const { container } = render(
      <Heatmap label="Heat" rows={rows} cols={cols} cells={partial} k={5} />
    );
    expect(container.querySelectorAll("[data-masked='true']").length).toBeGreaterThan(0);
  });
});
EOF

write_file "src/widgets/Heatmap/index.ts" <<'EOF'
export { Heatmap } from "./Heatmap";
export type { HeatmapProps, HeatmapCell } from "./Heatmap";
EOF

# ═══════════════════════════════════════════════════════════════════════════
# 5. Barrel export — src/widgets/index.ts (enrichi, on préserve L2 si présent)
# ═══════════════════════════════════════════════════════════════════════════

if [[ -f "${REPO_ROOT}/src/widgets/index.ts" ]] && grep -q "SmallGroupGuard" "${REPO_ROOT}/src/widgets/index.ts" 2>/dev/null; then
  # L2 déjà passé : on ajoute seulement les exports L3
  tmp="$(mktemp)"
  cp "${REPO_ROOT}/src/widgets/index.ts" "$tmp"
  for w in TimeSeries FunnelChart Gauge Heatmap; do
    if ! grep -q "widgets/${w}" "$tmp" 2>/dev/null && ! grep -q "\"./${w}\"" "$tmp" 2>/dev/null; then
      {
        echo ""
        echo "export { ${w} } from \"./${w}\";"
      } >> "$tmp"
    fi
  done
  # Réécrit via write_file pour bénéficier du dry-run / backup
  write_file "src/widgets/index.ts" < "$tmp"
  rm -f "$tmp"
else
  # Aucun barrel existant : on crée un barrel complet L2+L3
  write_file "src/widgets/index.ts" <<'EOF'
// src/widgets/index.ts — barrel export (L2 + L3)
// --- L2 : Widgets RGPD & Data ---
export { SmallGroupGuard } from "./SmallGroupGuard";
export type { SmallGroupGuardProps } from "./SmallGroupGuard";

export { KpiCard } from "./KpiCard";
export type { KpiCardProps, KpiTrend } from "./KpiCard";

export { QueueTable } from "./QueueTable";
export type { QueueTableProps, QueueRow } from "./QueueTable";

export { AlertPanel } from "./AlertPanel";
export type { AlertPanelProps, AlertLevel } from "./AlertPanel";

// --- L3 : Widgets Visualisation ---
export { TimeSeries } from "./TimeSeries";
export type { TimeSeriesProps, TimeSeriesPoint } from "./TimeSeries";

export { FunnelChart } from "./FunnelChart";
export type { FunnelChartProps, FunnelStage } from "./FunnelChart";

export { Gauge } from "./Gauge";
export type { GaugeProps } from "./Gauge";

export { Heatmap } from "./Heatmap";
export type { HeatmapProps, HeatmapCell } from "./Heatmap";
EOF
fi

# ═══════════════════════════════════════════════════════════════════════════
# 6. Tests (optionnels selon flags)
# ═══════════════════════════════════════════════════════════════════════════

if [[ "${DRY_RUN}" != "1" ]] && [[ "${SKIP_TESTS:-0}" != "1" ]]; then
  log_step "${LOT_ID} — tests"
  run_vitest "src/widgets/TimeSeries src/widgets/FunnelChart src/widgets/Gauge src/widgets/Heatmap" \
    || warn "certains tests ont échoué (non bloquant)"
fi

# ═══════════════════════════════════════════════════════════════════════════
# 7. Résumé
# ═══════════════════════════════════════════════════════════════════════════

log_dim "widgets   : $(widgets_list)"
for w in $(widgets_list); do
  log_dim "  • ${w} — $(widget_label "$w")"
done

FILES_WRITTEN="$(
  git -C "$REPO_ROOT" status --porcelain src/widgets 2>/dev/null \
    | /usr/bin/wc -l | tr -d ' '
)"
lot_summary "${LOT_ID}" "${FILES_WRITTEN:-0}" "4 widgets + tests + barrel"
log_ok "${LOT_ID} — complete"