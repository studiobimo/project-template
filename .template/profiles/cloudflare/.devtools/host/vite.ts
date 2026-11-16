import { fileURLToPath } from 'node:url'

import { cloudflare } from '@cloudflare/vite-plugin'
import type { UserConfig } from 'vite'

const sharedState = fileURLToPath(new URL('../../.dev-state', import.meta.url))

export default (): UserConfig => ({
  plugins: [cloudflare({ persistState: { path: sharedState } })]
})
