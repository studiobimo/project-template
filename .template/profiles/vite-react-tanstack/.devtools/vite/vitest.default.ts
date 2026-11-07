// Managed by studiobimo/project-template (profile vite-react-tanstack); change it there.
//
// What `make test` runs a workspace package on when it has no vitest.config.ts: `base`.
import { defineConfig, mergeConfig } from 'vitest/config'

import { base } from './vitest.ts'

export default mergeConfig(base, defineConfig({}))
