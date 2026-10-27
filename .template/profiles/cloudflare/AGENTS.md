<!-- markdownlint-disable-file MD041 -- only the block is synced, into a full AGENTS.md -->
<!-- >>> template:cloudflare -->
## Hosting: Cloudflare Workers

The `cloudflare` profile keeps this section and `.devtools/host/` in step with the template.
The shared Vite, Vitest, ESLint and make configs load their Cloudflare parts from there, so
the project's own config files never name the host. `wrangler.jsonc`, `.dev.vars.example`
and `worker/` are the project's.

- **One Worker serves the app.** Static files come from `dist/client`, and any path that is
  not a file falls back to `index.html` for the router. Only `/api/*` runs the Hono app in
  `worker/index.ts`. `make -C .devtools dev` runs it in workerd beside the client, with
  the bindings in `wrangler.jsonc` simulated locally.
- **Environments.** The top level of `wrangler.jsonc` is local development. Deploys go to
  `env.staging` or `env.production`, as `<name>-staging` and `<name>-production`. Neither
  inherits bindings or vars from the top level, so restate them in each.
- **Deploy with `make -C .devtools deploy ENV=<env>`.** The environment is fixed when the
  app is built, not when it is deployed. The target builds and deploys in one step;
  `wrangler deploy` after a plain build ships local development's bindings. On Workers
  Builds, set `CLOUDFLARE_ENV` as a build variable, use `pnpm exec vite build` as the build
  command, and `pnpm exec wrangler deploy` as the deploy command. No token goes in the
  repository.
- **Secrets** are never committed. List their names in `.dev.vars.example`. Put local
  values in `.dev.vars`, and deployed ones with
  `pnpm exec wrangler secret put <NAME> --env <env>`.
- **The `Env` type** is `worker/worker-configuration.d.ts`, generated from `wrangler.jsonc`
  by `make -C .devtools types` and ignored by git. `typecheck` runs it first.
- **Worker tests** sit beside the code as `worker/**/*.test.ts`. They call
  `app.request(path, init, env)` with `env` from `getPlatformProxy()`, and run in Node, not
  workerd. Code that imports a `cloudflare:*` module is tested through its binding.
- **One schema per concept** holds across the boundary: a route validates its input with
  the feature's schema from `src/features/<name>/schema.ts`.
<!-- <<< template:cloudflare -->
