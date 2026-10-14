import js from '@eslint/js';
import tseslint from 'typescript-eslint';
import react from 'eslint-plugin-react';
import reactHooks from 'eslint-plugin-react-hooks';

export default tseslint.config(
  {
    ignores: [
    '.backups/**',
      'venv/**',              // ← AJOUT
      '.pytest_cache/**',     // ← AJOUT
      'dist/**',
      'coverage/**',
      'node_modules/**',
      '.ci-reports/**',
      '.sync-worktrees/**',
      '.align-worktrees/**',
      'public/**',
      'workflows/**',
      '**/*.d.ts',
    ],
  },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ['**/*.{ts,tsx}'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
      parserOptions: { ecmaFeatures: { jsx: true } },
    },
    plugins: {
      react,
      'react-hooks': reactHooks,
    },
    settings: { react: { version: 'detect' } },
    rules: {
      ...react.configs.recommended.rules,
      ...reactHooks.configs.flat.recommended.rules,  // ← flat.recommended (v7.x)
      'react/react-in-jsx-scope': 'off',
      'react/prop-types': 'off',
       'react/no-unescaped-entities': 'off',
      'react-hooks/set-state-in-effect': 'off',          // ← AJOUT (ou corrige manuellement)
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
      '@typescript-eslint/no-empty-object-type': [
        'error',
        { allowInterfaces: 'with-single-extends' },
      ],
      'no-console': ['warn', { allow: ['warn', 'error'] }],
    },
  },
  {
    files: ['src/widgets/**/*.tsx', 'src/pages/**/*.tsx'],
    rules: {
      '@typescript-eslint/no-empty-object-type': 'off',
    },
  },
  {
    files: ['**/*.test.{ts,tsx}', '**/*.a11y.test.{ts,tsx}', 'vitest.setup.ts'],
    rules: { 'no-console': 'off' },
  },
  {
    files: ['scripts/**/*.{ts,js}'],       // ← AJOUT : autorise console.log dans scripts/
    rules: { 'no-console': 'off' },
  },
);