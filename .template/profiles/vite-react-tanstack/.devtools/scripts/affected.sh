#!/bin/sh
# Managed by studiobimo/project-template (profile vite-react-tanstack); change it there.
#
# Prints the git ref the tests should narrow to, or nothing, which means "run everything".
#
# `vitest run --changed <ref>` runs only the test files that import something the diff touched.
# That is only sound while the diff is all source: vitest cannot see a dependency bump, a
# changed config, a shared test setup or a tool upgrade reach into every test. So a diff that
# touches any of those, an unset or unusable base, or a clone too shallow to find the merge
# base all print nothing, and the caller runs the full suite. Failing open costs minutes,
# failing closed would hide a regression.
#
# CI sets AFFECTED_BASE to origin/<base> for a pull request it may narrow, and leaves it empty
# otherwise. A local `make ci` sets nothing, so it runs everything.
#
# The diff is the pull request's (AFFECTED_BASE...HEAD) plus uncommitted changes to tracked
# files, since vitest also reads those.

set -eu

base="${AFFECTED_BASE:-}"
[ -n "${base}" ] || exit 0

root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "${root}"
git rev-parse --verify --quiet "${base}^{commit}" >/dev/null || exit 0

committed="$(git diff --name-only "${base}...HEAD" 2>/dev/null)" || exit 0
pending="$(git diff --name-only HEAD 2>/dev/null)" || exit 0

touches_everything() {
    while IFS= read -r path; do
        [ -n "${path}" ] || continue
        name="${path##*/}"
        case "${name}" in
            pnpm-lock.yaml | pnpm-workspace.yaml | package.json | mise.toml | mise.lock) return 0 ;;
            tsconfig*.json | vite.config.* | vitest.config.* | vitest.workspace.*) return 0 ;;
            eslint.config.* | knip.json | .jscpd.json | wrangler.jsonc) return 0 ;;
        esac
        case "${path}" in
            .devtools/* | .mise/* | src/test/setup.* | */src/test/setup.*) return 0 ;;
        esac
    done
    return 1
}

if printf '%s\n%s\n' "${committed}" "${pending}" | touches_everything; then
    exit 0
fi

printf '%s\n' "${base}"
