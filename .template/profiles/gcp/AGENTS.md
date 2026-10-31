<!-- markdownlint-disable-file MD041 -- only the block is synced, into a full AGENTS.md -->
<!-- >>> template:gcp -->
## Hosting: Google Cloud Run

The `gcp` profile keeps this section, `.devtools/host/` and `deploy.yml` in step with the
template. The shared Vite, Vitest, ESLint and make configs load their Cloud Run parts from
there, so the project's own config files never name the host. `Dockerfile`, `.gcloudignore`,
`server/` and `infra/` are the project's. In a workspace `server/` sits in `APP_DIR` and the
others stay at the root, where the `Dockerfile` copies `<APP_DIR>/dist` into the image.

- **One service serves the app.** `server/site.ts` answers `/api/*` with the Hono app in
  `server/app.ts` and serves the client from `dist/client`; any other path gets
  `index.html` for the router. `make -C .devtools dev` runs the API inside the Vite dev
  server, and `make -C .devtools start` runs the production build as Cloud Run does.
- **The build is what ships.** `make -C .devtools build` bundles the server, Hono included,
  into `dist/server/index.mjs`. The image is Node and `dist/`, nothing else: Cloud Build
  receives only the `Dockerfile` and `dist/` (`.gcloudignore`). The client is the same
  build in every environment, so a setting that differs per environment belongs on the
  server, read from `process.env`.
- **Node is one version everywhere.** The `Dockerfile` copies Node from the official
  image's exact tag onto distroless, and `make -C .devtools check` fails unless that tag
  is the `node` in `mise.toml`. Bump them in one commit: a Dependabot PR for the image
  needs the `mise.toml` bump and `make -C .devtools lock` pushed onto it.
- **Infrastructure is OpenTofu, in `infra/`.** One GCP project per app, named in
  `infra/project.auto.tfvars.json` with the region and service name, which make reads too.
  It creates `<service>-staging` and `<service>-production`, each running as its own
  account with no roles; grant one what its service uses, in `infra/`. Environment
  variables and secrets go on the service there too, never in the image. Requests time
  out after 60 seconds, production runs at most 3 instances and staging 2, and a new
  revision gets traffic only once `/api/health` answers. A budget on the billing account
  mails its admins as the month nears `monthly_budget`; it warns, the caps limit. Applying
  it takes Billing Account Costs Manager, or Administrator, on that account.
- **Public unless `members` is set.** Apps are public and staging sends
  `X-Robots-Tag: noindex`. For an admin tool, list who may open it as `members` in
  `infra/project.auto.tfvars.json`: Identity-Aware Proxy then signs people in with Google
  and lets only them through, on both services. Change it with
  `make -C .devtools infra-plan` and `infra-apply`; the state is in a GCS bucket that
  `infra-bootstrap` creates once. Commit `infra/.terraform.lock.hcl`, which pins the
  provider; bump it by hand with `tofu init -upgrade`, a week after its release.
- **Deploys.** `make -C .devtools deploy ENV=staging|production` builds, then has Cloud
  Build make the image and Cloud Run roll it out. `deploy.yml` runs the same target: on a
  push to `main` to staging, and to production when `release.yml` calls it for a release.
  It signs in with Workload Identity Federation, no key, and only jobs in a GitHub
  environment named `staging` or `production` can. `make -C .devtools infra-github` sets
  the two repository variables it needs.
- **Server tests** sit beside the code as `server/**/*.test.ts` and call
  `app.request(path)` in Node.
- **One schema per concept** holds across the boundary: a route validates its input with
  the feature's schema from `src/features/<name>/schema.ts`, or from a workspace's shared
  package.
<!-- <<< template:gcp -->
