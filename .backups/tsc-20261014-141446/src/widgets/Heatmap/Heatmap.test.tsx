import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { Heatmap } from './Heatmap';

describe('Heatmap', () => {
  it('renders', () => {
    render(<Heatmap cells={[]} />);
    expect(screen.getByTestId('heatmap')).toBeInTheDocument();
  });
});
