# Contributing

Thanks for helping! This project follows a few strict conventions, and tooling enforces them.

## Setup

1. Install **[mise](https://mise.jdx.dev/getting-started.html)** (`brew install mise`). It
   installs every other tool, at the version `mise.toml` pins.
2. Run `make -C .devtools setup`. This installs the pinned tools and the `pre-commit`, `commit-msg`
   and `pre-push` hooks, which [lefthook](https://lefthook.dev/) runs.
3. Run `make -C .devtools check` to confirm everything passes.

`make -C .devtools help` lists all targets.

## Project layout

| Path | Purpose |
| --- | --- |
| `.devtools/` | Makefile, the shared hooks (`lefthook-base.yml`), guard and sync scripts |
| `mise.toml`, `mise.lock` | Every tool the hooks and CI run, pinned with checksums |
| `lefthook.yml` | This project's own hooks, on top of the shared ones |
| `.github/` | Workflows (thin wrappers over `studiobimo/.github`), issue and PR templates |

<!-- >>> template:workflow -->
## Workflow

### Branches: [Conventional Branch](https://conventionalbranch.org/)

`<type>/<description>`, lowercase, with single hyphens. Types: `feature`/`feat`, `bugfix`/`fix`,
`hotfix`, `release`, `chore`, plus `claude`/`codex`/`ai` for agent-authored work.
Examples: `feat/short-description`, `fix/what-was-broken`.

### Commits: [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)

`<type>(<scope>): <summary>`. Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`,
`test`, `build`, `ci`, `chore`, `revert`. Breaking changes use `!` or a `BREAKING CHANGE:` footer.
The scopes this project uses are listed in `AGENTS.md` and enforced from `.commitlintrc.yaml`:
a scope is optional, but one that is not listed is rejected. The rest is
[commitlint's conventional config](https://github.com/conventional-changelog/commitlint/tree/master/%40commitlint/config-conventional):
a lowercase subject with no full stop, and at most 100 characters in the header and in each
body line.

PRs are **squash-merged**, so the **PR title** must also be a Conventional Commit.
It becomes the commit on `main` that release-please reads.

### Pull requests: at most 20 files

Keep every PR to **20 changed files or fewer**. Split larger work into a **stack**:

```sh
gh extension install github/gh-stack   # once
gh stack init feat/first-slice         # start a stack from main
# ...commit...
gh stack add feat/second-slice         # next layer on top
gh stack submit                        # push all layers and open linked PRs
gh stack sync                          # after a lower layer merges
```

Each layer is measured against the layer below it. The limit is enforced in the `pre-push` hook,
in CI, and for AI agents through a PreToolUse hook (`.devtools/scripts/agent-guard.sh`).

### Files the template manages

Some files, and the regions of others between `>>> template:<name>` and `<<< template:<name>`
markers, are kept in step with `studiobimo/project-template`. Change them there, not here; then
`make -C .devtools sync` brings the change in. `make -C .devtools drift` shows what differs, and a
weekly workflow opens an issue when something does. A deliberate difference goes in
`.template-ignore`, with a comment saying why.
<!-- <<< template:workflow -->

## Releases

[release-please](https://github.com/googleapis/release-please) maintains a release PR from the
Conventional Commits on `main`. Merging it tags a SemVer release and cuts the GitHub Release.
Never edit a version by hand. Until 1.0.0, breaking changes bump the minor version.

## Repository settings (maintainers)

`main` is protected by rulesets: PRs required, squash-only, linear history, and required checks
`pr-checks` and `lint`. They and the other repository settings are defined in `studiobimo/.github`.
`make -C .devtools github` applies them to this repository and needs `gh` signed in as an admin;
`make -C .devtools github CHECK=1` only shows what differs.
