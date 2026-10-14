import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { axe, toHaveNoViolations } from 'jest-axe';
import { SmallGroupGuard } from './SmallGroupGuard';

expect.extend(toHaveNoViolations);

describe('SmallGroupGuard — a11y', () => {
  it('has no axe violations when rendering children', async () => {
    const { container } = render(
      <SmallGroupGuard n={10}>
        <p>aggregate content</p>
      </SmallGroupGuard>
    );
    expect(await axe(container)).toHaveNoViolations();
  });

  it('has no axe violations when rendering fallback', async () => {
    const { container } = render(
      <SmallGroupGuard n={2}>
        <p>hidden</p>
      </SmallGroupGuard>
    );
    expect(await axe(container)).toHaveNoViolations();
  });

  it('fallback is announced to screen readers via role=note', () => {
    render(<SmallGroupGuard n={1}>x</SmallGroupGuard>);
    const el = screen.getByRole('note');
    expect(el).toBeInTheDocument();
  });
});
