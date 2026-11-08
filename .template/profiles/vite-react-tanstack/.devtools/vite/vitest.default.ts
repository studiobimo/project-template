import { defineConfig, mergeConfig } from 'vitest/config'

import { base } from './vitest.ts'

export default mergeConfig(base, defineConfig({}))
