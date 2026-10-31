// Managed by studiobimo/project-template (profile cloudflare); change it there.
//
// The project's own Cloudflare files and packages, for `gen.mjs host` (or `gen.mjs app`) to
// write and install. Once written they are the project's: sync never compares them.
import { join } from 'node:path'

// The newest date the workerd that pnpm installs is sure to know: pnpm takes nothing less
// than a week old, and a release supports dates up to its own.
const compatibilityDate = new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10)

export default ({ slug, repo }) => ({
  dependencies: ['hono'],
  devDependencies: ['@cloudflare/vite-plugin', 'wrangler'],
  next: [
    'pnpm exec wrangler login                 # once, to deploy from this machine',
    'make -C .devtools deploy ENV=staging     # <name>-staging, from wrangler.jsonc'
  ],
  files: {
    'wrangler.jsonc': `{
  "$schema": "${join(repo, 'node_modules/wrangler/config-schema.json')}",
  "name": "${slug}",
  "main": "worker/index.ts",
  "compatibility_date": "${compatibilityDate}",
  "compatibility_flags": ["nodejs_compat"],
  "assets": {
    // Only /api/* reaches the Worker. Every other path is a file from dist/client or, for a
    // client route, index.html.
    "not_found_handling": "single-page-application",
    "run_worker_first": ["/api/*"]
  },
  "observability": { "enabled": true },
  "upload_source_maps": true,
  // The top level is local development. A deploy goes to one of these environments, named
  // <name>-<environment>, chosen at build time: make -C .devtools deploy ENV=staging.
  // Neither inherits bindings or vars from the top level, so each restates them.
  "env": {
    "staging": {},
    "production": {}
  }
}
`,
    '.dev.vars.example': `# The Worker's secrets, by name: copy this to .dev.vars, which git ignores, and fill it in
# for vite dev and the tests. make -C .devtools types reads the names from here for the Env
# type. A deployed environment's values: pnpm exec wrangler secret put <NAME> --env <env>.
`,
    'worker/tsconfig.json': `{
  "extends": "${join('..', repo, '.devtools/vite/tsconfig.base.json')}",
  "compilerOptions": {
    "tsBuildInfoFile": "../node_modules/.tmp/tsconfig.worker.tsbuildinfo",
    "lib": ["ES2024"],
    "types": ["node"],
    "paths": { "@/*": ["../src/*"] }
  },
  "include": ["."]
}
`,
    'worker/index.ts': `import { Hono } from 'hono'
import { secureHeaders } from 'hono/secure-headers'

// Only /api/* reaches the Worker: wrangler.jsonc's run_worker_first. A route validates what
// it reads with the feature's schema from src/features/<name>/schema.ts, the one the client
// parses the response with.
const app = new Hono<{ Bindings: Env }>().basePath('/api')

app.use(secureHeaders())

app.get('/health', (c) => c.json({ ok: true }))

app.notFound((c) => c.json({ error: 'Not found' }, 404))
app.onError((error, c) => {
  console.error(error)
  return c.json({ error: 'Internal error' }, 500)
})

export default app
`,
    'worker/index.test.ts': `import { afterAll, describe, expect, it } from 'vitest'
import { getPlatformProxy } from 'wrangler'

import app from './index'

// wrangler.jsonc's bindings and .dev.vars, run locally as vite dev runs them.
const platform = await getPlatformProxy<Env>()
afterAll(() => platform.dispose())

describe('worker', () => {
  it('answers /api/health', async () => {
    const response = await app.request('/api/health', {}, platform.env)
    expect(response.status).toBe(200)
    expect(await response.json()).toEqual({ ok: true })
  })

  it('answers an unknown /api path with a JSON 404', async () => {
    const response = await app.request('/api/nothing-here', {}, platform.env)
    expect(response.status).toBe(404)
    expect(await response.json()).toEqual({ error: 'Not found' })
  })
})
`
  }
})
