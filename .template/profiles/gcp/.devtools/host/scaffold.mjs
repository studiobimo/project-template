// Managed by studiobimo/project-template (profile gcp); change it there.
//
// The project's own Cloud Run files and packages, for `gen.mjs host` (or `gen.mjs app`) to
// write and install. Once written they are the project's: sync never compares them.
//
// What deploys the repository stays at its root, in a workspace too: repoFiles.
import { join } from 'node:path'

/** The .gcloudignore lines for a directory, which only count once each parent is let back in. */
const uploadOnly = (path) =>
  path
    .split('/')
    .flatMap((_, depth, parts) => {
      const dir = parts.slice(0, depth + 1).join('/')
      return depth < parts.length - 1 ? [`!/${dir}/`, `/${dir}/*`] : [`!/${dir}/`]
    })
    .join('\n')

export default ({ slug, appDir, repo }) => ({
  dependencies: ['hono', '@hono/node-server'],
  // .devtools/host/vite.ts imports them, and Node resolves that upward from .devtools/.
  devDependencies: repo === '.' ? [] : ['hono', '@hono/node-server'],
  next: [
    'edit infra/project.auto.tfvars.json   # the GCP project, region, repository, billing account, budget',
    'make -C .devtools infra-bootstrap     # once: the bucket for OpenTofu state',
    'make -C .devtools infra-apply         # the services, their accounts, Workload Identity',
    'make -C .devtools infra-github        # the repository variables deploy.yml signs in with',
    'make -C .devtools deploy ENV=staging  # <service>-staging, from this machine'
  ],
  files: {
    'server/tsconfig.json': `{
  "extends": "${join('..', repo, '.devtools/vite/tsconfig.base.json')}",
  "compilerOptions": {
    "tsBuildInfoFile": "../node_modules/.tmp/tsconfig.server.tsbuildinfo",
    "lib": ["ES2024"],
    "types": ["node"],
    "paths": { "@/*": ["../src/*"] }
  },
  "include": ["."]
}
`,
    'server/app.ts': `import { Hono } from 'hono'

// The API, under /api. A route validates what it reads with the feature's schema from
// src/features/<name>/schema.ts, the one the client parses the response with. Settings and
// secrets come from process.env, which infra/ sets on each service.
const app = new Hono().basePath('/api')

app.get('/health', (c) => c.json({ ok: true }))

app.notFound((c) => c.json({ error: 'Not found' }, 404))
app.onError((error, c) => {
  console.error(error)
  return c.json({ error: 'Internal error' }, 500)
})

export default app
`,
    'server/app.test.ts': `import { describe, expect, it } from 'vitest'

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
`,
    'server/site.ts': `import { serveStatic } from '@hono/node-server/serve-static'
import { Hono } from 'hono'
import { compress } from 'hono/compress'
import { createMiddleware } from 'hono/factory'
import { secureHeaders } from 'hono/secure-headers'

import api from './app'

// Vite names everything in assets/ by its content, so a file there never changes and is
// cached for a year. Anything else, index.html above all, is checked on every load, so a
// deploy reaches the next one.
const cache = createMiddleware(async (c, next) => {
  await next()
  if (c.res.status === 200) {
    const immutable = c.req.path.startsWith('/assets/')
    c.header('Cache-Control', immutable ? 'public, max-age=31536000, immutable' : 'no-cache')
  }
})

// Asks search engines to leave the site out: for staging, which is public too.
const noindex = createMiddleware(async (c, next) => {
  await next()
  c.header('X-Robots-Tag', 'noindex')
})

/**
 * Everything the service answers: /api/* from the app in app.ts, and the built client from
 * root. A path that is neither gets index.html, for the client's router, except under
 * assets/, where a missing file is a 404 rather than a page cached for a year.
 */
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
`,
    'server/site.test.ts': `import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs'
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
`,
    'server/index.ts': `import { fileURLToPath } from 'node:url'

import { serve } from '@hono/node-server'

import { site } from './site'

// This runs as dist/server/index.mjs, so the client is beside it, in dist/client.
const root = fileURLToPath(new URL('../client', import.meta.url))
const port = Number(process.env.PORT ?? 8080)
// infra/ sets INDEXED=false on staging.
const app = site(root, { indexed: process.env.INDEXED !== 'false' })

const server = serve({ fetch: app.fetch, port }, () => console.log(\`listening on \${port}\`))

// Cloud Run sends SIGTERM and waits ten seconds before it stops the instance: finish the
// requests in flight, then exit.
process.on('SIGTERM', () => server.close(() => process.exit(0)))
`
  },
  repoFiles: {
    Dockerfile: `# Cloud Build builds this from what \`make -C .devtools build\` left in dist/: .gcloudignore
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
`,
    '.gcloudignore': `# What \`gcloud run deploy --source\` uploads to Cloud Build: the Dockerfile and dist/, which
# \`make -C .devtools build\` writes first. Nothing else, so no source, no .env and no
# credentials file goes with it.
/*
!/Dockerfile
${uploadOnly(join(appDir, 'dist'))}
`,
    'infra/project.auto.tfvars.json': `{
  "project": "${slug}",
  "region": "us-central1",
  "service": "${slug}",
  "github_repository": "studiobimo/${slug}",
  "billing_account": "000000-000000-000000",
  "monthly_budget": 25,
  "members": []
}
`,
    'infra/versions.tf': `terraform {
  required_version = ">= 1.10"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.7"
    }
  }

  # \`make -C .devtools infra-bootstrap\` creates the bucket. OpenTofu evaluates the variable
  # before anything else, so the name follows the project.
  backend "gcs" {
    bucket = "\${var.project}-tofu-state"
    prefix = "tofu"
  }
}

provider "google" {
  project = var.project
  region  = var.region

  # The budget API bills its quota to a project; with a person's credentials there is none
  # unless this names it.
  billing_project       = var.project
  user_project_override = true
}
`,
    'infra/variables.tf': `# Values in project.auto.tfvars.json, which make reads too.

variable "project" {
  description = "The GCP project ID. One project per app: the account names below are fixed."
  type        = string
}

variable "region" {
  description = "The region the services, and the images they run, live in."
  type        = string
}

variable "service" {
  description = "The Cloud Run service's name, before -staging or -production."
  type        = string
}

variable "github_repository" {
  description = "owner/name of the only repository whose workflows may deploy."
  type        = string
}

variable "billing_account" {
  description = "The billing account the project is on, XXXXXX-XXXXXX-XXXXXX, for its budget."
  type        = string
}

variable "monthly_budget" {
  description = "What the project should cost a month, in the billing account's currency."
  type        = number
}

variable "members" {
  description = <<-EOT
    Who may open the app, as IAM principals such as user:ana@example.com or
    group:admins@example.com. Empty, the app is public; otherwise Identity-Aware Proxy signs
    people in and lets only these through. For admin tools.
  EOT
  type        = list(string)
  default     = []
}
`,
    'infra/main.tf': `locals {
  environments = toset(["staging", "production"])
  private      = length(var.members) > 0
}

data "google_project" "this" {}

resource "google_project_service" "api" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "billingbudgets.googleapis.com",
    "cloudbuild.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "iap.googleapis.com",
    "run.googleapis.com",
    "sts.googleapis.com",
  ])
  service            = each.key
  disable_on_destroy = false
}

# Where Cloud Build puts the images \`gcloud run deploy --source\` builds. Made here rather
# than by the first deploy, so old images are cleaned up.
resource "google_artifact_registry_repository" "source" {
  repository_id = "cloud-run-source-deploy"
  location      = var.region
  format        = "DOCKER"

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = 10
    }
  }

  cleanup_policies {
    id     = "delete-old"
    action = "DELETE"
    condition {
      older_than = "2592000s"
    }
  }

  depends_on = [google_project_service.api]
}

# Each environment's service runs as its own account, with no roles: grant one what the
# service uses, such as a secret or a bucket, and nothing more.
resource "google_service_account" "runtime" {
  for_each     = local.environments
  account_id   = "run-\${each.key}"
  display_name = "Cloud Run: \${var.service}-\${each.key}"
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
    service_account                  = google_service_account.runtime[each.key].email
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

      # Staging is public too: keep search engines out of it.
      dynamic "env" {
        for_each = each.key == "staging" ? { INDEXED = "false" } : {}
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

  depends_on = [google_project_service.api]
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

# Mails the billing account's admins as the month's cost reaches half, nine tenths and all
# of monthly_budget, and when it is forecast to pass it. It stops nothing.
resource "google_billing_budget" "project" {
  billing_account = var.billing_account
  display_name    = var.service

  budget_filter {
    projects = ["projects/\${data.google_project.this.number}"]
  }

  amount {
    specified_amount {
      units = tostring(var.monthly_budget)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.9
  }
  threshold_rules {
    threshold_percent = 1.0
  }
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  depends_on = [google_project_service.api]
}

# Builds the images, instead of the project's default compute account.
resource "google_service_account" "builder" {
  account_id   = "builder"
  display_name = "Cloud Build: images for Cloud Run"
}

resource "google_project_iam_member" "builder" {
  project = var.project
  role    = "roles/run.builder"
  member  = google_service_account.builder.member
}

# Deploys, from GitHub Actions: it uploads the source, starts a build as builder, and rolls
# the result out as each service's runtime account.
resource "google_service_account" "deployer" {
  account_id   = "deployer"
  display_name = "GitHub Actions: deploys \${var.service}"
}

resource "google_project_iam_member" "deployer" {
  for_each = toset(["roles/run.sourceDeveloper", "roles/serviceusage.serviceUsageConsumer"])
  project  = var.project
  role     = each.key
  member   = google_service_account.deployer.member
}

resource "google_service_account_iam_member" "deployer_acts_as" {
  for_each = merge(
    { for env, account in google_service_account.runtime : env => account.name },
    { builder = google_service_account.builder.name },
  )
  service_account_id = each.value
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.deployer.member
}

# GitHub Actions signs in with its own OIDC token: no key exists to leak. Only a job in
# github_repository that names a GitHub environment gets in, so the environments' rules
# (who may approve production, which branches) decide who deploys.
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
  depends_on                = [google_project_service.api]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub Actions"

  attribute_mapping = {
    "google.subject"        = "assertion.sub"
    "attribute.repository"  = "assertion.repository"
    "attribute.environment" = "assertion.environment"
  }
  attribute_condition = "assertion.repository == '\${var.github_repository}' && assertion.environment in ['staging', 'production']"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "github_deploys" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/\${google_iam_workload_identity_pool.github.name}/attribute.repository/\${var.github_repository}"
}
`,
    'infra/outputs.tf': `output "urls" {
  description = "Each environment's URL."
  value       = { for env, service in google_cloud_run_v2_service.app : env => service.uri }
}

# make -C .devtools infra-github copies these two into the repository's variables.
output "workload_identity_provider" {
  value = google_iam_workload_identity_pool_provider.github.name
}

output "deployer" {
  value = google_service_account.deployer.email
}
`
  }
})
