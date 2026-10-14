import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { Gauge } from './Gauge';

describe('Gauge', () => {
  it('renders', () => {
    render(<Gauge value={0} label="test" />);
    expect(screen.getByTestId('gauge')).toBeInTheDocument();
  });
});
