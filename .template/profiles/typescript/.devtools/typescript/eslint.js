import js from '@eslint/js'
import { defineConfig, globalIgnores } from 'eslint/config'
import globals from 'globals'
import tseslint from 'typescript-eslint'

export const base = defineConfig([
  globalIgnores(['**/dist', '**/coverage', '**/.turbo']),
  {
    files: ['**/*.{ts,tsx,mts}'],
    extends: [js.configs.recommended, tseslint.configs.recommended]
  },
  {
    files: ['**/*.{js,mjs,cjs}'],
    extends: [js.configs.recommended],
    languageOptions: { globals: globals.node }
  }
])

export const node = defineConfig([
  base,
  {
    files: ['**/*.{ts,tsx,mts}'],
    languageOptions: { globals: globals.node }
  }
])
