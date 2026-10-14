import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { QueueTable } from './QueueTable';

describe('QueueTable', () => {
  it('renders', () => {
    render(<QueueTable rows={[]} />);
    expect(document.body.textContent).not.toBe('');
  });
});
