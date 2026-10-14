import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],

  // Config Vite dev server — exclut les worktrees temporaires du watch
  server: {
    watch: {
      ignored: [
        '**/.push-worktrees/**',
        '**/.backups/**',
        '**/.ci-reports/**',
        '**/.sync-worktrees/**',
        '**/.align-worktrees/**',
        '**/node_modules/**',
        '**/dist/**',
        '**/dist-demo/**',
        '**/coverage/**',
        '**/venv/**',
        '**/.pytest_cache/**',
      ],
    },
  },

  // Config Vitest (tests unitaires + intégration)
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./vitest.setup.ts'],
    include: ['src/**/*.{test,spec}.{ts,tsx}'],
    exclude: [
      '**/node_modules/**',
      '**/dist/**',
      '**/.push-worktrees/**',
      '**/.backups/**',
    ],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json-summary', 'html'],
      exclude: [
        '**/*.test.tsx', '**/*.test.ts',
        '**/*.a11y.test.tsx',
        '**/*.stories.tsx',
        '**/index.ts',
        '**/*.d.ts',
        '**/.push-worktrees/**',
      ],
    },
  },
});