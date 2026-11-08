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
