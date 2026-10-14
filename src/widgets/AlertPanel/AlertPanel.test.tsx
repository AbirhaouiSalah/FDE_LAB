import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { AlertPanel } from './AlertPanel';
import type { Alert } from '../../mock/data';

describe('AlertPanel', () => {
  it('renders empty state when no alerts', () => {
    render(<AlertPanel alerts={[]} />);
    expect(screen.getByTestId('alert-panel')).toHaveTextContent(/aucune alerte/i);
  });

  it('renders all alerts with title and description', () => {
    const alerts: Alert[] = [
      { id: '1', level: 'warn', title: 'Alerte A', description: 'Description A' },
      { id: '2', level: 'info', title: 'Alerte B', description: 'Description B' },
    ];
    render(<AlertPanel alerts={alerts} />);
    expect(screen.getByText('Alerte A')).toBeInTheDocument();
    expect(screen.getByText('Alerte B')).toBeInTheDocument();
    expect(screen.getByText('Description A')).toBeInTheDocument();
    expect(screen.getByText('Description B')).toBeInTheDocument();
  });

  it('assigns role=alert to error-level alerts', () => {
    const alerts: Alert[] = [
      { id: '1', level: 'error', title: 'Erreur', description: 'Détail' },
    ];
    render(<AlertPanel alerts={alerts} />);
    expect(screen.getByRole('alert')).toBeInTheDocument();
  });

  it('assigns role=status to non-error alerts', () => {
    const alerts: Alert[] = [
      { id: '1', level: 'warn', title: 'Warn', description: 'Détail' },
    ];
    render(<AlertPanel alerts={alerts} />);
    expect(screen.getByRole('status')).toBeInTheDocument();
  });

  it('exposes region with aria-label', () => {
    const alerts: Alert[] = [
      { id: '1', level: 'info', title: 'Info', description: 'Détail' },
    ];
    render(<AlertPanel alerts={alerts} />);
    expect(screen.getByRole('region', { name: /alertes/i })).toBeInTheDocument();
  });
});
