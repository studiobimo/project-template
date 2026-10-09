# studiobimo/project-template

[![Lint](https://github.com/studiobimo/project-template/actions/workflows/lint.yml/badge.svg?branch=main)](https://github.com/studiobimo/project-template/actions/workflows/lint.yml)
[![Release](https://github.com/studiobimo/project-template/actions/workflows/release.yml/badge.svg?branch=main)](https://github.com/studiobimo/project-template/actions/workflows/release.yml)

The starting point for a new [studiobimo](https://github.com/studiobimo) repository, whatever it
is written in. It carries the parts every project shares and nothing about any one language:

- **Dev tooling** under `.devtools/`: one Makefile entry point, tools pinned with uv, and
  pre-commit hooks for secrets, workflows, shell, Markdown, typos and links.
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

`init` fills in the placeholders, swaps this README for a starter one, and deletes itself and
`.template/`. Then add the language: build files, the project's own Makefile targets and
pre-commit hooks, a CI workflow, and the Project, Layout and Conventions sections of `AGENTS.md`.

## Staying in step

A template only helps on day one unless something keeps the copies honest. Every file here is one
of three kinds, and [`.template/manifest`](.template/manifest) says which:

| Kind | Examples | After day one |
| --- | --- | --- |
| **Managed file** | `.devtools/base.mk`, `agent-guard.sh`, `.codex/*`, `pr-checks.yml` | Identical everywhere. `sync` overwrites it. |
| **Managed block** | the `base` region of `.gitignore`, the rules in `AGENTS.md` | Identical between its `>>> template:<name>` and `<<< template:<name>` markers. The rest of the file is the project's. |
| **Seeded** | `README.md`, `.devtools/Makefile`, `.pre-commit-config.yaml`, `release.yml` | The project's. Never compared. |

In a project:

```sh
make -C .devtools drift   # what differs from the latest template release
make -C .devtools sync    # take the template's version of every managed file and block
```

Each project also runs `template-drift.yml` weekly. It keeps one issue labelled `template-drift`
open while anything differs, rewrites it as that changes, and closes it when the repo is back in
step. A project that has to differ on purpose lists the path in `.template-ignore`.

Tool versions are deliberately not managed: Dependabot bumps the pre-commit `rev:`s and
`uv.lock` in each repo on its own schedule, so comparing them would report drift every week.

## Changing something for every project

1. Change it here, in a PR. If it is a new file or block, add it to `.template/manifest`; nothing
   managed may contain the `init` placeholders.
2. Merge. release-please opens a release PR; merging that tags `vX.Y.Z`.
3. The next weekly drift run opens an issue in each project, or run `make -C .devtools sync`
   there straight away.

The rules themselves do not live here. Commit, branch and PR-size checks are pre-commit hooks in
`studiobimo/.github`, and CI is its reusable workflows; this template only wires them up.

## Working on the template

It is a working project, so its own lint, PR checks and releases exercise every file it ships.

```sh
make -C .devtools setup
make -C .devtools check   # lint, plus .template/test.sh for the sync and init scripts
```
