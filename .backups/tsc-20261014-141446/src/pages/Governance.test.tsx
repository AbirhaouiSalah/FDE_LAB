import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { Governance } from './Governance';

describe('Governance', () => {
  it('renders', () => {
    render(<Governance />);
    expect(screen.getByTestId('governance-page')).toBeInTheDocument();
  });
});
