import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { Rubric } from './Rubric';

describe('Rubric', () => {
  it('renders', () => {
    render(<Rubric />);
    expect(screen.getByRole('heading', { level: 1 })).toBeInTheDocument();
  });
});
