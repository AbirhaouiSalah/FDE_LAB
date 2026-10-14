import { Gauge } from "../widgets/Gauge";
import { TimeSeries } from "../widgets/TimeSeries";
import { Heatmap } from "../widgets/Heatmap";
import {
  GAUGES, TIMESERIES, HEATMAP,
  toTimeSeriesPoints, toHeatmapCells,
} from "../mock/data";

const HEATMAP_ROWS = Array.from(new Set(HEATMAP.map((c) => c.dimension)));
const HEATMAP_COLS = Array.from(new Set(HEATMAP.map((c) => c.group)));

export function Quality() {
  return (
    <div data-testid="quality-page">
      <div className="main__header">
        <h1 className="main__title">Qualité</h1>
        <p className="main__subtitle">Taux d accord et confiance du copilote</p>
      </div>

      <div className="grid-kpi" style={{ gridTemplateColumns: "repeat(3, 1fr)" }}>
        {GAUGES.map((g) => (
          <div className="card" key={g.label}>
            <Gauge
              label={g.label}
              value={g.value}
              unit="%"
              minSampleSize={42}
              k={5}
            />
          </div>
        ))}
      </div>

      <div className="card" style={{ marginBottom: 24 }}>
        <h2 className="card__title">Temps médian — 14 jours</h2>
        <TimeSeries
          label="Temps médian — 14 jours"
          points={toTimeSeriesPoints(TIMESERIES)}
          unit="min"
          minSampleSize={42}
          k={5}
        />
      </div>

      <div className="card">
        <h2 className="card__title">Détail par dimension</h2>
        <Heatmap
          label="Détail par dimension"
          rows={HEATMAP_ROWS}
          cols={HEATMAP_COLS}
          cells={toHeatmapCells(HEATMAP)}
          k={5}
        />
      </div>
    </div>
  );
}
