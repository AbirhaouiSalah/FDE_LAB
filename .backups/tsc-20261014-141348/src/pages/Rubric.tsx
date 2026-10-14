import React from 'react';
import { RUBRIC_META } from '../mock/data';

const CRITERIA = [
  { name: 'Compétences techniques', weight: 30, desc: 'Adéquation avec la stack FDE (Python, data, cloud).' },
  { name: 'Expérience client',     weight: 25, desc: 'Capacité à intervenir chez le client, communication.' },
  { name: 'Autonomie',             weight: 20, desc: 'Capacité à mener un projet de bout en bout.' },
  { name: 'Anglais professionnel', weight: 15, desc: 'Niveau requis pour interventions internationales.' },
  { name: 'Mobilité',              weight: 10, desc: 'Disponibilité France / Porto.' },
];

export function Rubric() {
  return (
    <>
      <div className="main__header">
        <h1 className="main__title">Rubric {RUBRIC_META.version}</h1>
        <p className="main__subtitle">Critères utilisés par le copilote — le recruteur garde la décision finale</p>
      </div>

      <div className="card">
        <h2 className="card__title">Critères</h2>
        <table className="queue">
          <thead><tr><th>Critère</th><th>Poids</th><th>Description</th></tr></thead>
          <tbody>
            {CRITERIA.map(c => (
              <tr key={c.name}>
                <td style={{ fontWeight: 600 }}>{c.name}</td>
                <td className="queue__score">{c.weight} %</td>
                <td style={{ color: 'var(--color-text-muted)' }}>{c.desc}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
