import { cloudflare } from '@cloudflare/vite-plugin'
import type { UserConfig } from 'vite'

export default (): UserConfig => ({ plugins: [cloudflare()] })
