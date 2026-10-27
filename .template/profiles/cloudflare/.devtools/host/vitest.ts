// Managed by studiobimo/project-template (profile cloudflare); change it there.
//
// The Worker's test project, added to the React one by .devtools/vite/vitest.ts. Its tests
// call the Hono app directly, app.request(path, init, env), with the env from wrangler's
// getPlatformProxy(): the bindings in wrangler.jsonc, run locally as `vite dev` runs them.
//
// They run in Node, not workerd, because @cloudflare/vitest-pool-workers supports Vitest 4
// only. Code that imports a cloudflare:* module (Durable Objects, Workflows) cannot be
// imported here; test it through the bindings instead.
import type { TestProjectInlineConfiguration } from 'vitest/config'

const projects: TestProjectInlineConfiguration[] = [
  {
    resolve: { tsconfigPaths: true },
    test: {
      name: 'worker',
      environment: 'node',
      include: ['worker/**/*.test.ts'],
      restoreMocks: true
    }
  }
]

export default projects
