import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { TimeSeries } from './TimeSeries';

describe('TimeSeries', () => {
  const data = [
    { day: 'J-2', fr: 9.8, pt: 12.4 },
    { day: 'J-1', fr: 8.4, pt: 9.5 },
    { day: 'J-0', fr: 8.4, pt: 9.2 },
  ];

  it('renders empty state when no data', () => {
    render(<TimeSeries data={[]} />);
    expect(screen.getByTestId('time-series')).toHaveTextContent(/aucune donnée/i);
  });

  it('renders the SVG with an aria-label', () => {
    render(<TimeSeries data={data} yLabel="min" />);
    expect(screen.getByRole('img', { name: /série temporelle/i })).toBeInTheDocument();
  });

  it('renders the legend with both sites', () => {
    render(<TimeSeries data={data} />);
    expect(screen.getByText('France')).toBeInTheDocument();
    expect(screen.getByText('Porto')).toBeInTheDocument();
  });

  it('exposes data-testid=time-series', () => {
    render(<TimeSeries data={data} />);
    expect(screen.getByTestId('time-series')).toBeInTheDocument();
  });

  it('shows the unit in the legend', () => {
    render(<TimeSeries data={data} yLabel="min" />);
    expect(screen.getByText(/unité :\s*min/i)).toBeInTheDocument();
  });
});
