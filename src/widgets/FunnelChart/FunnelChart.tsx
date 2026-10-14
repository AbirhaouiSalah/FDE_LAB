export interface FunnelStage { label: string; value: number; }

export function FunnelChart({ stages }: { stages: FunnelStage[] }) {
  if (!stages.length) {
    return <div className="empty" data-testid="funnel-chart">Aucune étape</div>;
  }
  const max = stages[0].value;
  return (
    <div className="funnel" data-testid="funnel-chart">
      {stages.map((s, i) => {
        const pct = (s.value / max) * 100;
        const prev = i === 0 ? s.value : stages[i - 1].value;
        const conv = i === 0 ? 100 : (s.value / prev) * 100;
        return (
          <div className="funnel__stage" key={s.label}>
            <span className="funnel__label">{s.label}</span>
            <div className="funnel__bar-wrap">
              <div className="funnel__bar" style={{ width: `${pct}%` }}>
                {s.value.toLocaleString('fr-FR')}
              </div>
            </div>
            <span className="funnel__conversion">{i === 0 ? '—' : `${conv.toFixed(0)} %`}</span>
          </div>
        );
      })}
    </div>
  );
}
