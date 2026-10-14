import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { SmallGroupGuard } from './SmallGroupGuard';

describe('SmallGroupGuard', () => {
  describe('rendering', () => {
    it('renders children when n >= threshold', () => {
      render(
        <SmallGroupGuard n={10}>
          <span>visible data</span>
        </SmallGroupGuard>
      );
      expect(screen.getByText('visible data')).toBeInTheDocument();
      expect(screen.queryByTestId('small-group-guard-fallback')).not.toBeInTheDocument();
    });

    it('renders fallback when n < threshold', () => {
      render(
        <SmallGroupGuard n={3}>
          <span>hidden data</span>
        </SmallGroupGuard>
      );
      expect(screen.queryByText('hidden data')).not.toBeInTheDocument();
      expect(screen.getByTestId('small-group-guard-fallback')).toBeInTheDocument();
      expect(screen.getByText('n<5')).toBeInTheDocument();
    });

    it('renders exactly at threshold (n === 5)', () => {
      render(
        <SmallGroupGuard n={5}>
          <span>visible data</span>
        </SmallGroupGuard>
      );
      expect(screen.getByText('visible data')).toBeInTheDocument();
    });

    it('renders custom fallback when provided', () => {
      render(
        <SmallGroupGuard n={2} fallback={<span>trop petit</span>}>
          <span>hidden</span>
        </SmallGroupGuard>
      );
      expect(screen.getByText('trop petit')).toBeInTheDocument();
    });

    it('uses custom threshold', () => {
      render(
        <SmallGroupGuard n={5} threshold={10}>
          <span>hidden</span>
        </SmallGroupGuard>
      );
      expect(screen.queryByText('hidden')).not.toBeInTheDocument();
      expect(screen.getByText('n<10')).toBeInTheDocument();
    });
  });

  describe('RGPD compliance', () => {
    it('never renders children when n < 5', () => {
      const { container } = render(
        <SmallGroupGuard n={4}>
          <span data-testid="pii">sensitive aggregate</span>
        </SmallGroupGuard>
      );
      expect(container.querySelector('[data-testid="pii"]')).toBeNull();
    });

    it('provides accessible label on fallback', () => {
      render(<SmallGroupGuard n={2} context="par site">x</SmallGroupGuard>);
      const el = screen.getByTestId('small-group-guard-fallback');
      expect(el).toHaveAttribute('role', 'note');
      expect(el.getAttribute('aria-label')).toContain('par site');
      expect(el.getAttribute('aria-label')).toContain('5');
    });

    it('hides the visual "n<5" text from screen readers (aria-hidden)', () => {
      render(<SmallGroupGuard n={1}>x</SmallGroupGuard>);
      const visual = screen.getByText('n<5');
      expect(visual).toHaveAttribute('aria-hidden', 'true');
    });
  });

  describe('edge cases', () => {
    it('handles n = 0', () => {
      render(<SmallGroupGuard n={0}>x</SmallGroupGuard>);
      expect(screen.getByTestId('small-group-guard-fallback')).toBeInTheDocument();
    });

    it('handles negative n', () => {
      render(<SmallGroupGuard n={-1}>x</SmallGroupGuard>);
      expect(screen.getByTestId('small-group-guard-fallback')).toBeInTheDocument();
    });
  });
});
