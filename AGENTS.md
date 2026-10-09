# Agent guide: Project Name

<!-- >>> template:init -->
> **This is the template itself**, not a project. Its job is to be copied: see
> [README.md](README.md) for how, and `.template/manifest` for which files it keeps in step
> across projects. `make -C .devtools init` replaces this note and the placeholders below.
<!-- <<< template:init -->

Instructions for AI coding agents (Codex, Claude Code, and others) working in this repo.
`CLAUDE.md` only points here, so this file is the single source for every agent.

## Project

One-line project description.

<!-- Two or three sentences an agent needs before touching anything: what this is, what it is
built with, and where most of the code lives. Then the pointers below. -->

- What it is and how to use it: `README.md`
- Workflow and conventions in full: `CONTRIBUTING.md`
- Commit scopes: `build`, `ci`, `docs`, `deps`, `devtools`. `.commitlintrc.yaml` enforces this
  list, so add a scope in both places.

## Layout

```text
.devtools/               Makefile (project targets), base.mk (shared targets), lefthook-base.yml (shared hooks)
  scripts/               agent-guard.sh, template-sync.sh, github-setup.sh, and this project's own scripts
.github/workflows/       thin wrappers over studiobimo/.github reusable workflows
.claude/  .codex/        agent settings and the PreToolUse hook that runs agent-guard.sh
mise.toml  mise.lock     every tool the hooks and CI run, pinned; .mise/locks/ belongs with them
lefthook.yml             this project's hooks, on top of the shared ones
.commitlintrc.yaml       commit rules: commitlint's conventional config plus this project's scopes
AGENTS.md  CLAUDE.md     this guide; CLAUDE.md only imports it
```

<!-- Add the project's own directories above, one line each: path, then what lives there. -->

<!-- >>> template:rules -->
## Non-negotiables

These hold in every studiobimo repo. Git hooks, CI and an agent hook all enforce them, so a
violation is caught before it is reviewed.

- **Commits:** [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/),
  `<type>(<scope>): <summary>`. PRs are squash-merged, so the **PR title** must be one too.
  commitlint checks both against its conventional config: a lowercase summary with no full stop,
  at most 100 characters in the header and in each body line, and a scope from the project's list.
- **Branches:** [Conventional Branch](https://conventionalbranch.org/), `<type>/<description>`
  in lowercase with single hyphens, e.g. `feat/short-description`. Agents may use `claude/…` or
  `codex/…`.
- **PR size:** at most 20 changed files. Split bigger work with `gh stack`
  (`gh stack init`, `gh stack add`, `gh stack submit`).
- **Versioning:** SemVer, managed by release-please. Never edit a version, a
  `.release-please-manifest.json` or a `CHANGELOG.md` by hand.
- **Pinning:** third-party GitHub Actions are pinned to full commit SHAs with the version in a
  comment; studiobimo's own reusable workflows are called at `@v1`. Every tool is pinned in
  `mise.toml` and locked in `mise.lock`. Dependabot does not read `mise.toml`: a tool is bumped by
  hand, then `make -C .devtools lock`, and `mise.toml`, `mise.lock` and `.mise/locks/` are
  committed together.
- **Workflows:** `permissions: {}` at the top, the minimum per job, `persist-credentials: false`
  on every checkout, secrets passed explicitly and never with `secrets: inherit`.
- **Say what you tested.** State what you ran and what it showed. If something could not be
  tested, say so plainly rather than implying it was.

A PreToolUse hook (`.devtools/scripts/agent-guard.sh`) blocks `gh pr create`, `gh stack submit`
and `git push` when the PR-size rule is violated, and blocks non-conventional branch names.

## Where shared things live

Some files here are not this repo's to edit. Changing them locally only creates drift, which a
weekly workflow reports as an issue.

| To change | Edit it in | It reaches this repo by |
| --- | --- | --- |
| CI behaviour (lint, PR checks, release) | `studiobimo/.github`, `.github/workflows/` | the `@v1` tag moving |
| Branch and PR-size rules | `studiobimo/.github`, `.devtools/` | the `@v1` tag moving; lefthook refetches it daily |
| Shared hooks and tool versions | `studiobimo/project-template` | `make -C .devtools sync` |
| Files and blocks listed in the template's `.template/manifest`, and in the manifest of each profile in `.template-profiles` | `studiobimo/project-template` | `make -C .devtools sync` |

A managed block sits between `>>> template:<name>` and `<<< template:<name>` marker lines, like
this section. Edit outside the markers freely; inside them, change the template instead. If a
difference is deliberate, list the path in `.template-ignore` with a comment saying why.
<!-- <<< template:rules -->

## Commands

```sh
make -C .devtools setup   # once: pinned tools + git hooks
make -C .devtools check   # everything CI runs
make -C .devtools lint    # the pre-commit hook, on every file
make -C .devtools lock    # after changing a pinned version
make -C .devtools drift   # where this repo differs from the template
make -C .devtools sync    # pull the template's managed files
make -C .devtools github  # apply the org's GitHub settings and rulesets (CHECK=1 to compare)
make -C .devtools help    # all targets
```

## Conventions

<!-- What an agent cannot infer from the code: formatting it must not hand-apply, invariants,
where tests go, what cannot be tested locally. Keep each to one or two lines. -->
