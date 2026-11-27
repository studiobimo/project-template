import { existsSync } from 'node:fs'

import react from '@vitejs/plugin-react'
import type { TestProjectInlineConfiguration } from 'vitest/config'

import { test } from '../typescript/vitest.ts'
import { hosting } from './vite.ts'

const setup = './src/test/setup.ts'

export const base: TestProjectInlineConfiguration = {
  resolve: { tsconfigPaths: true },
  plugins: [react()],
  test: {
    ...test,
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
