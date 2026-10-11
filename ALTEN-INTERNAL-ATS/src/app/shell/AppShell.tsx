import type { ReactNode } from 'react';
export interface AppShellProps { children: ReactNode }
export function AppShell({ children }: AppShellProps) {
  return <div data-testid="app-shell">{children}</div>;
}
