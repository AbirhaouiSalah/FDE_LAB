import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { AlertPanel } from './AlertPanel';

describe('AlertPanel', () => {
  it('renders', () => {
    render(<AlertPanel alerts={[]} />);
    expect(screen.getByTestId('alert-panel')).toBeInTheDocument();
  });
});
