import { AlertPanel } from "../widgets/AlertPanel";
import { Gauge } from "../widgets/Gauge";
import { ALERTS, GAUGES } from "../mock/data";

export function Operations() {
  return (
    <div data-testid="operations-page">
      <div className="main__header">
        <h1 className="main__title">Operations</h1>
        <p className="main__subtitle">
          Supervision MCO — alertes et santé du service
        </p>
      </div>

      <div className="grid-2">
        <div className="card">
          <h2 className="card__title">Alertes actives</h2>
          <div style={{ display: "grid", gap: 12 }}>
            {ALERTS.map((a) => (
              <AlertPanel key={a.id} level={a.level} title={a.title}>
                {a.description}
              </AlertPanel>
            ))}
          </div>
        </div>
        <div className="card">
          <h2 className="card__title">Santé</h2>
          <div
            style={{ display: "flex", flexDirection: "column", gap: 16 }}
          >
            {GAUGES.slice(0, 2).map((g) => (
              <Gauge key={g.label} value={g.value} label={g.label} />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
