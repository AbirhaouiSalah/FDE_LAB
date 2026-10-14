import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { TimeSeries } from './TimeSeries';

describe('TimeSeries', () => {
  it('renders', () => {
    render(<TimeSeries data={[]} />);
    expect(document.body.textContent).not.toBe('');
  });
});
