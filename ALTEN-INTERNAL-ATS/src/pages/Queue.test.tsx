import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { QueuePage } from './Queue';

describe('QueuePage', () => {
  it('renders', () => {
    render(<QueuePage />);
    expect(screen.getByTestId('queue-page')).toBeInTheDocument();
  });
});
