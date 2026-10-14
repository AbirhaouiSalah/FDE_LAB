import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { FairnessPage } from './Fairness';

describe('FairnessPage', () => {
  it('renders', () => {
    render(<FairnessPage />);
    expect(screen.getByTestId('fairness-page')).toBeInTheDocument();
  });
});
