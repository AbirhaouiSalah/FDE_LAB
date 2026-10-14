import { QueueTable } from '../widgets/QueueTable';
import { QUEUE } from '../mock/data';

export function Queue() {
  return (
    <div data-testid="queue-page">
      <div className="main__header">
        <h1 className="main__title">Queue de pré-screening</h1>
        <p className="main__subtitle">{QUEUE.length} candidats · identifiants anonymisés · aucune PII</p>
      </div>
      <div className="card">
        <QueueTable rows={QUEUE} />
      </div>
    </div>
  );
}
