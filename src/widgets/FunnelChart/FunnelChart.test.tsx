import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { FunnelChart } from './FunnelChart';

describe('FunnelChart', () => {
  it('renders', () => {
    render(<FunnelChart />);
    expect(screen.getByTestId('funnel-chart')).toBeInTheDocument();
  });
});
