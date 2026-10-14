import { FunnelChart } from "../widgets/FunnelChart";
import { TimeSeries } from "../widgets/TimeSeries";
import { FUNNEL, TIMESERIES, toFunnelStages, toTimeSeriesPoints } from "../mock/data";

export function Pipeline() {
  return (
    <div data-testid="pipeline-page">
      <div className="main__header">
        <h1 className="main__title">Pipeline</h1>
        <p className="main__subtitle">Entonnoir complet et évolution temporelle</p>
      </div>

      <div className="card" style={{ marginBottom: 24 }}>
        <h2 className="card__title">Entonnoir — 30 derniers jours</h2>
        <FunnelChart
          label="Entonnoir — 30 derniers jours"
          stages={toFunnelStages(FUNNEL)}
          minSampleSize={100}
          k={5}
        />
      </div>

      <div className="card">
        <h2 className="card__title">Temps médian par site — 14 jours</h2>
        <TimeSeries
          label="Temps médian par site"
          points={toTimeSeriesPoints(TIMESERIES)}
          unit="min"
          minSampleSize={42}
          k={5}
        />
      </div>
    </div>
  );
}
