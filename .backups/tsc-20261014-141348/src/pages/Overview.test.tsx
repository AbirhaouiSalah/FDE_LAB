import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { OverviewPage } from './Overview';

describe('OverviewPage', () => {
  it('renders', () => {
    render(<OverviewPage />);
    expect(screen.getByTestId('overview-page')).toBeInTheDocument();
  });
});
