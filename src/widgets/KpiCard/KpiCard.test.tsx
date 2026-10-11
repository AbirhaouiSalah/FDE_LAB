import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { KpiCard } from './KpiCard';

describe('KpiCard', () => {
  it('renders', () => {
    render(<KpiCard />);
    expect(screen.getByTestId('kpi-card')).toBeInTheDocument();
  });
});
