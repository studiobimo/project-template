# studiobimo/project-template

[![CI](https://github.com/studiobimo/project-template/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/studiobimo/project-template/actions/workflows/ci.yml)
[![Release](https://github.com/studiobimo/project-template/actions/workflows/release.yml/badge.svg?branch=main)](https://github.com/studiobimo/project-template/actions/workflows/release.yml)

The starting point for a new [studiobimo](https://github.com/studiobimo) repository, whatever it
is written in. It carries the parts every project shares and nothing about any one language:

- **Dev tooling**: one Makefile entry point under `.devtools/`, every tool pinned with
  [mise](https://mise.jdx.dev/), and [lefthook](https://lefthook.dev/) hooks for secrets,
  workflows, shell, Markdown, typos and links.
- **Conventions, enforced**: Conventional Commits and Branch names, a 20-file PR limit, in git
  hooks, in CI, and for AI agents before they act. Issue titles follow Conventional Commits too:
  the issue forms start them with a type, and a workflow flags one that does not.
- **CI and releases** as thin wrappers over
  [studiobimo/.github](https://github.com/studiobimo/.github): `ci.yml` (baseline and validate), `pr-events.yml`,
  release-please.
- **An agent guide**: `AGENTS.md` with the layout, the rules, the commands and where shared
  things live. `CLAUDE.md` imports it, so every agent reads the same file.

## Start a project

```sh
gh repo create studiobimo/my-project --template studiobimo/project-template --private --clone
cd my-project
make -C .devtools init NAME="My Project" SLUG=my-project DESC="What it is, in one line."
make -C .devtools setup
make -C .devtools check
```

`init` is the first thing to run in a new copy, before anything is committed. It fills in the
placeholders, swaps this README for a starter one, and deletes itself and `.template/`. Then it
sets up the repository on GitHub with `gh`, which has to be signed in as an admin of it:

- the description, from `DESC`, and any deployment environments named in `ENVS="development production"`;
- the settings every studiobimo repository shares: squash-only merges, Actions and workflow
  permissions, secret scanning and Dependabot alerts, and the rulesets that protect `main` and
  release tags. Those are defined once in [studiobimo/.github](https://github.com/studiobimo/.github)
  and applied by its script, so nothing here copies them.

The GitHub half can be repeated at any time: `make -C .devtools github` applies it again, and
`make -C .devtools github CHECK=1` only shows what differs. Once the rulesets are on, `main` takes
pull requests only, so the initialising commit goes up as one; `init` prints the commands.

A private repository gets [less on the Free plan](https://github.com/studiobimo/.github#rulesets-and-repository-settings).
GitHub offers it no rulesets, secret scanning or private vulnerability reporting, so `github`
skips them with a note. `main` then takes direct pushes, and `ci / baseline` and `ci / validate` run but are not
required. Only the local hooks and the agent guard hold the rules, and both can be skipped.

Then add the language: build files, the project's own Makefile targets, tools in `mise.toml`
and jobs in `lefthook.yml`, a CI workflow, and the Project, Layout and Conventions sections of `AGENTS.md`.

## Staying in step

A template only helps on day one unless something keeps the copies honest. Every file here is one
of four kinds, and [`.template/manifest`](.template/manifest) says which:

| Kind | Examples | After day one |
| --- | --- | --- |
| **Managed file** | `.devtools/base.mk`, `.devtools/lefthook-base.yml`, `.devtools/scripts/*.sh` (`strings.sh` holds their names and messages), `.codex/*`, `ci.yml`, `pr-events.yml`, `issue-title.yml` | Identical everywhere. `sync` overwrites it. |
| **Managed block** | the `base` region of `.gitignore`, the shared tools in `mise.toml`, the rules in `AGENTS.md` | Identical between its `>>> template:<name>` and `<<< template:<name>` markers. The rest of the file is the project's. |
| **Seed entry** | `.repo-health/baseline.json` | The project's. `sync` writes it only if the project has none, never overwrites it; `drift` reports a missing one and ignores the content. For a file projects created before the template shipped it never got. |
| **Seeded** | `README.md`, `.devtools/Makefile`, `.commitlintrc.yaml`, `release.yml`, the issue forms | The project's. Never compared. |

In a project:

```sh
make -C .devtools drift   # what differs from the latest template release
make -C .devtools sync    # take the template's version of every managed file and block
```

Each project also runs `template-drift.yml` weekly. It keeps one issue labelled `template-drift`
open while anything differs, rewrites it as that changes, and closes it when the repo is back in
step. A project that has to differ on purpose lists the path in `.template-ignore`.

Some entries are marked `required` in the manifest: the agent guard, the shared hooks, the CI,
PR-events, issue-title and drift workflows, `template-sync.sh` itself and the `strings.sh` it reads, the
rules in `AGENTS.md`, and the `overrides` block of `CODEOWNERS`.
They are what keeps every repo honest, so `.template-ignore` cannot switch them off:
listing one there is reported as drift, and `sync` applies it anyway. The `overrides` block makes
the fleet's owners review every change to `.template-ignore`, `.template-profiles`, the tool pins
and the agent settings, so a repo can still depart from the template, but not without review.

A `seed` entry takes `required` too, with the same meaning: listing its path in `.template-ignore`
is drift and `sync` seeds the file anyway. The baseline is a plain seed. A project whose `sync` is
older than the `seed` kind gets everything listed before it, itself included, and then stops with
`unknown entry 'seed ...'` (exit 2); running `sync` again, now with the new script, writes the seed.

### CI

`ci.yml` calls the org's `ci-project` and gives a pull request two required checks. `ci / baseline`
runs on every push, drafts included: the pre-commit hooks over every file (secret scan and linters)
and the pull request's title, branch, size and commits. `ci / validate` runs `make -C .devtools ci`
and is decided by the policy in [studiobimo/.github](https://github.com/studiobimo/.github#baseline-and-validate):

- A draft, and the middle of a stack of pull requests, defer it. It runs when the pull request is
  marked ready, and a skipped `ci / validate` counts as passing.
- A pull request into `develop` or a stack layer narrows the tests to what changed
  (`AFFECTED_BASE`, `CI_FULL=false`); one into `main`, a push, a fork and a manual run with `full`
  run everything.
- The `ci:full` label runs everything now, whatever else is true. `make -C .devtools github`
  creates it ("Run the full CI now, with full test suites"), and the `repo-health-config-change`
  label that lets a reviewed pull request change an analyser's config.
- A profile lists in `FULL_CI_TARGETS` the targets that only a full run executes (browser suites, say);
  `ci` runs them unless `CI_FULL=false`.

`pr-events.yml` is its companion: a title edit re-checks the title, and adding `ci:full` or
retargeting the pull request dispatches `ci.yml` again. Both files stay as the template ships them;
the job in `ci.yml` has to be named `ci`.

A project with no profile validates with the base `ci` target, the duplication check. A profile adds
to it, and may ship its own `ci.yml`: the `vite-react-tanstack` profile's adds the caches its tools
fill, and the `java-gradle` profile's keeps the Gradle build as a separate `check` job. For a
project that opts in, sync takes the profile's file and ignores the template's. The template itself
validates with `.template/test.sh`.

#### Moving an existing project over

`sync` only writes files, so it does not delete what the template stopped shipping. After the sync
that brings `ci.yml` and `pr-events.yml`, delete `.github/workflows/pr-checks.yml` and
`.github/workflows/lint.yml` by hand: their work is in `ci / baseline`. Then change the
repository's required checks from `pr-checks / ...`, `lint / hooks` (and `check`, or `check / check`
for `java-gradle`) to `ci / baseline` and `ci / validate`. A `java-gradle` project keeps requiring
`check / check` as well, which is still its Gradle build.

### Profiles

Some files only make sense for one kind of project, so they are not in the template's root. A
profile is a second manifest, `.template/manifest.<name>`, with its files under
`.template/profiles/<name>/`. A project opts in by listing the name in a `.template-profiles`
file, and `sync`, `drift` and the weekly check then cover it too. Each manifest says what it
manages and what stays per project.

- **`java-gradle`**, for the Fabric and NeoForge mods: the Gradle convention plugins, CI, the
  Gradle Makefile targets and hooks, and the Dependabot and `.gitattributes` entries that go
  with them.
- **`typescript`**, for TypeScript services and libraries in one pnpm workspace: Turborepo under
  make (`turbo run` for build, typecheck and test, `--affected` for narrowed CI), the shared
  tsconfig, ESLint and Vitest configs, one Dockerfile for every service with Node pinned to
  `mise.toml`'s, and a generator that scaffolds `packages/contracts` (zod schemas and the
  `defineTopic` helper that validates at publish and at consume) and a first service:

  ```sh
  echo typescript >> .template-profiles
  make -C .devtools sync                      # then `include typescript.mk` in .devtools/Makefile
  node .devtools/typescript/gen.mjs workspace
  node .devtools/typescript/gen.mjs service <name>
  ```

- **`vite-react-tanstack`**, for a React app built with Vite, file-based TanStack Router,
  TanStack Query and Tailwind. It builds on `typescript`, which must be listed above it: that
  profile keeps the pnpm pin and release cooldown, CI, the strict tsconfig, ESLint and Vitest
  bases and the shared make targets. This one adds the Vite, Vitest, ESLint and TypeScript configs
  that the project's own config files extend, Prettier, the Makefile targets, hooks, a bundle
  budget, i18next with a lint rule against inline strings, the shadcn MCP server registered for
  Claude Code (`.mcp.json`) and Codex (`.codex/config.toml`), and the conventions in `AGENTS.md`.
  It does not choose a host.

  Its generator, `.devtools/scripts/gen.mjs`, writes everything a new project needs around it
  and installs the packages; after that it writes routes, features, components and hooks:

  ```sh
  printf "typescript\nvite-react-tanstack\n" >> .template-profiles
  make -C .devtools sync                      # then `include vite.mk` in .devtools/Makefile, after base.mk
  make -C .devtools setup
  node .devtools/scripts/gen.mjs app          # config, router and i18n wiring, packages, first build
  node .devtools/scripts/gen.mjs route '/invoices/$invoiceId'
  ```

  For a pnpm workspace, with either hosting profile below, tell it where the app lives before
  running `gen.mjs app`. It then writes the app there, and the shared tools to a `package.json`
  at the root:

  ```make
  # .devtools/Makefile
  APP_DIR := apps/web   # above `include vite.mk`
  ```

  ```yaml
  # pnpm-workspace.yaml, above the vite block
  packages:
    - apps/*
    - packages/*
  ```

  With several apps, list them in `APPS` (`APPS := apps/admin apps/site`). `build`, `typecheck`,
  `budget`, `clean` and the host's `types` and `deploy` then run for each, `ci` and `deploy.yml`
  with them, and `APP=apps/site` narrows one to a single app. A budget can be set per app
  (`BUNDLE_TOTAL_KIB@apps/site := 200`).

- **`cloudflare`**, a hosting profile for a `vite-react-tanstack` app: one Worker serves the
  client and answers `/api/*` with Hono, with its tests, types, a deploy target that builds
  for the environment it deploys to, and a workflow that deploys `develop` to development and
  each release to production (`DEPLOY_ENVS := production` in `.devtools/Makefile` drops
  development and `develop`). Apart from that workflow it manages only `.devtools/host/`,
  which the shared configs load when it exists, so adding it, or swapping it for another
  host later, leaves the project's own config files and `src/` alone:

  ```sh
  echo cloudflare >> .template-profiles
  make -C .devtools sync
  node .devtools/scripts/gen.mjs host         # wrangler.jsonc and worker/, then the packages
  ```

- **`gcp-infra`**, the Google Cloud project that every Cloud Run service shares, with no
  other profile needed: OpenTofu in `infra/` and its state bucket, Workload Identity Federation
  for the deploy workflow, the project's APIs (Cloud Run, Artifact Registry, Secret Manager,
  Pub/Sub, Vertex AI, Telemetry, Cloud Trace, Monitoring, Logging), a runtime account per
  service and environment that can write traces and metrics, and a budget.
  `DEPLOY_ENVS := production` in `.devtools/Makefile` drops development:

  ```sh
  echo gcp-infra >> .template-profiles
  make -C .devtools sync
  make -C .devtools infra-gen                 # a first infra/; then infra-bootstrap, infra-apply, infra-github
  ```

- **`gcp`**, the Node and Vite part, a hosting profile like `cloudflare`: one service, a Hono
  server on Node bundled into `dist/server`, serves the client and answers `/api/*`. It builds
  on `gcp-infra`, which is listed before it (`gcp` needs it), and adds the services to
  `infra/`, the make targets and a deploy workflow that ships `develop` to development and
  each release to production, with no key stored anywhere:

  ```sh
  printf 'gcp-infra\ngcp\n' >> .template-profiles   # after vite-react-tanstack
  make -C .devtools sync
  node .devtools/scripts/gen.mjs host         # server/, infra/ and the Dockerfile, then the packages
  ```

  A project that had `gcp` before `gcp-infra` existed lists `gcp-infra` above it and syncs: the
  blocks it moves keep their names, so they are updated in place.

## Tool versions

Every tool the hooks and CI run is pinned in `mise.toml`, with checksums in `mise.lock`. The shared
ones sit in the `base` block of `mise.toml`, so they are managed: the same linter at the same
version in every project.

Dependabot does not read `mise.toml`, so nothing bumps these on its own. `tools-outdated.yml` runs
weekly and keeps one `tools-outdated` issue open while a pin has a release a week old or more.
Bump them here, by hand:

```sh
mise outdated --bump            # what has a newer release
$EDITOR mise.toml               # change the version
make -C .devtools lock          # record the new checksums in mise.lock
make -C .devtools setup check   # install it and prove the hooks still pass
git add mise.toml mise.lock .mise/locks
```

Leave a release a week before taking it, as Dependabot's cooldown does for everything else. After
the template's next release, `make -C .devtools sync` in a project takes the new versions and
refreshes that project's own `mise.lock`. A project bumps its own tools, the ones outside the
block, the same way.

The branch and PR-size checks are not pinned this way. The hooks pull them from
`studiobimo/.github` at its floating `v1` tag, the one the workflows are called at, and lefthook
looks for a newer `v1` once a day.

## Changing something for every project

1. Change it here, in a PR. If it is a new file or block, add it to `.template/manifest`; nothing
   managed may contain the `init` placeholders.
2. Merge. release-please opens a release PR; merging that tags `vX.Y.Z`.
3. The next weekly drift run opens an issue in each project, or run `make -C .devtools sync`
   there straight away.

The rules themselves do not live here. The branch and PR-size checks are lefthook jobs in
`studiobimo/.github`, the commit rules are commitlint's conventional config, and CI is its reusable workflows; this template only wires them up.

## Working on the template

It is a working project, so its own CI (`ci.yml`, with `ci / validate` running `.template/test.sh`),
PR events and releases exercise every file it ships.

```sh
make -C .devtools setup
make -C .devtools check   # lint, plus .template/test.sh for the sync and init scripts
make -C .devtools ci      # what ci / validate runs here: .template/test.sh
```
