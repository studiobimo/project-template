// Managed by studiobimo/project-template (profile gcp); change it there.
//
// Cloud Run's half of vite.config.ts, merged in by .devtools/vite/vite.ts. The client builds
// into dist/client, beside the server's bundle in dist/server (.devtools/host/server.ts).
// Under `vite dev`, /api/* goes to the Hono app in server/app.ts, which Vite loads and
// reloads as it does the client, so one dev server runs both.
import { getRequestListener } from '@hono/node-server'
import type { Hono } from 'hono'
import { isRunnableDevEnvironment, type Plugin, type UserConfig } from 'vite'

export default (): UserConfig => ({
  build: { outDir: 'dist/client' },
  plugins: [api()]
})

function api(): Plugin {
  return {
    name: 'api',
    configureServer(server) {
      const ssr = server.environments.ssr
      server.middlewares.use((req, res, next) => {
        if (!/^\/api(?:[/?]|$)/.test(req.url ?? '')) {
          next()
          return
        }
        if (!isRunnableDevEnvironment(ssr)) {
          next(new Error('the ssr environment cannot run server/app.ts in this process'))
          return
        }
        ssr.runner
          .import<{ default: Hono }>('/server/app.ts')
          .then(({ default: app }) => getRequestListener(app.fetch)(req, res))
          .catch(next)
      })
    }
  }
}
