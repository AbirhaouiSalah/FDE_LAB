import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { Queue } from './Queue';

describe('Queue', () => {
  it('renders', () => {
    render(<Queue />);
    expect(screen.getByRole('heading', { level: 1 })).toBeInTheDocument();
  });
});
