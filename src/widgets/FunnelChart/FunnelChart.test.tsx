import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { FunnelChart } from './FunnelChart';

describe('FunnelChart', () => {
  it('renders empty state when no stages', () => {
    render(<FunnelChart stages={[]} />);
    expect(screen.getByTestId('funnel-chart')).toHaveTextContent(/aucune étape/i);
  });

  it('renders one row per stage', () => {
    render(<FunnelChart stages={[
      { label: 'Sourced', value: 1000 },
      { label: 'Screened', value: 500 },
      { label: 'Offer', value: 50 },
    ]} />);
    expect(screen.getByText('Sourced')).toBeInTheDocument();
    expect(screen.getByText('Screened')).toBeInTheDocument();
    expect(screen.getByText('Offer')).toBeInTheDocument();
  });

  it('shows the raw value formatted in fr-FR', () => {
    render(<FunnelChart stages={[{ label: 'Sourced', value: 1240 }]} />);
    // 1 240 avec espace fine insécable
    expect(screen.getByText(/1\s*240/)).toBeInTheDocument();
  });

  it('shows conversion percentage for non-first stages', () => {
    render(<FunnelChart stages={[
      { label: 'Sourced', value: 1000 },
      { label: 'Screened', value: 500 },
    ]} />);
    // 500/1000 = 50 %
    expect(screen.getByText(/50\s*%/)).toBeInTheDocument();
  });

  it('shows em dash for the first stage (no conversion)', () => {
    render(<FunnelChart stages={[{ label: 'Sourced', value: 1000 }]} />);
    expect(screen.getByText('—')).toBeInTheDocument();
  });
});
