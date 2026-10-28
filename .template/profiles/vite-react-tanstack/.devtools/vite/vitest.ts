// Managed by studiobimo/project-template (profile vite-react-tanstack); change it there.
//
// The test projects: the React one, and whatever the hosting profile's
// .devtools/host/vitest.ts adds for its server code, each in its own environment.
// vitest.config.ts lists them with any of the project's own:
//
//   export default defineConfig({ test: { projects: await projects() } })
import react from '@vitejs/plugin-react'
import type { TestProjectInlineConfiguration } from 'vitest/config'

import { hosting } from './vite.ts'

export async function projects(): Promise<TestProjectInlineConfiguration[]> {
  return [client(), ...((await hosting<TestProjectInlineConfiguration[]>('vitest.ts')) ?? [])]
}

export function client(): TestProjectInlineConfiguration {
  return {
    plugins: [react()],
    resolve: { tsconfigPaths: true },
    test: {
      name: 'client',
      environment: 'jsdom',
      globals: true,
      setupFiles: ['./src/test/setup.ts'],
      include: ['src/**/*.test.{ts,tsx}'],
      css: true,
      restoreMocks: true
    }
  }
}
