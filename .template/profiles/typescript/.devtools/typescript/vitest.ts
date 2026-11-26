import { defineConfig, type TestProjectInlineConfiguration } from 'vitest/config'

export const test: NonNullable<TestProjectInlineConfiguration['test']> = {
  include: ['src/**/*.test.{ts,tsx}'],
  restoreMocks: true
}

export const base = defineConfig({ test: { ...test, environment: 'node' } })

export default base
