#!/usr/bin/env bash
set -euo pipefail

template="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# The names and placeholders the scripts use, so a test never spells one differently.
# shellcheck source=.devtools/scripts/strings.sh
. "${template}/.devtools/scripts/strings.sh"
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
unset TEMPLATE_REPO SETTINGS_REPO NAME SLUG DESC ENVS

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

printf '# >>> template:baseline\nours\n# <<< template:baseline\n' >>.gitignore
expect 0 "a block whose name only starts like a managed one is the project's" "${sync[@]}" --check
sed -i.bak '/<<< template:base$/d' .gitignore && rm .gitignore.bak
expect 1 "a block that lost its end marker is drift" "${sync[@]}" --check
expect 2 "which sync refuses to rewrite" "${sync[@]}"
expect 0 "so the project's lines after it survive" grep -qx 'build/' .gitignore
git checkout --quiet -- .gitignore
sed -n '/>>> template:base$/,/<<< template:base$/p' .gitignore >"${work}/block"
cat "${work}/block" >>.gitignore
expect 1 "a block that appears twice is drift" "${sync[@]}" --check
expect 2 "which sync refuses to rewrite" "${sync[@]}"
git checkout --quiet -- .gitignore

echo "# edited locally" >>lychee.toml
printf '# We check extra hosts here.\nlychee.toml\n' >.template-ignore
expect 0 ".template-ignore exempts a path" "${sync[@]}" --check
expect 0 "sync leaves an ignored path alone" "${sync[@]}"
expect 0 "the local edit is still there" grep -q 'edited locally' lychee.toml
printf 'lychee.toml  # we check extra hosts here' >.template-ignore
expect 0 "so does a path with its reason beside it, on a last line with no newline" "${sync[@]}" --check

echo "# edited locally" >>.devtools/scripts/agent-guard.sh
printf '# We check extra hosts here.\nlychee.toml\n# ours\n.devtools/scripts/agent-guard.sh\n' >.template-ignore
expect 1 "a required path in .template-ignore is drift" "${sync[@]}" --check
expect 0 "sync applies a required entry anyway" "${sync[@]}"
expect 1 "so the local edit is gone" grep -q 'edited locally' .devtools/scripts/agent-guard.sh
expect 1 "and the ignore line stays drift until it goes" "${sync[@]}" --check
printf '# We check extra hosts here.\nlychee.toml\n' >.template-ignore
expect 0 "in step once it has gone" "${sync[@]}" --check

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

# Profiles: a second manifest, read from its own directory, switched on by .template-profiles.
rm -f .template-ignore
expect 0 "back in step before the profile cases" "${sync[@]}"
prof="${work}/prof"
cp -R "${src}" "${prof}"
mkdir -p "${prof}/.template/profiles/fixture"
printf '# a profile for the tests\nfile   fixture.txt\nblock  cfg.yml  extra\n' >"${prof}/.template/manifest.fixture"
printf 'from the profile\n' >"${prof}/.template/profiles/fixture/fixture.txt"
printf '# >>> template:extra\nkey: value\n# <<< template:extra\n' >"${prof}/.template/profiles/fixture/cfg.yml"
psync=(.devtools/scripts/template-sync.sh --from "${prof}" --ref v9.9.9)

expect 0 "a profile nobody opted in to is ignored" "${psync[@]}" --check
printf '# opted in\n\nfixture\n' >.template-profiles
expect 1 "an opted-in profile's missing file is drift" "${psync[@]}" --check
expect 0 "sync brings in the profile's file and block" "${psync[@]}"
expect 0 "the file is the profile's" grep -qx 'from the profile' fixture.txt
expect 0 "the block was created" grep -qx 'key: value' cfg.yml
expect 0 "and the copy is in step" "${psync[@]}" --check

echo 'edited locally' >>fixture.txt
expect 1 "an edited profile file is drift" "${psync[@]}" --check
expect 0 "sync restores it" "${psync[@]}"
sed -i.bak 's/^key: value$/key: other/' cfg.yml && rm cfg.yml.bak
expect 1 "an edited profile block is drift" "${psync[@]}" --check
expect 0 "sync rewrites it" "${psync[@]}"
expect 0 "the block is the profile's again" grep -qx 'key: value' cfg.yml

echo 'edited locally' >>fixture.txt
printf '# ours\nfixture.txt\n' >.template-ignore
expect 0 ".template-ignore exempts a path inside a profile" "${psync[@]}" --check
rm .template-ignore
expect 0 "sync puts it right again" "${psync[@]}"

printf 'file   fixture.txt\nblock  cfg.yml  extra  required\n' >"${prof}/.template/manifest.fixture"
sed -i.bak 's/^key: value$/key: other/' cfg.yml && rm cfg.yml.bak
printf '# ours\ncfg.yml\n' >.template-ignore
expect 1 "a required block cannot be ignored either" "${psync[@]}" --check
expect 0 "sync rewrites it anyway" "${psync[@]}"
expect 0 "the block is the profile's again" grep -qx 'key: value' cfg.yml
rm .template-ignore
printf 'file   fixture.txt  optional\n' >"${prof}/.template/manifest.fixture"
expect 2 "an unknown flag in a manifest is an error" "${psync[@]}" --check
printf 'block  cfg.yml  required\n' >"${prof}/.template/manifest.fixture"
expect 2 "a block needs a name before its flag" "${psync[@]}" --check

echo nope >.template-profiles
expect 2 "a profile the template does not have is an error, not drift" "${psync[@]}" --check
echo '../src' >.template-profiles
expect 2 "a profile name that is not a name is an error" "${psync[@]}" --check
printf 'nope' >.template-profiles
expect 2 "even on a last line with no newline" "${psync[@]}" --check
rm .template-profiles fixture.txt cfg.yml

# Every profile the template ships: each file it lists exists, each block has its markers.
in_repo() { (cd "$1" && shift && "$@"); }
for manifest in "${src}"/.template/manifest.*; do
    name="${manifest##*/manifest.}"
    copy "${work}/profile-${name}"
    echo "${name}" >"${work}/profile-${name}/.template-profiles"
    expect 0 "the ${name} profile syncs into a project" \
        in_repo "${work}/profile-${name}" .devtools/scripts/template-sync.sh --from "${src}" --ref v9.9.9
    expect 0 "and the project is in step with it" \
        in_repo "${work}/profile-${name}" .devtools/scripts/template-sync.sh --check --from "${src}" --ref v9.9.9
done

echo "vite-react-tanstack generator"
vite="${work}/profile-vite-react-tanstack"
gen() { (cd "${vite}" && mise exec -- node .devtools/scripts/gen.mjs "$@"); }
routes="${vite}/src/routes"
# shellcheck disable=SC2016 # $invoiceId is the route parameter, for gen.mjs, not the shell
expect 0 "writes a route" gen route '/invoices/$invoiceId'
expect 0 "named by its id" grep -qF "createFileRoute('/invoices/\$invoiceId')" "${routes}/invoices/\$invoiceId.tsx"
expect 0 "writes an index route for a trailing slash" gen route /settings/
expect 0 "whose id keeps the slash" grep -qF "createFileRoute('/settings/')" "${routes}/settings/index.tsx"
expect 0 "writes the root index route" gen route /
expect 0 "as index.tsx" grep -qF "createFileRoute('/')" "${routes}/index.tsx"
expect 0 "writes a route in a group" gen route '/(marketing)/pricing'
expect 0 "whose id keeps the group" grep -qF "createFileRoute('/(marketing)/pricing')" "${routes}/(marketing)/pricing.tsx"
expect 1 "refuses to overwrite a route" gen route /settings/
expect 1 "refuses a path that climbs out of src/routes" gen route /a/../b
expect 1 "refuses a feature route before the feature" gen route /invoices --feature invoices
mkdir -p "${vite}/src/locales/en" "${vite}/src/locales/es"
expect 0 "writes a feature" gen feature invoices
expect 0 "with its query options" test -f "${vite}/src/features/invoices/queries.ts"
expect 0 "and its strings, in every language" \
    test -f "${vite}/src/locales/en/invoices.json" -a -f "${vite}/src/locales/es/invoices.json"
expect 0 "which its page reads through t()" \
    grep -qF "useTranslation('invoices')" "${vite}/src/features/invoices/invoices-page.tsx"
expect 0 "and then a route that loads it" gen route /invoices --feature invoices
expect 0 "through the route's loader" grep -qF 'ensureQueryData(invoicesQueryOptions())' "${routes}/invoices.tsx"
rm "${vite}/src/features/invoices/invoices-page.tsx"
expect 1 "refuses a feature when any of its files is taken" gen feature invoices
expect 1 "and writes none of them" test -f "${vite}/src/features/invoices/invoices-page.tsx"
expect 1 "refuses an unknown generator" gen nope
expect 1 "refuses host files without a hosting profile" gen host --no-install
cp -R "${work}/profile-cloudflare/.devtools/host" "${vite}/.devtools/"
expect 0 "writes the hosting profile's files" gen host --no-install
expect 0 "naming the Worker after the project" \
    grep -qF '"name": "profile-vite-react-tanstack"' "${vite}/wrangler.jsonc"
expect 0 "with both environments by default" \
    grep -qF '"development": {}' "${vite}/wrangler.jsonc"
rm -r "${vite}/wrangler.jsonc" "${vite}/worker" "${vite}/.dev.vars.example"
printf 'DEPLOY_ENVS := production # no develop branch\n' >>"${vite}/.devtools/Makefile"
gen_from_src() { (cd "${vite}/src" && mise exec -- node ../.devtools/scripts/gen.mjs "$@"); }
expect 0 "writes only the environments DEPLOY_ENVS lists, from any directory" gen_from_src host --no-install
expect 1 "without development" grep -qF '"development"' "${vite}/wrangler.jsonc"
expect 0 "keeping production" grep -qF '"production": {}' "${vite}/wrangler.jsonc"
printf 'DEPLOY_ENVS := production # no develop branch\ninclude base.mk\ninclude vite.mk\n' >"${vite}/.devtools/production.mk"
production() { make -s -C "${vite}/.devtools" -f production.mk "$@"; }
expect 2 "and refuses to deploy to development" production deploy ENV=development
listed_envs() { [[ "$(production deploy-envs)" == production ]]; }
usage_of_deploy() { local out; out="$(production deploy ENV=development 2>&1)" || true; [[ "${out}" == *"ENV=production"$'\n'* ]]; }
expect 0 "listing production for deploy.yml" listed_envs
expect 0 "with a usage that names only production" usage_of_deploy
mkdir -p "${work}/image"
printf '#!/bin/sh\necho "$%s"\n' IMAGE_NODE >"${work}/image/node"
printf '#!/bin/sh\necho "$%s"\n' IMAGE_PNPM >"${work}/image/pnpm"
chmod +x "${work}/image/node" "${work}/image/pnpm"
# image [VAR=value ...] <make args>: make as a build image with no mise runs it.
image() {
    local vars=()
    while [[ "$1" == *=* ]]; do vars+=("$1"); shift; done
    env -u GITHUB_REF_NAME PATH="${work}/image:${PATH}" ${vars[@]+"${vars[@]}"} \
        make -s -C "${vite}/.devtools" -f production.mk MISE=no-mise "$@"
}
pinned() { sed -n "s/^$1 = \"\(.*\)\"/\1/p" "${vite}/mise.toml"; }
runs_from_path() { local out; out="$(image -n build-app)"; [[ "${out}" == *"pnpm exec vite build"* && "${out}" != *"mise"* ]]; }
expect 0 "without mise, make runs the tools on the PATH" runs_from_path
expect 2 "and will not deploy with a node other than mise.toml's" \
    image IMAGE_NODE=1.0.0 IMAGE_PNPM="$(pinned pnpm)" deploy-tools
expect 2 "or a pnpm other than its" image IMAGE_NODE="$(pinned node)" IMAGE_PNPM=1.0.0 deploy-tools
expect 0 "but deploys with the ones it pins" \
    image IMAGE_NODE="$(pinned node)" IMAGE_PNPM="$(pinned pnpm)" deploy-tools
expect 0 "with mise, the image's versions are not checked" \
    env IMAGE_NODE=1.0.0 PATH="${work}/image:${PATH}" make -s -C "${vite}/.devtools" -f production.mk deploy-tools
git -C "${vite}" checkout --quiet --detach
expect 0 "a detached Workers Builds checkout ships from the branch it names" \
    image WORKERS_CI_BRANCH=main deploy-branch ENV=production
expect 2 "and only that branch" image WORKERS_CI_BRANCH=feat/thing deploy-branch ENV=production
git -C "${vite}" checkout --quiet main
rm -r "${vite}/.devtools/host" "${vite}/.devtools/production.mk"
cp -R "${work}/profile-gcp/.devtools/host" "${vite}/.devtools/"
expect 0 "writes another hosting profile's files" gen host --no-install
expect 0 "naming the Cloud Run service after the project" \
    grep -qF '"service": "profile-vite-react-tanstack"' "${vite}/infra/project.auto.tfvars.json"
expect 0 "with an image on the Node mise.toml pins" \
    grep -q "^FROM node:$(sed -n 's/^node = "\(.*\)"/\1/p' mise.toml)-" "${vite}/Dockerfile"
expect 0 "with a service for each environment DEPLOY_ENVS lists" \
    grep -qF 'environments = toset(["production"])' "${vite}/infra/main.tf"
expect 0 "and only those let in to deploy" \
    grep -qF "assertion.environment in ['production']" "${vite}/infra/deploy.tf"

echo "vite-react-tanstack bundle budget"
budget() { (cd "${vite}" && mise exec -- node .devtools/scripts/bundle-budget.mjs "$@"); }
expect 1 "fails before anything is built" budget --dir nothing-here
mkdir -p "${vite}/dist/assets" && echo 'console.log(1)' >"${vite}/dist/assets/app.js"
expect 0 "passes a bundle within its budget" budget
expect 1 "fails a chunk over its budget" budget --chunk-kib 0

echo "vite-react-tanstack in an app directory"
generated() {
    copy "$1"
    printf 'vite-react-tanstack\n%s\n' "${2:-cloudflare}" >"$1/.template-profiles"
    in_repo "$1" .devtools/scripts/template-sync.sh --from "${src}" --ref v9.9.9 >/dev/null
}
gen_in() { (cd "$1" && shift && mise exec -- node .devtools/scripts/gen.mjs "$@"); }
shop="${work}/acme-shop"
generated "${shop}"
printf 'APP_DIR := apps/web\n' >>"${shop}/.devtools/Makefile"
printf '# Acme Shop\n\nSells things.\n' >"${shop}/README.md"
expect 1 "refuses an app the workspace does not list" gen_in "${shop}" app --no-install
expect 1 "and writes nothing" test -e "${shop}/eslint.config.js"
cp "${shop}/pnpm-workspace.yaml" "${work}/no-packages"
{ printf 'packages:\n  - packages/*\n\n'; cat "${work}/no-packages"; } >"${shop}/pnpm-workspace.yaml"
expect 1 "or one that lists only other packages" gen_in "${shop}" app --no-install
{ printf 'packages:\n  - apps/*\n  - "!apps/web"\n\n'; cat "${work}/no-packages"; } >"${shop}/pnpm-workspace.yaml"
expect 1 "or leaves it out by name" gen_in "${shop}" app --no-install
{ printf 'packages:\n  - apps/*\n\n'; cat "${work}/no-packages"; } >"${work}/workspace"
cp "${work}/workspace" "${shop}/pnpm-workspace.yaml"
expect 0 "a packages: key above the blocks is in step" \
    in_repo "${shop}" .devtools/scripts/template-sync.sh --check --from "${src}" --ref v9.9.9
expect 0 "writes the app into APP_DIR" gen_in "${shop}" app --no-install
expect 0 "with the host's files beside it" test -f "${shop}/apps/web/worker/index.ts"
expect 0 "naming the Worker after the repository, not the app" \
    grep -qF '"name": "acme-shop"' "${shop}/apps/web/wrangler.jsonc"
expect 0 "and the app's package after both" \
    grep -qF '"name": "acme-shop-web"' "${shop}/apps/web/package.json"
expect 0 "reading the description from the repository's README" \
    grep -qF "description: 'Sells things.'" "${shop}/apps/web/src/config/site.ts"
expect 0 "reaching the shared Vite config from there" \
    grep -qF "'../../.devtools/vite/vite.ts'" "${shop}/apps/web/vite.config.ts"
expect 0 "and the shared tsconfig" \
    grep -qF '"../../.devtools/vite/tsconfig.base.json"' "${shop}/apps/web/tsconfig.app.json"
expect 0 "from the Worker's too" \
    grep -qF '"../../../.devtools/vite/tsconfig.base.json"' "${shop}/apps/web/worker/tsconfig.json"
expect 0 "and the shared ESLint rules" \
    grep -qF "{ app } from '../../.devtools/vite/eslint.js'" "${shop}/apps/web/eslint.config.js"
expect 0 "keeps a config at the root for what no package covers" \
    grep -qF "{ base } from './.devtools/vite/eslint.js'" "${shop}/eslint.config.js"
expect 0 "and Prettier's ignores" grep -qx 'apps/web/src/routeTree.gen.ts' "${shop}/.prettierignore"
expect 0 "and the launch config" test -f "${shop}/.claude/launch.json"
expect 0 "writes later files into APP_DIR too" gen_in "${shop}" feature invoices
expect 0 "beside the catalogs it found there" test -f "${shop}/apps/web/src/locales/en/invoices.json"
expect 0 "and routes that load them" gen_in "${shop}" route /invoices --feature invoices
expect 0 "at the app's own path" test -f "${shop}/apps/web/src/routes/invoices.tsx"

# make reads APP_DIR on either side of the include, as gen.mjs does. `types-app` is the host's.
runs_in_app() { make -n --no-print-directory -C "${shop}/.devtools" -f "$1" "$2" | grep -q 'cd .*/apps/web'; }
printf 'APP_DIR := apps/web\ninclude base.mk\ninclude vite.mk\n' >"${shop}/.devtools/above.mk"
printf 'include base.mk\ninclude vite.mk\nAPP_DIR := apps/web\n' >"${shop}/.devtools/below.mk"
expect 0 "make runs in APP_DIR when it is set above the include" runs_in_app above.mk dev
expect 0 "and when it is set below" runs_in_app below.mk dev
expect 0 "the host's recipes too" runs_in_app below.mk types-app
rm "${shop}/.devtools/above.mk" "${shop}/.devtools/below.mk"

# APPS lists several apps: the app-level targets run once for each, APP narrows them to one,
# and a budget can be set for a single app.
printf 'APPS := apps/web apps/site\nBUNDLE_TOTAL_KIB@apps/site := 200\ninclude base.mk\ninclude vite.mk\n' \
    >"${shop}/.devtools/many.mk"
many() { make -n --no-print-directory -C "${shop}/.devtools" -f many.mk "$@"; }
many_has() { many "${@:2}" | grep -q -- "$1"; }
for target in build typecheck budget types clean; do
    expect 0 "${target} runs for every app in APPS" many_has 'for app in apps/web apps/site' "${target}"
done
expect 0 "deploy does too" many_has 'for app in apps/web apps/site' deploy ENV=development
expect 0 "APP narrows a target to one app" many_has 'for app in apps/site;' build APP=apps/site
expect 0 "dev takes the first app" many_has 'cd .*/apps/web' dev
expect 0 "dev takes the app APP names" many_has 'cd .*/apps/site' dev APP=apps/site
expect 0 "one app's budget can differ" many_has '--total-kib 200' budget-app APP_DIR=apps/site
expect 0 "while the others keep the default" many_has '--total-kib 550' budget-app APP_DIR=apps/web
expect 0 "tests every package, not a list of them" many_has 'packages.mjs test' test
expect 0 "type-checks the packages that are not apps" \
    many_has 'packages.mjs typecheck apps/web apps/site' typecheck
expect 0 "and finds an app missing from APPS when it budgets" \
    many_has 'packages.mjs apps apps/web apps/site' budget
rm "${shop}/.devtools/many.mk"

# packages.mjs runs in a package and picks what to run from what the package has. vitest and
# tsc are stand-ins that record how they were called.
stubs="${work}/stubs"
mkdir -p "${stubs}"
for tool in vitest tsc; do
    cat >"${stubs}/${tool}" <<'EOF'
#!/bin/sh
echo "${0##*/}" "$@" >>"$CALLS"
EOF
    chmod +x "${stubs}/${tool}"
done
export CALLS="${work}/calls"
check() { # <directory> <task> [app...]
    local dir="${shop}/$1"
    shift
    : >"${CALLS}"
    (cd "${dir}" && PATH="${stubs}:${PATH}" mise exec -- node "${shop}/.devtools/scripts/packages.mjs" "$@")
}
ran() { grep -q -- "$1" "${CALLS}"; }
ran_nothing() { ! [[ -s "${CALLS}" ]]; }
mkdir -p "${shop}/packages/ui/src" "${shop}/packages/data/src" "${shop}/packages/docs"
touch "${shop}/packages/data/vitest.config.ts" "${shop}/packages/data/tsconfig.json" \
    "${shop}/packages/ui/tsconfig.json"

expect 0 "a package with a src/ and no config is tested" check packages/ui test
expect 0 "on the shared default" ran 'vitest run --config .*/.devtools/vite/vitest.default.ts'
expect 0 "even when it has no tests yet" ran '--passWithNoTests'
expect 0 "a package with a config is tested on it" check packages/data test
expect 0 "alone" ran '^vitest run$'
expect 0 "a package with no src/ is left alone" check packages/docs test
expect 0 "and runs nothing" ran_nothing
expect 0 "a package with a tsconfig.json is type-checked" check packages/ui typecheck apps/web
expect 0 "by tsc -b" ran '^tsc -b$'
rm "${shop}/packages/ui/tsconfig.json"
expect 1 "a package with a src/ and no tsconfig.json fails" check packages/ui typecheck apps/web
expect 0 "an app is left to typecheck-app" check apps/web typecheck apps/web
expect 0 "and runs nothing" ran_nothing
expect 0 "a package without a src/ is not type-checked" check packages/docs typecheck apps/web
expect 1 "an app missing from the list fails" check apps/web apps packages/ui
expect 0 "an app in it passes" check apps/web apps apps/web
expect 0 "so does a package with no vite.config.ts" check packages/ui apps apps/web
expect 1 "an unknown task fails" check packages/ui lint

flat="${work}/flat-shop"
generated "${flat}"
printf '# Flat Shop\n\n[![Lint](https://example.com/b.svg)](https://example.com)\n![Logo](logo.png)\n\nSells flat things.\n' \
    >"${flat}/README.md"
expect 0 "without APP_DIR the app stays at the root" gen_in "${flat}" app --no-install
expect 0 "past the README's badges for the description" \
    grep -qF "description: 'Sells flat things.'" "${flat}/src/config/site.ts"
expect 0 "with one package.json" grep -qF '"gen": "node .devtools/scripts/gen.mjs"' "${flat}/package.json"
expect 0 "the configs as they were" grep -qF 'defineConfig([app])' "${flat}/eslint.config.js"
expect 0 "and the paths" grep -qF "'./.devtools/vite/vite.ts'" "${flat}/vite.config.ts"
expect 0 "Worker's included" grep -qF '"../.devtools/vite/tsconfig.base.json"' "${flat}/worker/tsconfig.json"

run="${work}/run-shop"
generated "${run}" gcp
printf 'APP_DIR := apps/web\n' >>"${run}/.devtools/Makefile"
cp "${work}/workspace" "${run}/pnpm-workspace.yaml"
expect 0 "writes the Cloud Run server into APP_DIR" gen_in "${run}" app --no-install
expect 0 "reaching the shared tsconfig from there" \
    grep -qF '"../../../.devtools/vite/tsconfig.base.json"' "${run}/apps/web/server/tsconfig.json"
expect 0 "and keeps what deploys it at the root" test -f "${run}/infra/main.tf"
expect 0 "with both environments by default" \
    grep -qF 'environments = toset(["development", "production"])' "${run}/infra/main.tf"
expect 0 "with an image of the app's build" grep -qx 'COPY apps/web/dist ./dist' "${run}/Dockerfile"
expect 0 "and that build let back in, parent by parent" \
    grep -qx '!/apps/web/dist/' "${run}/.gcloudignore"
expect 0 "from the first of them" grep -qx '/apps/\*' "${run}/.gcloudignore"
flat_run="${work}/flat-run"
generated "${flat_run}" gcp
printf '# Flat Run\n\n[![Lint](https://example.com/b.svg)](https://example.com)\n' >"${flat_run}/README.md"
expect 0 "and without APP_DIR the server stays at the root" gen_in "${flat_run}" app --no-install
expect 0 "with the image as it was" grep -qx 'COPY dist ./dist' "${flat_run}/Dockerfile"
expect 0 "and the upload" grep -qx '!/dist/' "${flat_run}/.gcloudignore"
expect 0 "a README of only badges falls back to the name" \
    grep -qF "description: 'Flat Run'" "${flat_run}/src/config/site.ts"

# A pnpm that records what gen.mjs installs. It goes first on the PATH mise exec builds.
mkdir -p "${work}/recording"
cat >"${work}/recording/pnpm" <<'PNPM'
#!/usr/bin/env bash
echo "$*" >>"${PNPM_LOG}"
PNPM
chmod +x "${work}/recording/pnpm"
export PNPM_LOG="${work}/pnpm.log"
installed="${work}/installed-shop"
generated "${installed}"
printf 'APP_DIR := apps/web\n' >>"${installed}/.devtools/Makefile"
cp "${work}/workspace" "${installed}/pnpm-workspace.yaml"
gen_recording() {
    # shellcheck disable=SC2016 # $1 and PATH are for the inner shell, after mise has set PATH
    (cd "${installed}" && mise exec -- bash -c 'PATH="$1:${PATH}" node .devtools/scripts/gen.mjs app' _ "${work}/recording")
}
expect 0 "installs a workspace's app" gen_recording
expect 0 "with tailwindcss in the app's package, where shadcn looks" \
    grep -qE '^add --save-dev [^-].* tailwindcss( |$)' "${PNPM_LOG}"
expect 0 "and at the root, beside its Vite plugin" \
    grep -qE '^add --save-dev --workspace-root .* tailwindcss( |$)' "${PNPM_LOG}"

expect 2 "a directory that is not the template is an error, not drift" \
    .devtools/scripts/template-sync.sh --check --from "${work}"
expect 2 "an unknown flag is an error" .devtools/scripts/template-sync.sh --nope
expect 2 "and so is a flag without its value" .devtools/scripts/template-sync.sh --from
expect 0 "--help prints the usage" .devtools/scripts/template-sync.sh --help
cp "${work}/out" "${work}/help.out"
expect 0 "from the script's header" grep -q '^Usage: template-sync.sh' "${work}/help.out"

echo "github-setup"
# A gh that answers from GH_REPO_JSON and records every call that would change something.
mkdir -p "${work}/bin" "${work}/settings/.devtools"
cat >"${work}/bin/gh" <<'GH'
#!/usr/bin/env bash
case "$1 $2" in
    "repo view") [[ -n "${GH_REPO_JSON:-}" ]] && echo "${GH_REPO_JSON}" || exit 1 ;;
    "api repos/acme/widget/environments/"*) exit 1 ;;
    *) echo "$*" >>"${GH_LOG}" ;;
esac
GH
chmod +x "${work}/bin/gh"
# Stands in for studiobimo/.github's script, which needs the real API.
cat >"${work}/settings/.devtools/repo-settings.sh" <<'SHARED'
echo "shared ORG=${ORG} $*" >>"${GH_LOG}"
SHARED
export PATH="${work}/bin:${PATH}" GH_LOG="${work}/gh.log"
export GH_REPO_JSON='{"nameWithOwner":"acme/widget","description":"","viewerCanAdminister":true}'
setup=(.devtools/scripts/github-setup.sh --from "${work}/settings")
called() { grep -qxF -- "$1" "${GH_LOG}"; }

: >"${GH_LOG}"
expect 1 "--check reports what is missing" env DESC="A widget." ENVS=development "${setup[@]}" --check
expect 0 "and asks the shared script only to compare" called "shared ORG=acme --check widget"
expect 1 "and changes nothing" grep -qv '^shared ' "${GH_LOG}"

: >"${GH_LOG}"
expect 0 "applies the setup" env DESC="A widget." ENVS=development "${setup[@]}"
expect 0 "runs the shared settings for this repository" called "shared ORG=acme widget"
expect 0 "sets the description" called "repo edit acme/widget --description A widget."
expect 0 "creates the environment" called "api -X PUT repos/acme/widget/environments/development"

: >"${GH_LOG}"
expect 0 "leaves the description alone unless asked" "${setup[@]}"
expect 1 "so nothing but the shared script ran" grep -qv '^shared ' "${GH_LOG}"
expect 2 "refuses an environment name that is not one" env ENVS='a/b' "${setup[@]}"
expect 2 "refuses without admin rights" \
    env GH_REPO_JSON='{"nameWithOwner":"acme/widget","description":"","viewerCanAdminister":false}' "${setup[@]}"
expect 2 "refuses a repository that is not on GitHub" env GH_REPO_JSON= "${setup[@]}"
expect 2 "an unknown flag is an error" .devtools/scripts/github-setup.sh --nope
expect 2 "and so is a flag without its value" .devtools/scripts/github-setup.sh --ref

echo "agent-guard"
# A mise that answers `mise exec -- lefthook ...` as the org's jobs would, and logs each job.
mkdir -p "${work}/guard"
cat >"${work}/guard/mise" <<'MISE'
#!/usr/bin/env bash
[[ "$1 $2 $3" == "exec -- lefthook" ]] || exit 127
case "$4" in
    version) [[ -z "${GUARD_NOT_SET_UP:-}" ]] ;;
    run)
        job="$7"
        echo "${job} BRANCH_NAME=${BRANCH_NAME:-} PR_BASE=${PR_BASE:-}" >>"${GUARD_LOG}"
        if [[ "${job}" == branch-name && ! "${BRANCH_NAME}" =~ ^[a-z]+/[a-z0-9*-]+$ ]] \
            || [[ "${job}" == pr-size && -n "${GUARD_TOO_BIG:-}" ]]; then
            echo "🥊 ${job}"
            exit 1
        fi
        ;;
esac
MISE
chmod +x "${work}/guard/mise"
export GUARD_LOG="${work}/guard.log"
# guard [VAR=value ...] <command>: the call as Claude Code hands it to the hook.
guard() {
    local vars=()
    while [[ $# -gt 1 ]]; do vars+=("$1"); shift; done
    jq -n --arg command "$1" '{tool_input: {command: $command}}' \
        | env PATH="${work}/guard:${PATH}" ${vars[@]+"${vars[@]}"} .devtools/scripts/agent-guard.sh
}
guarded() { grep -qxF -- "$1" "${GUARD_LOG}"; }

expect 0 "lets a Conventional Branch through" guard 'git switch -c feat/new-thing'
expect 2 "blocks git switch -c with any other name" guard 'git switch -c New_Thing'
expect 2 "and git checkout -b, after other flags" guard 'git checkout -q -b New_Thing main'
expect 2 "and git worktree add -b" guard 'git worktree add ../elsewhere -b New_Thing'
expect 2 "and git branch <name>" guard 'git branch New_Thing'
expect 0 "but not git branch -d" guard 'git branch -d New_Thing'
expect 2 "and a rename to a bad name" guard 'git branch -m feat/old New_Thing'
expect 0 "judging the new name, not the old" guard 'git branch -m Old_Thing feat/new-thing'
expect 2 "and every layer gh stack adds" guard 'gh stack add feat/fine New_Thing'
: >"${GUARD_LOG}"
expect 0 "reads a * as a name, never a glob" guard 'gh stack add feat/*'
expect 0 "so it checks that one name" guarded 'branch-name BRANCH_NAME=feat/* PR_BASE='
expect 0 "lets a push through when the size check passes" guard 'git push -u origin HEAD'
expect 2 "blocks it when it does not" guard GUARD_TOO_BIG=1 'git push'
expect 2 "and gh pr create, after another command" guard GUARD_TOO_BIG=1 'cd here && gh pr create --fill'
: >"${GUARD_LOG}"
expect 0 "measures a pull request against the base it names" guard 'gh pr create --fill --base feat/lower'
expect 0 "by passing that base to the job" guarded 'pr-size BRANCH_NAME= PR_BASE=feat/lower'
expect 0 "lets --help through" guard GUARD_TOO_BIG=1 'git push --help'
expect 0 "reads only the first line" guard GUARD_TOO_BIG=1 $'cat <<EOF\ngit push\nEOF'
expect 0 "lets everything through before setup" guard GUARD_NOT_SET_UP=1 'git switch -c New_Thing'

echo "init"
proj="${work}/proj"
copy "${proj}"
cd "${proj}"
# No repository on GitHub from here on, so init has to finish without one.
export GH_REPO_JSON=
expect 1 "refuses without a name" env SLUG=my-project DESC=x .devtools/scripts/init.sh
expect 1 "refuses a slug that is not kebab-case" \
    env NAME=x SLUG=My_Project DESC=x .devtools/scripts/init.sh
expect 0 "initialises a project" \
    env NAME="My Project" SLUG=my-project DESC="Does one thing & does it well." .devtools/scripts/init.sh
cp "${work}/out" "${work}/init.out"
expect 0 "says so when GitHub could not be set up" grep -q 'GitHub is not set up' "${work}/init.out"
expect 0 "names the project" grep -qx '# My Project' README.md
expect 0 "keeps punctuation in the description" grep -qxF 'Does one thing & does it well.' README.md
expect 1 "leaves no placeholder behind" \
    grep -rIlF --exclude-dir=.git -e "${PLACEHOLDER_NAME}" -e "${PLACEHOLDER_SLUG}" -e "${PLACEHOLDER_DESC}" .
expect 1 "leaves no init region behind" grep -rIl --exclude-dir=.git "template:${INIT_BLOCK}" .
expect 1 "removes .template/" test -e .template
expect 1 "removes itself" test -e .devtools/scripts/init.sh
expect 0 "keeps the GitHub setup for later runs" test -x .devtools/scripts/github-setup.sh
expect 1 "removes the template-only make targets" grep -q '^init:\|^test:' .devtools/Makefile
expect 1 "refuses to run twice" env NAME=x SLUG=x DESC=x "${template}/.devtools/scripts/init.sh"
expect 0 "is born in step with the template" \
    .devtools/scripts/template-sync.sh --check --from "${src}" --ref v9.9.9

if ((failures > 0)); then
    echo "${failures} failed" >&2
    exit 1
fi
echo "All passed"
