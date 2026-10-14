import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { Quality } from './Quality';

describe('Quality', () => {
  it('renders', () => {
    render(<Quality />);
    expect(screen.getByTestId('quality-page')).toBeInTheDocument();
  });
});
