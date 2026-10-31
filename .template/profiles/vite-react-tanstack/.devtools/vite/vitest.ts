// Managed by studiobimo/project-template (profile vite-react-tanstack); change it there.
//
// The test projects: the React one, and whatever the hosting profile's
// .devtools/host/vitest.ts adds for its server code, each in its own environment.
// vitest.config.ts lists them with any of the project's own:
//
//   export default defineConfig({ test: { projects: await projects() } })
//
// Any other workspace package has a vitest.config.ts of its own, on `base`, which `make test`
// runs too:
//
//   export default mergeConfig(base, defineConfig({ test: { environment: 'jsdom' } }))
import react from '@vitejs/plugin-react'
import type { TestProjectInlineConfiguration } from 'vitest/config'

import { hosting } from './vite.ts'

export const base: TestProjectInlineConfiguration = {
  resolve: { tsconfigPaths: true },
  test: {
    include: ['src/**/*.test.{ts,tsx}'],
    restoreMocks: true
  }
}

export async function projects(): Promise<TestProjectInlineConfiguration[]> {
  return [client(), ...((await hosting<TestProjectInlineConfiguration[]>('vitest.ts')) ?? [])]
}

export function client(): TestProjectInlineConfiguration {
  return {
    ...base,
    plugins: [react()],
    test: {
      ...base.test,
      name: 'client',
      environment: 'jsdom',
      globals: true,
      setupFiles: ['./src/test/setup.ts'],
      css: true
    }
  }
}
