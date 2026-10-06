#!/usr/bin/env bash
set -euo pipefail

template="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0

expect() {
    local want="$1" what="$2" got=0
    shift 2
    "$@" >"${work}/out" 2>&1 || got=$?
    if [[ "${got}" == "${want}" ]]; then
        echo "✔ ${what}"
    else
        echo "✖ ${what}: expected exit ${want}, got ${got}" >&2
        sed 's/^/    /' "${work}/out" >&2
        failures=$((failures + 1))
    fi
}

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

# Keep the developer's own git config and any hooks out of the fixtures.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
unset TEMPLATE_REPO NAME SLUG DESC

copy() {
    mkdir -p "$1"
    (cd "${template}" && git ls-files -z --cached --others --exclude-standard) \
        | (cd "${template}" && tar --null -T - -cf -) | tar -xf - -C "$1"
    git -C "$1" init --quiet --initial-branch=main
    git -C "$1" add -A
    git -C "$1" commit --quiet -m 'chore: copy of the template'
}

echo "template-sync"
src="${work}/src"
repo="${work}/repo"
copy "${src}"
copy "${repo}"
cd "${repo}"
sync=(.devtools/scripts/template-sync.sh --from "${src}" --ref v9.9.9)

expect 0 "a fresh copy is in step" "${sync[@]}" --check

echo "# edited locally" >>lychee.toml
expect 1 "an edited managed file is drift" "${sync[@]}" --check
expect 0 "sync restores it" "${sync[@]}"
expect 0 "and the copy is in step again" "${sync[@]}" --check
expect 0 "sync records the template version" grep -qx v9.9.9 .template-version

chmod -x .devtools/scripts/agent-guard.sh
expect 1 "a lost executable bit is drift" "${sync[@]}" --check
expect 0 "sync restores the bit" "${sync[@]}"
expect 0 "the script is executable again" test -x .devtools/scripts/agent-guard.sh

rm CLAUDE.md
expect 1 "a missing managed file is drift" "${sync[@]}" --check
expect 0 "sync recreates it" "${sync[@]}"

printf '\n# Project\nbuild/\n' >>.gitignore
expect 0 "edits outside a block are the project's" "${sync[@]}" --check
sed -i.bak 's/^Thumbs\.db$/Thumbs.db.edited/' .gitignore && rm .gitignore.bak
expect 1 "an edit inside a block is drift" "${sync[@]}" --check
expect 0 "sync rewrites the block" "${sync[@]}"
expect 0 "the block is the template's again" grep -qx 'Thumbs.db' .gitignore
expect 0 "and the project's lines survived" grep -qx 'build/' .gitignore

sed -i.bak '/template:base/d' .gitattributes && rm .gitattributes.bak
expect 1 "a block without its markers is drift" "${sync[@]}" --check
expect 0 "sync appends the block" "${sync[@]}"
expect 0 "in step once the markers are back" "${sync[@]}" --check

echo "# edited locally" >>lychee.toml
printf '# We check extra hosts here.\nlychee.toml\n' >.template-ignore
expect 0 ".template-ignore exempts a path" "${sync[@]}" --check
expect 0 "sync leaves an ignored path alone" "${sync[@]}"
expect 0 "the local edit is still there" grep -q 'edited locally' lychee.toml

newer="${work}/newer"
cp -R "${src}" "${newer}"
{
    sed -n '1p' "${src}/.devtools/scripts/template-sync.sh"
    printf '# padding %s\n' {1..40}
    sed '1d' "${src}/.devtools/scripts/template-sync.sh"
} >"${newer}/.devtools/scripts/template-sync.sh"
expect 0 "sync survives replacing itself" .devtools/scripts/template-sync.sh --from "${newer}" --ref v9.9.9
expect 0 "and is in step afterwards" .devtools/scripts/template-sync.sh --check --from "${newer}" --ref v9.9.9
expect 0 "back on the released script" "${sync[@]}"

expect 2 "a directory that is not the template is an error, not drift" \
    .devtools/scripts/template-sync.sh --check --from "${work}"
expect 2 "an unknown flag is an error" .devtools/scripts/template-sync.sh --nope

echo "init"
proj="${work}/proj"
copy "${proj}"
cd "${proj}"
expect 1 "refuses without a name" env SLUG=my-project DESC=x .devtools/scripts/init.sh
expect 1 "refuses a slug that is not kebab-case" \
    env NAME=x SLUG=My_Project DESC=x .devtools/scripts/init.sh
expect 0 "initialises a project" \
    env NAME="My Project" SLUG=my-project DESC="Does one thing & does it well." .devtools/scripts/init.sh
expect 0 "names the project" grep -qx '# My Project' README.md
expect 0 "keeps punctuation in the description" grep -qxF 'Does one thing & does it well.' README.md
expect 1 "leaves no placeholder behind" \
    grep -rIl --exclude-dir=.git -e 'Project Name' -e 'project-slug' -e 'One-line project description' .
expect 1 "leaves no init region behind" grep -rIl --exclude-dir=.git 'template:init' .
expect 1 "removes .template/" test -e .template
expect 1 "removes itself" test -e .devtools/scripts/init.sh
expect 1 "removes the template-only make targets" grep -q '^init:\|^test:' .devtools/Makefile
expect 1 "refuses to run twice" env NAME=x SLUG=x DESC=x "${template}/.devtools/scripts/init.sh"
expect 0 "is born in step with the template" \
    .devtools/scripts/template-sync.sh --check --from "${src}" --ref v9.9.9

if ((failures > 0)); then
    echo "${failures} failed" >&2
    exit 1
fi
echo "All passed"
