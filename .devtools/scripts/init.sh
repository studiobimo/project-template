#!/usr/bin/env bash
# Turns a fresh copy of studiobimo/project-template into a project. Run once:
#
#   make -C .devtools init NAME="My Project" SLUG=my-project DESC="What it is."
#
# It fills in the placeholders, swaps the template's README for the starter one,
# resets the release state, and then removes everything that only the template
# needs -- .template/, the `template:init` regions, and this script. Last, it sets
# up the repository on GitHub (github-setup.sh); ENVS="staging production" also
# creates those deployment environments.
set -euo pipefail

name="${NAME:-}"
slug="${SLUG:-}"
desc="${DESC:-}"

die() {
    echo "✖ $*" >&2
    exit 1
}

root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git repository"
cd "${root}"

[[ -d .template ]] || die "no .template/ here: this project is already initialised"
[[ -n "${name}" && -n "${slug}" && -n "${desc}" ]] \
    || die 'usage: make -C .devtools init NAME="My Project" SLUG=my-project DESC="What it is."'
[[ "${slug}" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] \
    || die "SLUG must be kebab-case (lowercase letters, digits, single hyphens): ${slug}"

mv .template/README.md README.md
rm -rf .template
rm -f CHANGELOG.md .template-version
printf '{\n  ".": "0.0.0"\n}\n' >.release-please-manifest.json

files=()
while IFS= read -r f; do
    [[ -f "${f}" ]] || continue
    case "${f}" in
        .devtools/uv.lock | .devtools/scripts/init.sh | *.png | *.jpg | *.zip) continue ;;
    esac
    files+=("${f}")
done < <(git ls-files --cached --others --exclude-standard)

# Drop the regions that only make sense in the template itself (and the blank line
# before each, so no file is left with a double gap), then fill in the placeholders.
NAME="${name}" SLUG="${slug}" DESC="${desc}" perl -0pi -e '
    s/(?:^\n)?^[^\n]*>>> template:init.*?<<< template:init[^\n]*\n//msg;
    s/\QProject Name\E/$ENV{NAME}/g;
    s/\Qproject-slug\E/$ENV{SLUG}/g;
    s/\QOne-line project description.\E/$ENV{DESC}/g;
' "${files[@]}"

rm -- .devtools/scripts/init.sh

echo "✔ ${name} (${slug}) is initialised."
echo

# The files are done either way, so a GitHub failure is reported and not fatal.
if ! DESC="${desc}" ENVS="${ENVS:-}" .devtools/scripts/github-setup.sh; then
    echo "✖ GitHub is not set up. Fix the above, then: make -C .devtools github" >&2
fi

# main only takes pull requests once the rulesets are on, so the first commit is one.
cat <<MSG

    Next:
    make -C .devtools setup    # pinned tools + git hooks
    make -C .devtools check    # confirm everything passes
    git switch -c chore/initialise-project
    git add -A && git commit -m "chore: initialise from project-template"
    git push -u origin HEAD && gh pr create --fill

    Then fill in AGENTS.md (Project, Layout, Conventions) and README.md.
MSG
