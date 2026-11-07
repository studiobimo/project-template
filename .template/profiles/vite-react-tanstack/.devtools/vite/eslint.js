// Managed by studiobimo/project-template (profile vite-react-tanstack); change it there.
//
// The shared ESLint rules in layers, each extending the one before. eslint.config.js picks
// one and adds the project's own:
//
//   export default defineConfig([app, { files: ['src/**/*.tsx'], rules: { ... } }])
//
//   base   TypeScript and Node scripts: the root's config, for what no package covers
//   react  base, and what any React package needs: hooks, accessibility, strings in catalogs
//   app    react, and what only the Vite app has: Fast Refresh, the router, the host's rules
//
// Every workspace package extends `react` from an eslint.config.js of its own, as the app
// extends `app`: ESLint uses the nearest one to each file. A package that is not React, or is
// exempt from a rule, turns that rule off in its own config, where it can be seen.
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

export const base = defineConfig([
  globalIgnores(['dist', 'coverage']),
  {
    files: ['**/*.{ts,tsx}'],
    extends: [js.configs.recommended, tseslint.configs.recommended]
  },
  {
    files: ['**/*.{js,mjs}', '*.config.ts', '.devtools/**/*.ts'],
    extends: [js.configs.recommended],
    languageOptions: { globals: globals.node }
  }
])

export const react = defineConfig([
  base,
  // Vendored: a fix would not survive the next `shadcn add`.
  globalIgnores(['src/components/ui']),
  {
    files: ['**/*.{ts,tsx}'],
    extends: [reactHooks.configs.flat.recommended, pluginQuery.configs['flat/recommended']],
    languageOptions: { globals: globals.browser }
  },
  {
    files: ['src/**/*.tsx'],
    extends: [jsxA11y.flatConfigs.recommended]
  },
  {
    // Every string a person reads comes from src/locales/ through t(), whether or not the
    // app is translated yet: text in JSX, and the attributes that are read or announced.
    files: ['src/**/*.tsx'],
    ignores: ['src/**/*.test.tsx'],
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
  }
])

export const app = defineConfig([
  react,
  // Generated: a fix would not survive the next build.
  globalIgnores(['src/routeTree.gen.ts']),
  {
    files: ['**/*.{ts,tsx}'],
    extends: [reactRefresh.configs.vite, pluginRouter.configs['flat/recommended']]
  },
  {
    // Providers export their use* hook and route files their Route: neither breaks Fast Refresh.
    files: ['src/**/*-provider.tsx', 'src/routes/**/*.tsx'],
    rules: { 'react-refresh/only-export-components': 'off' }
  },
  ...host
])
