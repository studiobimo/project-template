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
  globalIgnores(['src/routeTree.gen.ts']),
  {
    files: ['**/*.{ts,tsx}'],
    extends: [reactRefresh.configs.vite, pluginRouter.configs['flat/recommended']]
  },
  {
    files: ['src/**/*-provider.tsx', 'src/routes/**/*.tsx'],
    rules: { 'react-refresh/only-export-components': 'off' }
  },
  ...host
])
