import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { Pipeline } from './Pipeline';

describe('Pipeline', () => {
  it('renders', () => {
    render(<Pipeline />);
    expect(screen.getByRole('heading', { level: 1 })).toBeInTheDocument();
  });
});
