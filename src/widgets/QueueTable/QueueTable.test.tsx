import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { QueueTable } from './QueueTable';
import type { QueueRow } from '../../mock/data';

describe('QueueTable', () => {
  it('renders empty state when no rows', () => {
    render(<QueueTable rows={[]} />);
    expect(screen.getByTestId('queue-table')).toHaveTextContent(/file vide/i);
  });

  it('renders all rows', () => {
    const rows: QueueRow[] = [
      { id: 'C-1', site: 'FR', score: 87, status: 'pending', waiting: '2 h' },
      { id: 'C-2', site: 'PT', score: 74, status: 'review',  waiting: '4 h' },
      { id: 'C-3', site: 'FR', score: 91, status: 'done',    waiting: '—' },
    ];
    render(<QueueTable rows={rows} />);
    expect(screen.getByText('C-1')).toBeInTheDocument();
    expect(screen.getByText('C-2')).toBeInTheDocument();
    expect(screen.getByText('C-3')).toBeInTheDocument();
  });

  it('shows FR / PT sites', () => {
    render(<QueueTable rows={[
      { id: 'C-1', site: 'FR', score: 87, status: 'pending', waiting: '2 h' },
      { id: 'C-2', site: 'PT', score: 74, status: 'review',  waiting: '4 h' },
    ]} />);
    expect(screen.getByText('FR')).toBeInTheDocument();
    expect(screen.getByText('PT')).toBeInTheDocument();
  });

  it('labels statuses correctly', () => {
    render(<QueueTable rows={[
      { id: 'C-1', site: 'FR', score: 87, status: 'pending', waiting: '2 h' },
      { id: 'C-2', site: 'PT', score: 74, status: 'review',  waiting: '4 h' },
      { id: 'C-3', site: 'FR', score: 91, status: 'done',    waiting: '—' },
    ]} />);
    expect(screen.getByText('En attente')).toBeInTheDocument();
    expect(screen.getByText('À revoir')).toBeInTheDocument();
    expect(screen.getByText('Traité')).toBeInTheDocument();
  });

  it('exposes data-testid=queue-table', () => {
    render(<QueueTable rows={[
      { id: 'C-1', site: 'FR', score: 87, status: 'pending', waiting: '2 h' },
    ]} />);
    expect(screen.getByTestId('queue-table')).toBeInTheDocument();
  });
});
