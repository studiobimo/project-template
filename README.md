# studiobimo/project-template

[![Lint](https://github.com/studiobimo/project-template/actions/workflows/lint.yml/badge.svg?branch=main)](https://github.com/studiobimo/project-template/actions/workflows/lint.yml)
[![Release](https://github.com/studiobimo/project-template/actions/workflows/release.yml/badge.svg?branch=main)](https://github.com/studiobimo/project-template/actions/workflows/release.yml)

The starting point for a new [studiobimo](https://github.com/studiobimo) repository, whatever it
is written in. It carries the parts every project shares and nothing about any one language:

- **Dev tooling**: one Makefile entry point under `.devtools/`, every tool pinned with
  [mise](https://mise.jdx.dev/), and [lefthook](https://lefthook.dev/) hooks for secrets,
  workflows, shell, Markdown, typos and links.
- **Conventions, enforced**: Conventional Commits and Branch names, a 20-file PR limit, in git
  hooks, in CI, and for AI agents before they act.
- **CI and releases** as thin wrappers over
  [studiobimo/.github](https://github.com/studiobimo/.github): lint, PR checks, release-please.
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

- the description, from `DESC`, and any deployment environments named in `ENVS="staging production"`;
- the settings every studiobimo repository shares: squash-only merges, Actions and workflow
  permissions, secret scanning and Dependabot alerts, and the rulesets that protect `main` and
  release tags. Those are defined once in [studiobimo/.github](https://github.com/studiobimo/.github)
  and applied by its script, so nothing here copies them.

The GitHub half can be repeated at any time: `make -C .devtools github` applies it again, and
`make -C .devtools github CHECK=1` only shows what differs. Once the rulesets are on, `main` takes
pull requests only, so the initialising commit goes up as one; `init` prints the commands.

Then add the language: build files, the project's own Makefile targets, tools in `mise.toml`
and jobs in `lefthook.yml`, a CI workflow, and the Project, Layout and Conventions sections of `AGENTS.md`.

## Staying in step

A template only helps on day one unless something keeps the copies honest. Every file here is one
of three kinds, and [`.template/manifest`](.template/manifest) says which:

| Kind | Examples | After day one |
| --- | --- | --- |
| **Managed file** | `.devtools/base.mk`, `.devtools/lefthook-base.yml`, `agent-guard.sh`, `github-setup.sh`, `.codex/*`, `pr-checks.yml` | Identical everywhere. `sync` overwrites it. |
| **Managed block** | the `base` region of `.gitignore`, the shared tools in `mise.toml`, the rules in `AGENTS.md` | Identical between its `>>> template:<name>` and `<<< template:<name>` markers. The rest of the file is the project's. |
| **Seeded** | `README.md`, `.devtools/Makefile`, `.commitlintrc.yaml`, `release.yml` | The project's. Never compared. |

In a project:

```sh
make -C .devtools drift   # what differs from the latest template release
make -C .devtools sync    # take the template's version of every managed file and block
```

Each project also runs `template-drift.yml` weekly. It keeps one issue labelled `template-drift`
open while anything differs, rewrites it as that changes, and closes it when the repo is back in
step. A project that has to differ on purpose lists the path in `.template-ignore`.

## Tool versions

Every tool the hooks and CI run is pinned in `mise.toml`, with checksums in `mise.lock`. The shared
ones sit in the `base` block of `mise.toml`, so they are managed: the same linter at the same
version in every project.

Dependabot does not read `mise.toml`, so nothing bumps these on its own. Bump them here, by hand:

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

It is a working project, so its own lint, PR checks and releases exercise every file it ships.

```sh
make -C .devtools setup
make -C .devtools check   # lint, plus .template/test.sh for the sync and init scripts
```
