import { defineConfig } from 'vitest/config'

export const base = defineConfig({
  test: {
    include: ['src/**/*.test.ts'],
    restoreMocks: true,
    environment: 'node'
  }
})

export default base
