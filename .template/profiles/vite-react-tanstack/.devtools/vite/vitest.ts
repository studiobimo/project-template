// Managed by studiobimo/project-template (profile vite-react-tanstack); change it there.
//
// The test projects: the React one, and whatever the hosting profile's
// .devtools/host/vitest.ts adds for its server code, each in its own environment.
// vitest.config.ts lists them with any of the project's own:
//
//   export default defineConfig({ test: { projects: await projects() } })
//
// `base` is the React setup (jsdom, Testing Library's matchers from src/test/setup.ts, the
// React plugin), and what every other workspace package runs on. `make test` runs a package
// with no vitest.config.ts on `base` as it is; one with a config of its own extends it and
// overrides what differs, say the environment of a package that is not React:
//
//   export default mergeConfig(base, defineConfig({ test: { environment: 'node' } }))
import { existsSync } from 'node:fs'

import react from '@vitejs/plugin-react'
import type { TestProjectInlineConfiguration } from 'vitest/config'

import { hosting } from './vite.ts'

const setup = './src/test/setup.ts'

export const base: TestProjectInlineConfiguration = {
  resolve: { tsconfigPaths: true },
  plugins: [react()],
  test: {
    include: ['src/**/*.test.{ts,tsx}'],
    restoreMocks: true,
    environment: 'jsdom',
    globals: true,
    setupFiles: existsSync(setup) ? [setup] : [],
    css: true
  }
}

export async function projects(): Promise<TestProjectInlineConfiguration[]> {
  return [client(), ...((await hosting<TestProjectInlineConfiguration[]>('vitest.ts')) ?? [])]
}

export function client(): TestProjectInlineConfiguration {
  return { ...base, test: { ...base.test, name: 'client' } }
}
