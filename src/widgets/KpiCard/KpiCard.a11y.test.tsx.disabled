import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { axe, toHaveNoViolations } from 'jest-axe';
import { KpiCard } from './KpiCard';

expect.extend(toHaveNoViolations);

describe('KpiCard — a11y', () => {
  it('has no axe violations (minimal)', async () => {
    const { container } = render(<KpiCard label="x" value={1} />);
    expect(await axe(container)).toHaveNoViolations();
  });

  it('has no axe violations (full)', async () => {
    const { container } = render(
      <KpiCard
        label="Median handling time"
        value={8.4}
        unit="min"
        baseline={18}
        target={4}
        status="watch"
        lastRefresh="2026-10-11T08:00:00Z"
        href="/definitions/median"
      />
    );
    expect(await axe(container)).toHaveNoViolations();
  });

  it('has an aria-label on the article', () => {
    render(<KpiCard label="Median handling time" value={8.4} unit="min" />);
    expect(screen.getByRole('article')).toHaveAttribute(
      'aria-label',
      'Median handling time: 8.4 min'
    );
  });

  it('definition link has explicit aria-label', () => {
    render(<KpiCard label="Median" value={1} href="/d" />);
    const link = screen.getByRole('link');
    expect(link).toHaveAttribute('aria-label', 'Voir la définition de Median');
  });
});
