import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { Gauge } from './Gauge';

describe('Gauge', () => {
  it('renders the label', () => {
    render(<Gauge value={88.5} label="Taux d'accord" />);
    expect(screen.getByText("Taux d'accord")).toBeInTheDocument();
  });

  it('formats the value with one decimal and %', () => {
    render(<Gauge value={88.456} label="x" />);
    expect(screen.getByText(/88\.5\s*%/)).toBeInTheDocument();
  });

  it('uses ok color for value >= 85', () => {
    const { container } = render(<Gauge value={90} label="x" />);
    const svg = container.querySelector('svg');
    expect(svg?.innerHTML).toContain('var(--color-ok)');
  });

  it('uses watch color for 70 <= value < 85', () => {
    const { container } = render(<Gauge value={75} label="x" />);
    const svg = container.querySelector('svg');
    expect(svg?.innerHTML).toContain('var(--color-watch)');
  });

  it('uses alert color for value < 70', () => {
    const { container } = render(<Gauge value={50} label="x" />);
    const svg = container.querySelector('svg');
    expect(svg?.innerHTML).toContain('var(--color-alert)');
  });

  it('clamps value to 0-100', () => {
    render(<Gauge value={150} label="x" />);
    expect(screen.getByText(/100\.0\s*%/)).toBeInTheDocument();
  });

  it('wraps in data-testid=gauge', () => {
    render(<Gauge value={50} label="x" />);
    expect(screen.getByTestId('gauge')).toBeInTheDocument();
  });
});
