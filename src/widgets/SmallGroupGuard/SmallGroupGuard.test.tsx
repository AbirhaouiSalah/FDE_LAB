import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { SmallGroupGuard } from './SmallGroupGuard';

describe('SmallGroupGuard', () => {
  it('renders', () => {
    render(<SmallGroupGuard />);
    expect(screen.getByTestId('small-group-guard')).toBeInTheDocument();
  });
});
