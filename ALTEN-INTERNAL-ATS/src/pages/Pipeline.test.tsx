import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { PipelinePage } from './Pipeline';

describe('PipelinePage', () => {
  it('renders', () => {
    render(<PipelinePage />);
    expect(screen.getByTestId('pipeline-page')).toBeInTheDocument();
  });
});
