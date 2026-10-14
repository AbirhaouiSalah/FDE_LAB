import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { QueueTable } from './QueueTable';
import type { QueueRow } from '../../mock/data';

const ROWS: QueueRow[] = [
  { id: 'c-a1b2', site: 'FR', score: 82, status: 'pending', waiting: '2h' },
  { id: 'c-c3d4', site: 'PT', score: 45, status: 'review',  waiting: '1d' }
];

describe('QueueTable', () => {
  it('renders with data-testid', () => {
    render(<QueueTable rows={ROWS} />);
    expect(screen.getByTestId('queue-table')).toBeInTheDocument();
  });

  it('renders one row per candidate', () => {
    render(<QueueTable rows={ROWS} />);
    const rows = screen.getAllByRole('row');
    // 1 header + 2 rows = 3
    expect(rows.length).toBe(3);
  });

  it('affiche l\'id anonymisé', () => {
    render(<QueueTable rows={ROWS} />);
    expect(screen.getByText('c-a1b2')).toBeInTheDocument();
    expect(screen.getByText('c-c3d4')).toBeInTheDocument();
  });

  it('n\'affiche jamais de nom réel (RGPD)', () => {
    render(<QueueTable rows={ROWS} />);
    const html = document.body.innerHTML;
    // Regex heuristique : un vrai nom ressemblerait à "Jean Dupont"
    expect(html).not.toMatch(/\b[A-Z][a-z]+\s+[A-Z][a-z]+\b/);
  });

  it('renders empty state gracefully', () => {
    render(<QueueTable rows={[]} />);
    expect(screen.getByTestId('queue-table')).toBeInTheDocument();
  });

  it('affiche le site correctement', () => {
    render(<QueueTable rows={ROWS} />);
    expect(screen.getByText('FR')).toBeInTheDocument();
    expect(screen.getByText('PT')).toBeInTheDocument();
  });
});
