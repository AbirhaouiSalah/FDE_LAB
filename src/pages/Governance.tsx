import React from 'react';
import { RUBRIC_META } from '../mock/data';

export function Governance() {
  return (
    <>
      <div className="main__header">
        <h1 className="main__title">Governance</h1>
        <p className="main__subtitle">Conformité RGPD, EU AI Act, traçabilité</p>
      </div>

      <div className="card" style={{ marginBottom: 24 }}>
        <h2 className="card__title">Conformité</h2>
        <ul style={{ margin: 0, paddingLeft: 20, lineHeight: 1.9 }}>
          <li><strong>RGPD</strong> — aucune PII stockée ou affichée ; suppression des petits groupes (n&lt;5).</li>
          <li><strong>EU AI Act (Annexe III)</strong> — système d'aide à la décision, supervision humaine obligatoire.</li>
          <li><strong>Résidence EU</strong> — données hébergées en France et au Portugal.</li>
          <li><strong>Read-only</strong> — le dashboard ne prend aucune décision automatique.</li>
        </ul>
      </div>

      <div className="card">
        <h2 className="card__title">Rubric courante</h2>
        <dl style={{ display: 'grid', gridTemplateColumns: 'max-content 1fr', gap: '8px 24px', margin: 0 }}>
          <dt style={{ color: 'var(--color-text-muted)' }}>Version</dt><dd style={{ margin: 0, fontFamily: 'var(--font-mono)' }}>{RUBRIC_META.version}</dd>
          <dt style={{ color: 'var(--color-text-muted)' }}>Déployée le</dt><dd style={{ margin: 0 }}>{RUBRIC_META.deployedAt}</dd>
          <dt style={{ color: 'var(--color-text-muted)' }}>Sites</dt><dd style={{ margin: 0 }}>{RUBRIC_META.site}</dd>
          <dt style={{ color: 'var(--color-text-muted)' }}>Note</dt><dd style={{ margin: 0 }}>{RUBRIC_META.note}</dd>
        </dl>
      </div>
    </>
  );
}
