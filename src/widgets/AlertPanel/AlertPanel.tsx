import type { Alert } from '../../mock/data';

const ICONS: Record<Alert['level'], string> = { info: 'ℹ', warn: '⚠', error: '✕' };

export function AlertPanel({ alerts }: { alerts: Alert[] }) {
  if (!alerts.length) {
    return (
      <div className="empty" style={{ minHeight: 120 }} data-testid="alert-panel">
        Aucune alerte
      </div>
    );
  }
  return (
    <div role="region" aria-label="Alertes" data-testid="alert-panel">
      {alerts.map(a => (
        <div key={a.id} className={`alert alert--${a.level}`} role={a.level === 'error' ? 'alert' : 'status'}>
          <span className="alert__icon" aria-hidden="true" style={{ fontSize: 16, lineHeight: '18px', textAlign: 'center' }}>{ICONS[a.level]}</span>
          <div className="alert__body">
            <p className="alert__title">{a.title}</p>
            <p className="alert__desc">{a.description}</p>
          </div>
        </div>
      ))}
    </div>
  );
}
