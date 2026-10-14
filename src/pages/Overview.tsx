import { KpiCard } from "../widgets/KpiCard";
import { AlertPanel } from "../widgets/AlertPanel";
import { FunnelChart } from "../widgets/FunnelChart";
import { TimeSeries } from "../widgets/TimeSeries";
import { KPIS, ALERTS, FUNNEL, TIMESERIES, RUBRIC_META } from "../mock/data";

export function Overview() {
  return (
    <div data-testid="overview-page">
      <div className="main__header">
        <h1 className="main__title">Vue d ensemble</h1>
        <p className="main__subtitle">
          Rubric {RUBRIC_META.version} · Site FR + PT · Données fictives, aucune PII
        </p>
      </div>

      <div className="banner" role="note">
        <span aria-hidden="true">⚠</span>
        <span>
          Données fictives — aucune PII — usage démonstration.
          Le copilote propose, le recruteur décide.
        </span>
      </div>

      <div className="grid-kpi">
        {KPIS.map((k) => (
          <KpiCard
            key={k.id}
            label={k.label}
            value={k.value}
            sampleSize={k.n ?? undefined}
            k={5}
          />
        ))}
      </div>

      <div className="grid-2">
        <div className="card">
          <h2 className="card__title">Entonnoir de pré-screening</h2>
          <FunnelChart stages={FUNNEL} />
        </div>
        <div className="card">
          <h2 className="card__title">Alertes ({ALERTS.length})</h2>
          <div style={{ display: "grid", gap: 12 }}>
            {ALERTS.map((a) => (
              <AlertPanel key={a.id} level={a.level} title={a.title}>
                {a.description}
              </AlertPanel>
            ))}
          </div>
        </div>
      </div>

      <div className="card">
        <h2 className="card__title">
          Temps médian de pré-screening — 14 derniers jours
        </h2>
        <TimeSeries data={TIMESERIES} yLabel="min" />
      </div>
    </div>
  );
}
