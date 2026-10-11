import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { GovernancePage } from './Governance';

describe('GovernancePage', () => {
  it('renders', () => {
    render(<GovernancePage />);
    expect(screen.getByTestId('governance-page')).toBeInTheDocument();
  });
});
