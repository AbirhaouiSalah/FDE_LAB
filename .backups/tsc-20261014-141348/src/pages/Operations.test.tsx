import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { OperationsPage } from './Operations';

describe('OperationsPage', () => {
  it('renders', () => {
    render(<OperationsPage />);
    expect(screen.getByTestId('operations-page')).toBeInTheDocument();
  });
});
