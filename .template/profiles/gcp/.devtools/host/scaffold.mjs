import { join } from 'node:path'

import { INFRA, infraFiles } from '../gcp-infra/scaffold.mjs'

const uploadOnly = (path) =>
  path
    .split('/')
    .flatMap((_, depth, parts) => {
      const dir = parts.slice(0, depth + 1).join('/')
      return depth < parts.length - 1 ? [`!/${dir}/`, `/${dir}/*`] : [`!/${dir}/`]
    })
    .join('\n')

const serverTsconfig = (repo) => `{
  "extends": "${join('..', repo, '.devtools/vite/tsconfig.base.json')}",
  "compilerOptions": {
    "tsBuildInfoFile": "../node_modules/.tmp/tsconfig.server.tsbuildinfo",
    "lib": ["ES2024"],
    "types": ["node"],
    "paths": { "@/*": ["../src/*"] }
  },
  "include": ["."]
}
`

const serverApp = `import { Hono } from 'hono'

const app = new Hono().basePath('/api')

app.get('/health', (c) => c.json({ ok: true }))

app.notFound((c) => c.json({ error: 'Not found' }, 404))
app.onError((error, c) => {
  console.error(error)
  return c.json({ error: 'Internal error' }, 500)
})

export default app
`

const serverAppTest = `import { describe, expect, it } from 'vitest'

import app from './app'

describe('api', () => {
  it('answers /api/health', async () => {
    const response = await app.request('/api/health')
    expect(response.status).toBe(200)
    expect(await response.json()).toEqual({ ok: true })
  })

  it('answers an unknown /api path with a JSON 404', async () => {
    const response = await app.request('/api/nothing-here')
    expect(response.status).toBe(404)
    expect(await response.json()).toEqual({ error: 'Not found' })
  })
})
`

const serverSite = `import { serveStatic } from '@hono/node-server/serve-static'
import { Hono } from 'hono'
import { compress } from 'hono/compress'
import { createMiddleware } from 'hono/factory'
import { secureHeaders } from 'hono/secure-headers'

import api from './app'

const cache = createMiddleware(async (c, next) => {
  await next()
  if (c.res.status === 200) {
    const immutable = c.req.path.startsWith('/assets/')
    c.header('Cache-Control', immutable ? 'public, max-age=31536000, immutable' : 'no-cache')
  }
})

const noindex = createMiddleware(async (c, next) => {
  await next()
  c.header('X-Robots-Tag', 'noindex')
})

export function site(root: string, options: { indexed?: boolean } = {}) {
  const app = new Hono()
  if (options.indexed === false) app.use(noindex)
  return app
    .use(secureHeaders(), compress())
    .route('/', api)
    .all('/api/*', (c) => c.json({ error: 'Not found' }, 404))
    .use(cache, serveStatic({ root }))
    .get('/assets/*', (c) => c.text('Not found', 404))
    .get('*', serveStatic({ root, path: 'index.html' }))
}
`

const serverSiteTest = `import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

import { afterAll, describe, expect, it } from 'vitest'

import { site } from './site'

const root = mkdtempSync(join(tmpdir(), 'site-'))
mkdirSync(join(root, 'assets'))
writeFileSync(join(root, 'index.html'), '<!doctype html><title>app</title>')
writeFileSync(join(root, 'assets', 'index-abc123.js'), 'export {}')
afterAll(() => rmSync(root, { recursive: true }))

const app = site(root)

describe('site', () => {
  it('serves the API', async () => {
    const response = await app.request('/api/health')
    expect(await response.json()).toEqual({ ok: true })
  })

  it('answers an unknown /api path with a JSON 404, not the page', async () => {
    const response = await app.request('/api/nothing-here')
    expect(response.status).toBe(404)
    expect(await response.json()).toEqual({ error: 'Not found' })
  })

  it('caches a hashed asset for good', async () => {
    const response = await app.request('/assets/index-abc123.js')
    expect(response.status).toBe(200)
    expect(response.headers.get('cache-control')).toContain('immutable')
  })

  it('answers a missing asset with a 404, not the page', async () => {
    const response = await app.request('/assets/index-gone.js')
    expect(response.status).toBe(404)
    expect(response.headers.get('cache-control')).toBeNull()
  })

  it('answers a client route with index.html, checked on every load', async () => {
    const response = await app.request('/invoices/42')
    expect(response.status).toBe(200)
    expect(await response.text()).toContain('<title>app</title>')
    expect(response.headers.get('cache-control')).toBe('no-cache')
  })

  it('is indexed unless told otherwise', async () => {
    expect((await app.request('/')).headers.get('x-robots-tag')).toBeNull()
    const hidden = site(root, { indexed: false })
    expect((await hidden.request('/')).headers.get('x-robots-tag')).toBe('noindex')
    expect((await hidden.request('/api/health')).headers.get('x-robots-tag')).toBe('noindex')
  })
})
`

const serverIndex = `import { fileURLToPath } from 'node:url'

import { serve } from '@hono/node-server'

import { site } from './site'

const root = fileURLToPath(new URL('../client', import.meta.url))
const port = Number(process.env.PORT ?? 8080)
const app = site(root, { indexed: process.env.INDEXED !== 'false' })

const server = serve({ fetch: app.fetch, port }, () => console.log(\`listening on \${port}\`))

process.on('SIGTERM', () => server.close(() => process.exit(0)))
`

const dockerfile = (
  appDir
) => `# Cloud Build builds this from what \`make -C .devtools build\` left in dist/: .gcloudignore
# sends it nothing else. The server is one bundled file, so the image is Node and dist/,
# with no shell, no package manager and no node_modules.
#
# Node is the exact release mise.toml pins, taken from the official image and run on
# distroless: distroless's own Node images name only the major version. make check fails
# when the two differ, so a Dependabot bump of this tag lands with the mise.toml one.
FROM node:24.21.0-trixie-slim@sha256:173f125896c3b47ddf056734c7ea789d04595a6a08769a8f78e0df642781fb66 AS node

FROM gcr.io/distroless/cc-debian13:nonroot@sha256:3ee00291cf386ec52a552e6a858d555debd74776eb4bfa53fa3df2cd6677515e
COPY --from=node /usr/local/bin/node /usr/local/bin/node
WORKDIR /app
COPY ${join(appDir, 'dist')} ./dist
ENV NODE_ENV=production
ENTRYPOINT ["/usr/local/bin/node"]
CMD ["--enable-source-maps", "dist/server/index.mjs"]
`

const gcloudignore = (
  appDir
) => `# What \`gcloud run deploy --source\` uploads to Cloud Build: the Dockerfile and dist/, which
# \`make -C .devtools build\` writes first. Nothing else, so no source, no .env and no
# credentials file goes with it.
/*
!/Dockerfile
${uploadOnly(join(appDir, 'dist'))}
`

const tfService = `variable "members" {
  description = <<-EOT
    Who may open the app, as IAM principals such as user:ana@example.com or
    group:admins@example.com. Empty, the app is public; otherwise Identity-Aware Proxy signs
    people in and lets only these through. For admin tools.
  EOT
  type        = list(string)
  default     = []
}

locals {
  private = length(var.members) > 0
}

resource "google_project_service" "iap" {
  service            = "iap.googleapis.com"
  disable_on_destroy = false
}

resource "google_cloud_run_v2_service" "app" {
  for_each = local.environments
  name     = "\${var.service}-\${each.key}"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"
  labels   = { app = var.service, environment = each.key }

  # Public, anyone may call it without an IAM binding to allUsers. With members, IAP signs
  # people in first, and only IAP may call the service.
  invoker_iam_disabled = !local.private
  iap_enabled          = local.private
  deletion_protection  = each.key == "production"

  template {
    service_account                  = google_service_account.runtime["app-\${each.key}"].email
    labels                           = { app = var.service, environment = each.key }
    max_instance_request_concurrency = 80
    # A request still unanswered after this fails with a 504, rather than holding an
    # instance for Cloud Run's default of five minutes.
    timeout = "60s"

    # The caps are what bound the bill: the budget below only warns.
    scaling {
      min_instance_count = 0
      max_instance_count = each.key == "production" ? 3 : 2
    }

    containers {
      # A placeholder until the first deploy: from then on the image is the deploy's, not
      # OpenTofu's (ignore_changes below). Settings for the app go in env blocks here.
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      # Development is public too: keep search engines out of it.
      dynamic "env" {
        for_each = each.key == "development" ? { INDEXED = "false" } : {}
        content {
          name  = env.key
          value = env.value
        }
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle          = true
        startup_cpu_boost = true
      }

      # Traffic reaches a new revision only once the app answers, so a deploy that cannot
      # start leaves the previous one serving.
      startup_probe {
        http_get {
          path = "/api/health"
        }
        period_seconds    = 2
        timeout_seconds   = 1
        failure_threshold = 15
      }
    }
  }

  lifecycle {
    ignore_changes = [
      client,
      client_version,
      template[0].containers[0].image,
    ]
  }

  depends_on = [google_project_service.api, google_project_service.iap]
}

# With members, IAP calls the service for them: its agent needs to be allowed to. A project
# whose first IAP use this is may not have the agent yet; if apply fails on it, run
# \`gcloud beta services identity create --service=iap.googleapis.com\` and apply again.
resource "google_cloud_run_v2_service_iam_member" "iap" {
  for_each = local.private ? local.environments : toset([])
  name     = google_cloud_run_v2_service.app[each.key].name
  location = var.region
  role     = "roles/run.invoker"
  member   = "serviceAccount:service-\${data.google_project.this.number}@gcp-sa-iap.iam.gserviceaccount.com"
}

resource "google_iap_web_cloud_run_service_iam_member" "members" {
  for_each = {
    for pair in setproduct(local.private ? local.environments : toset([]), var.members) :
    "\${pair[0]} \${pair[1]}" => { environment = pair[0], member = pair[1] }
  }
  project                = var.project
  location               = var.region
  cloud_run_service_name = google_cloud_run_v2_service.app[each.value.environment].name
  role                   = "roles/iap.httpsResourceAccessor"
  member                 = each.value.member
}

output "urls" {
  description = "Each environment's URL."
  value       = { for env, service in google_cloud_run_v2_service.app : env => service.uri }
}
`

export default (project) => {
  const { appDir, repo, deployEnvs } = project
  return {
    dependencies: ['hono', '@hono/node-server'],
    devDependencies: repo === '.' ? [] : ['hono', '@hono/node-server'],
    next: [
      ...INFRA.next,
      `make -C .devtools deploy ENV=${deployEnvs[0]} # <service>-${deployEnvs[0]}, from this machine`
    ],
    files: {
      'server/tsconfig.json': serverTsconfig(repo),
      'server/app.ts': serverApp,
      'server/app.test.ts': serverAppTest,
      'server/site.ts': serverSite,
      'server/site.test.ts': serverSiteTest,
      'server/index.ts': serverIndex
    },
    repoFiles: {
      Dockerfile: dockerfile(appDir),
      '.gcloudignore': gcloudignore(appDir),
      ...infraFiles(project, { members: [] }),
      'infra/service.tf': tfService
    }
  }
}
