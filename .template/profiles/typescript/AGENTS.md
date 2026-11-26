<!-- markdownlint-disable-file MD041 -- only the block is synced, into a full AGENTS.md -->
<!-- >>> template:typescript -->
## TypeScript workspace: pnpm, Turborepo and zod contracts

The `typescript` profile keeps this section, the shared configs and scripts in
`.devtools/typescript/` and `.devtools/typescript.mk` in step with the template. The project's
own `package.json`, `turbo.json`, `eslint.config.js`, `knip.json` and every package's
`package.json` and `tsconfig*.json` import or extend those and add only what is particular to it.

### Stack

- TypeScript in `strict` mode on Node, the version `mise.toml` pins. Packages compile with `tsc`
  into `dist/`; sources import each other with their `.ts` extension, which `tsc` rewrites.
- **Packages:** pnpm, pinned in `mise.toml`; the root `package.json` repeats the version in
  `devEngines.packageManager` for Turborepo, and `make ci` fails when they differ. Never add `package-lock.json` or `yarn.lock`.
- **Tasks:** Turborepo, under make. `build`, `typecheck` and `test` are `turbo run` over every
  package that has the script, dependencies first and cached. A package exposes `build`,
  `typecheck` and `test` and nothing else is needed. Turborepo is a devDependency of the root.
- **Tests:** Vitest, next to the code as `*.test.ts`. **Lint:** one ESLint config at the root.
- **Validation:** zod, in `packages/contracts` only.

### Layout

```text
packages/contracts/   every message and schema: zod schemas and the topics that carry them
services/<name>/      one deployable service each; its entry point is src/index.ts
.devtools/typescript/ shared tsconfigs, ESLint and Vitest configs, the one Dockerfile
```

### Conventions

- **One schema per message.** A message exists once, in `packages/contracts`, as a zod schema
  wrapped by `defineTopic(name, schema)`. A publisher calls `topic.encode(payload)`, a consumer
  `topic.decode(data)`: both validate, so a malformed message fails where it is made and where it
  is read. Pub/Sub topic schemas only accept Avro and Protobuf, so zod does it in code. Never
  declare the same payload twice.
- **Scaffold with the generator:** `node .devtools/typescript/gen.mjs workspace` writes the
  root files and `packages/contracts` and installs their packages;
  `node .devtools/typescript/gen.mjs service <name>` adds `services/<name>`.
- **A new package** needs a `package.json` with `build`, `typecheck` and `test` scripts, a
  `tsconfig.json` extending `../../.devtools/typescript/tsconfig.package.json` and a
  `tsconfig.build.json` extending `../../.devtools/typescript/tsconfig.build.json`.
  `"test": "vitest run --config ../../.devtools/typescript/vitest.ts"` runs the default setup.
  List its folder under `packages:` in `pnpm-workspace.yaml` unless a glob there covers it.
- **Images.** Every service builds with the same Dockerfile:
  `make -C .devtools image SERVICE=services/<name>`. Its Node is the one `mise.toml` pins;
  `make ci` fails when they differ, so bump both in one commit.
  pnpm builds the service and the workspace packages it depends on, then `pnpm deploy` copies
  it with its production dependencies only; its entry point is `dist/index.js`. The image is
  built for `linux/amd64` whatever the host, so an Apple Silicon build runs on Cloud Run. The
  Node image is taken by digest.
- **Narrowed CI.** `ci / validate` sets `AFFECTED_BASE` for a pull request it may narrow, and
  `make test` then runs `turbo run test --affected`: the packages that changed and what depends
  on them. A change to the lockfile, `pnpm-workspace.yaml`, `mise.lock` or
  `.devtools/typescript/` (`globalDependencies` in `turbo.json`) affects every package. A local
  run sets nothing and tests everything. `FULL_CI_TARGETS` lists suites a narrowed run skips.

### Commands

```sh
make -C .devtools install   # the packages pnpm-lock.yaml pins
make -C .devtools build     # every package, dependencies first
make -C .devtools ci        # build, types, ESLint, knip, jscpd, tests, audit, Node check
make -C .devtools image SERVICE=services/<name>
```
<!-- <<< template:typescript -->
