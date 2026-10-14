import { Gauge } from '../widgets/Gauge';
import { TimeSeries } from '../widgets/TimeSeries';
import { Heatmap } from '../widgets/Heatmap';
import { GAUGES, TIMESERIES, HEATMAP } from '../mock/data';

export function Quality() {
  return (
    <>
      <div className="main__header">
        <h1 className="main__title">Qualité</h1>
        <p className="main__subtitle">Taux d'accord et confiance du copilote</p>
      </div>

      <div className="grid-kpi" style={{ gridTemplateColumns: 'repeat(3, 1fr)' }}>
        {GAUGES.map(g => (
          <div className="card" key={g.label}><Gauge value={g.value} label={g.label} /></div>
        ))}
      </div>

      <div className="card" style={{ marginBottom: 24 }}>
        <h2 className="card__title">Temps médian — 14 jours</h2>
        <TimeSeries data={TIMESERIES} yLabel="min" />
      </div>

      <div className="card">
        <h2 className="card__title">Détail par dimension</h2>
        <Heatmap cells={HEATMAP} />
      </div>
    </>
  );
}
