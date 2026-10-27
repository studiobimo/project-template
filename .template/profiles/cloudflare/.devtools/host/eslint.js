// Managed by studiobimo/project-template (profile cloudflare); change it there.
//
// The Worker's part of the ESLint config, added after the shared rules by
// .devtools/vite/eslint.js.
import { globalIgnores } from 'eslint/config'
import globals from 'globals'

export default [
  globalIgnores(['.wrangler', 'worker/worker-configuration.d.ts']),
  {
    // workerd's globals are a service worker's: fetch, Request, caches, crypto.
    files: ['worker/**/*.ts'],
    languageOptions: { globals: globals.serviceworker }
  }
]
