import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { Operations } from './Operations';

describe('Operations', () => {
  it('renders', () => {
    render(<Operations />);
    expect(screen.getByTestId('operations-page')).toBeInTheDocument();
  });
});
