// Managed by studiobimo/project-template (profile vite-react-tanstack); change it there.
//
// The shared ESLint rules, with the hosting profile's from .devtools/host/eslint.js when
// there is one. eslint.config.js spreads them and adds the project's own:
//
//   export default defineConfig([app, { files: ['src/**/*.tsx'], rules: { ... } }])
import { existsSync } from 'node:fs'

import js from '@eslint/js'
import pluginQuery from '@tanstack/eslint-plugin-query'
import pluginRouter from '@tanstack/eslint-plugin-router'
import { defineConfig, globalIgnores } from 'eslint/config'
import i18next from 'eslint-plugin-i18next'
import jsxA11y from 'eslint-plugin-jsx-a11y'
import reactHooks from 'eslint-plugin-react-hooks'
import reactRefresh from 'eslint-plugin-react-refresh'
import globals from 'globals'
import tseslint from 'typescript-eslint'

const hostConfig = new URL('../host/eslint.js', import.meta.url)
const host = existsSync(hostConfig) ? (await import(hostConfig.href)).default : []

export const app = defineConfig([
  globalIgnores(['dist', 'coverage', 'src/routeTree.gen.ts']),
  {
    files: ['**/*.{ts,tsx}'],
    extends: [
      js.configs.recommended,
      tseslint.configs.recommended,
      reactHooks.configs.flat.recommended,
      reactRefresh.configs.vite,
      pluginQuery.configs['flat/recommended'],
      pluginRouter.configs['flat/recommended']
    ],
    languageOptions: { globals: globals.browser }
  },
  {
    // shadcn/ui primitives export their variants next to the component, providers their
    // use* hook, and route files their Route: none of that breaks Fast Refresh.
    files: ['src/components/ui/**/*.{ts,tsx}', 'src/**/*-provider.tsx', 'src/routes/**/*.tsx'],
    rules: { 'react-refresh/only-export-components': 'off' }
  },
  {
    // The shadcn/ui primitives carry their own accessibility semantics.
    files: ['src/**/*.tsx'],
    ignores: ['src/components/ui/**'],
    extends: [jsxA11y.flatConfigs.recommended]
  },
  {
    // Every string a person reads comes from src/locales/ through t(), whether or not the
    // app is translated yet: text in JSX, and the attributes that are read or announced.
    files: ['src/**/*.tsx'],
    ignores: ['src/components/ui/**', 'src/**/*.test.tsx'],
    plugins: { i18next },
    rules: {
      'i18next/no-literal-string': [
        'error',
        {
          mode: 'jsx-only',
          'jsx-attributes': {
            include: [
              'alt',
              'aria-description',
              'aria-label',
              'aria-placeholder',
              'aria-roledescription',
              'aria-valuetext',
              'label',
              'placeholder',
              'title'
            ]
          }
        }
      ]
    }
  },
  {
    files: ['**/*.{js,mjs}', '*.config.ts', '.devtools/**/*.ts'],
    extends: [js.configs.recommended],
    languageOptions: { globals: globals.node }
  },
  ...host
])
