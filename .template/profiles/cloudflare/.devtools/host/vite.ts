// Managed by studiobimo/project-template (profile cloudflare); change it there.
//
// Cloudflare's half of vite.config.ts, merged in by .devtools/vite/vite.ts. The plugin runs
// the Worker in workerd under `vite dev` and `vite preview`, with wrangler.jsonc's bindings
// simulated locally, and builds it beside the client: dist/client and dist/<worker>.
import { cloudflare } from '@cloudflare/vite-plugin'
import type { UserConfig } from 'vite'

export default (): UserConfig => ({ plugins: [cloudflare()] })
