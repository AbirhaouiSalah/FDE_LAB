import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { KpiCard, formatValue, deltaPct } from './KpiCard';

describe('KpiCard — formatValue', () => {
  it('formats pct', () => expect(formatValue(12.345, 'pct')).toBe('12.3 %'));
  it('formats min', () => expect(formatValue(8.4, 'min')).toBe('8.4 min'));
  it('formats h',   () => expect(formatValue(2.5, 'h')).toBe('2.5 h'));
  it('formats d',   () => expect(formatValue(1.5, 'd')).toBe('1.5 j'));
  it('formats count with fr-FR locale', () =>
    expect(formatValue(12345, 'count')).toBe('12 345'));
  it('returns raw string when unit undefined', () =>
    expect(formatValue(42)).toBe('42'));
});

describe('KpiCard — deltaPct', () => {
  it('returns null when baseline undefined', () =>
    expect(deltaPct(10, undefined)).toBeNull());
  it('returns null when baseline = 0', () =>
    expect(deltaPct(10, 0)).toBeNull());
  it('computes positive delta', () =>
    expect(deltaPct(15, 10)).toBeCloseTo(50));
  it('computes negative delta', () =>
    expect(deltaPct(8.4, 18)).toBeCloseTo(-53.333, 2));
});

describe('KpiCard — rendering', () => {
  it('renders label and formatted value', () => {
    render(<KpiCard label="Median handling time" value={8.4} unit="min" />);
    expect(screen.getByText('Median handling time')).toBeInTheDocument();
    expect(screen.getByText('8.4 min')).toBeInTheDocument();
  });

  it('renders delta when baseline provided', () => {
    render(<KpiCard label="x" value={8.4} unit="min" baseline={18} />);
    expect(screen.getByTestId('kpi-card-delta')).toHaveTextContent('-53.3 %');
  });

  it('omits delta when baseline is 0', () => {
    render(<KpiCard label="x" value={1} baseline={0} />);
    expect(screen.queryByTestId('kpi-card-delta')).not.toBeInTheDocument();
  });

  it('renders target when provided', () => {
    render(<KpiCard label="x" value={8.4} unit="min" target={4} />);
    expect(screen.getByTestId('kpi-card-target')).toHaveTextContent('Cible : 4.0 min');
  });

  it('renders lastRefresh when provided', () => {
    render(<KpiCard label="x" value={1} lastRefresh="2026-10-11T08:00:00Z" />);
    expect(screen.getByText(/Dernière mise à jour/)).toBeInTheDocument();
  });

  it('renders definition link when href provided', () => {
    render(<KpiCard label="x" value={1} href="/definitions/x" />);
    const link = screen.getByRole('link', { name: /Voir la définition de x/ });
    expect(link).toHaveAttribute('href', '/definitions/x');
  });
});

describe('KpiCard — status', () => {
  it('sets data-status to ok by default', () => {
    render(<KpiCard label="x" value={1} />);
    expect(screen.getByTestId('kpi-card')).toHaveAttribute('data-status', 'ok');
  });
  it('sets data-status to watch', () => {
    render(<KpiCard label="x" value={1} status="watch" />);
    expect(screen.getByTestId('kpi-card')).toHaveAttribute('data-status', 'watch');
  });
  it('sets data-status to alert', () => {
    render(<KpiCard label="x" value={1} status="alert" />);
    expect(screen.getByTestId('kpi-card')).toHaveAttribute('data-status', 'alert');
  });
});

describe('KpiCard — RGPD compliance', () => {
  it('hides the card when n < 5', () => {
    render(<KpiCard label="x" value={42} n={3} />);
    expect(screen.queryByTestId('kpi-card')).not.toBeInTheDocument();
    expect(screen.getByTestId('small-group-guard-fallback')).toBeInTheDocument();
  });

  it('shows the card when n >= 5', () => {
    render(<KpiCard label="x" value={42} n={5} />);
    expect(screen.getByTestId('kpi-card')).toBeInTheDocument();
  });

  it('shows the card when n is undefined (no group info)', () => {
    render(<KpiCard label="x" value={42} />);
    expect(screen.getByTestId('kpi-card')).toBeInTheDocument();
  });
});
