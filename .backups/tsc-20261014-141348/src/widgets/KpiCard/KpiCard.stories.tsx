import type { Meta, StoryObj } from '@storybook/react';
import { KpiCard } from './KpiCard';

const meta: Meta<typeof KpiCard> = {
  title: 'Widgets/KpiCard',
  component: KpiCard,
  tags: ['autodocs'],
  argTypes: {
    status: { control: 'inline-radio', options: ['ok', 'watch', 'alert'] },
    unit:   { control: 'inline-radio', options: ['min', 'h', 'd', 'count', 'pct'] },
  },
};
export default meta;

type Story = StoryObj<typeof KpiCard>;

export const Default: Story = {
  args: { label: 'Median handling time', value: 8.4, unit: 'min' },
};

export const WithBaselineAndTarget: Story = {
  args: {
    label: 'Median handling time',
    value: 8.4,
    unit: 'min',
    baseline: 18,
    target: 4,
    status: 'ok',
    lastRefresh: '2026-10-11T08:00:00Z',
    href: '/definitions/median-handling-time',
  },
};

export const Watch: Story = {
  args: { label: 'Override rate', value: 12.5, unit: 'pct', status: 'watch' },
};

export const Alert: Story = {
  args: { label: 'Agreement rate', value: 62.1, unit: 'pct', status: 'alert' },
};

export const SmallGroupHidden: Story = {
  args: { label: 'Per-site median (Porto)', value: 9.2, unit: 'min', n: 3 },
};

export const Count: Story = {
  args: { label: 'Candidates screened', value: 12345, unit: 'count' },
};
