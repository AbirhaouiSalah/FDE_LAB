import React from 'react';
import type { QueueRow } from '../../mock/data';

const STATUS_LABEL: Record<QueueRow['status'], { label: string; cls: string }> = {
  pending: { label: 'En attente', cls: 'pill--watch' },
  review:  { label: 'À revoir',   cls: 'pill--alert' },
  done:    { label: 'Traité',     cls: 'pill--ok' },
};

export function QueueTable({ rows }: { rows: QueueRow[] }) {
  if (!rows.length) return <div className="empty">File vide</div>;
  return (
    <table className="queue">
      <thead>
        <tr>
          <th>ID</th>
          <th>Site</th>
          <th>Score</th>
          <th>Statut</th>
          <th>Attente</th>
        </tr>
      </thead>
      <tbody>
        {rows.map(r => {
          const st = STATUS_LABEL[r.status];
          return (
            <tr key={r.id}>
              <td className="queue__id">{r.id}</td>
              <td>{r.site}</td>
              <td className="queue__score">{r.score}</td>
              <td><span className={`pill ${st.cls}`}>{st.label}</span></td>
              <td>{r.waiting}</td>
            </tr>
          );
        })}
      </tbody>
    </table>
  );
}
