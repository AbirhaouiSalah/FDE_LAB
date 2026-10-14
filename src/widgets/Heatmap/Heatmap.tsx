import React from 'react';
import type { HeatCell } from '../../mock/data';

function colorFor(v: number, min: number, max: number) {
  const t = (v - min) / (max - min || 1);
  // Interpole entre ok (vert) et alert (rouge)
  const r = Math.round(16 + t * (239 - 16));
  const g = Math.round(185 + t * (68 - 185));
  const b = Math.round(129 + t * (68 - 129));
  return `rgb(${r},${g},${b})`;
}

export function Heatmap({ cells }: { cells: HeatCell[] }) {
  const dims = Array.from(new Set(cells.map(c => c.dimension)));
  const groups = Array.from(new Set(cells.map(c => c.group)));
  const values = cells.map(c => c.value);
  const min = Math.min(...values), max = Math.max(...values);

  return (
    <table className="heat" aria-label="Heatmap par dimension">
      <thead>
        <tr>
          <th style={{ textAlign: 'left' }}>Dimension</th>
          {groups.map(g => <th key={g}>{g}</th>)}
        </tr>
      </thead>
      <tbody>
        {dims.map(d => (
          <tr key={d}>
            <th style={{ textAlign: 'left', paddingRight: 12 }}>{d}</th>
            {groups.map(g => {
              const cell = cells.find(c => c.dimension === d && c.group === g);
              if (!cell) return <td key={g}><div className="heat__cell" style={{ background: 'var(--color-surface-2)', color: 'var(--color-text-subtle)' }}>—</div></td>;
              if (cell.n < 5) return (
                <td key={g}>
                  <div className="heat__cell" style={{ background: 'var(--color-surface-2)', color: 'var(--color-text-subtle)' }} title="Agrégat masqué (n<5)">n&lt;5</div>
                </td>
              );
              return (
                <td key={g}>
                  <div className="heat__cell" style={{ background: colorFor(cell.value, min, max) }} title={`n=${cell.n}`}>{cell.value.toFixed(1)}</div>
                </td>
              );
            })}
          </tr>
        ))}
      </tbody>
    </table>
  );
}
