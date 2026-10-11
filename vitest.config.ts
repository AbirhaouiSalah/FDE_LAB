import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./vitest.setup.ts'],
    include: ['src/**/*.{test,spec}.{ts,tsx}'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json-summary', 'html'],
      exclude: [
        '**/*.test.tsx', '**/*.test.ts',
        '**/*.a11y.test.tsx',
        '**/*.stories.tsx',
        '**/index.ts',
        '**/*.d.ts',
      ],
    },
  },
});
