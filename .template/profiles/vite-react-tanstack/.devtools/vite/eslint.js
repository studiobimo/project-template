import { existsSync } from 'node:fs'

import pluginQuery from '@tanstack/eslint-plugin-query'
import pluginRouter from '@tanstack/eslint-plugin-router'
import { defineConfig, globalIgnores } from 'eslint/config'
import i18next from 'eslint-plugin-i18next'
import jsxA11y from 'eslint-plugin-jsx-a11y'
import reactHooks from 'eslint-plugin-react-hooks'
import reactRefresh from 'eslint-plugin-react-refresh'
import globals from 'globals'

import { base as typescript } from '../typescript/eslint.js'

const hostConfig = new URL('../host/eslint.js', import.meta.url)
const host = existsSync(hostConfig) ? (await import(hostConfig.href)).default : []

export const base = defineConfig([
  typescript,
  {
    files: ['*.config.ts', '.devtools/**/*.ts'],
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
