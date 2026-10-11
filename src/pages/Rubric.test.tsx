import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { RubricPage } from './Rubric';

describe('RubricPage', () => {
  it('renders', () => {
    render(<RubricPage />);
    expect(screen.getByTestId('rubric-page')).toBeInTheDocument();
  });
});
