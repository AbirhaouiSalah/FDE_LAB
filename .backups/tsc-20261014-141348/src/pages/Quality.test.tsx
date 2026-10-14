import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { QualityPage } from './Quality';

describe('QualityPage', () => {
  it('renders', () => {
    render(<QualityPage />);
    expect(screen.getByTestId('quality-page')).toBeInTheDocument();
  });
});
