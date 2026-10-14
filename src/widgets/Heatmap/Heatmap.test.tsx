import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { Heatmap } from './Heatmap';
import type { HeatCell } from '../../mock/data';

describe('Heatmap', () => {
  const cells: HeatCell[] = [
    { dimension: 'Site', group: 'FR', value: 8.4, n: 220 },
    { dimension: 'Site', group: 'PT', value: 9.2, n: 122 },
    { dimension: 'Cohorte', group: 'Junior', value: 9.6, n: 154 },
    { dimension: 'Cohorte', group: 'Stage', value: 10.2, n: 42 },
  ];

  it('renders a table with aria-label', () => {
    render(<Heatmap cells={cells} />);
    expect(screen.getByRole('table', { name: /heatmap/i })).toBeInTheDocument();
  });

  it('exposes data-testid=heatmap', () => {
    render(<Heatmap cells={cells} />);
    expect(screen.getByTestId('heatmap')).toBeInTheDocument();
  });

  it('renders one row per dimension', () => {
    render(<Heatmap cells={cells} />);
    expect(screen.getByText('Site')).toBeInTheDocument();
    expect(screen.getByText('Cohorte')).toBeInTheDocument();
  });

  it('renders the value inside each cell', () => {
    render(<Heatmap cells={cells} />);
    expect(screen.getByText('8.4')).toBeInTheDocument();
    expect(screen.getByText('9.2')).toBeInTheDocument();
  });

  it('masks cells with n < 5 with n<5', () => {
    const small: HeatCell[] = [
      { dimension: 'Site', group: 'FR', value: 8.4, n: 3 },
    ];
    render(<Heatmap cells={small} />);
    expect(screen.getByText('n<5')).toBeInTheDocument();
  });
});
