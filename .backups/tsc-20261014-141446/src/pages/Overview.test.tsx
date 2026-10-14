import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { Overview } from './Overview';

describe('Overview', () => {
  it('renders', () => {
    render(<Overview />);
    expect(screen.getByTestId('overview-page')).toBeInTheDocument();
  });
});
