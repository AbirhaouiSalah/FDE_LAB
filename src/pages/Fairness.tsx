import { Heatmap } from '../widgets/Heatmap';
import { SmallGroupGuard } from '../widgets/SmallGroupGuard';
import { HEATMAP } from '../mock/data';

export function Fairness() {
  return (
    <>
      <div className="main__header">
        <h1 className="main__title">Fairness</h1>
        <p className="main__subtitle">Écarts par dimension — les petits groupes (n&lt;5) sont masqués</p>
      </div>

      <div className="card" style={{ marginBottom: 24 }}>
        <h2 className="card__title">Heatmap par dimension</h2>
        <Heatmap cells={HEATMAP} />
      </div>

      <div className="card">
        <h2 className="card__title">Démonstration SmallGroupGuard</h2>
        <div style={{ display: 'flex', gap: 24, alignItems: 'center', flexWrap: 'wrap' }}>
          <div>
            <p style={{ fontSize: 12, color: 'var(--color-text-muted)', margin: '0 0 6px' }}>n = 42 (visible)</p>
            <SmallGroupGuard n={42} context="Fairness site FR">
              <span className="pill pill--ok">Agrégat affiché</span>
            </SmallGroupGuard>
          </div>
          <div>
            <p style={{ fontSize: 12, color: 'var(--color-text-muted)', margin: '0 0 6px' }}>n = 3 (masqué)</p>
            <SmallGroupGuard n={3} context="Fairness site PT">
              <span className="pill pill--ok">Ne devrait jamais s'afficher</span>
            </SmallGroupGuard>
          </div>
        </div>
      </div>
    </>
  );
}
