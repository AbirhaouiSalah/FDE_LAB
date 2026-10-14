import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { Fairness } from './Fairness';

describe('Fairness', () => {
  it('renders', () => {
    render(<Fairness />);
    expect(screen.getByRole('heading', { level: 1 })).toBeInTheDocument();
  });
});
