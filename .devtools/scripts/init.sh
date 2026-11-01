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

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
. "${here}/strings.sh" || exit 1
# Read by die, in strings.sh: init.sh has no drift to report, so an error is 1.
DIE_STATUS=1

name="${NAME:-}"
slug="${SLUG:-}"
desc="${DESC:-}"

root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "${MSG_NOT_GIT_REPO}"
cd "${root}"
self=".devtools/scripts/${BASH_SOURCE[0]##*/}"

[[ -d "${TEMPLATE_DIR}" ]] || die "${MSG_INIT_DONE_ALREADY}"
[[ -n "${name}" && -n "${slug}" && -n "${desc}" ]] || die "${MSG_INIT_USAGE}"
[[ "${slug}" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || die "${MSG_INIT_BAD_SLUG}" "${slug}"

mv "${TEMPLATE_DIR}/README.md" README.md
rm -rf "${TEMPLATE_DIR}"
rm -f CHANGELOG.md "${TEMPLATE_VERSION}"
say "${RELEASE_MANIFEST_INITIAL}" >"${RELEASE_MANIFEST}"

files=()
while IFS= read -r f; do
    [[ -f "${f}" ]] || continue
    case "${f}" in
        mise.lock | .mise/* | "${self}" | *.png | *.jpg | *.zip) continue ;;
    esac
    files+=("${f}")
done < <(git ls-files --cached --others --exclude-standard)

# Drop the regions that only make sense in the template itself (and the blank line
# before each, so no file is left with a double gap), then fill in the placeholders.
# Every value reaches perl through the environment, so none of it is read as a pattern.
START="${MARK_START}${INIT_BLOCK}" END="${MARK_END}${INIT_BLOCK}" \
    FROM_NAME="${PLACEHOLDER_NAME}" FROM_SLUG="${PLACEHOLDER_SLUG}" FROM_DESC="${PLACEHOLDER_DESC}" \
    NAME="${name}" SLUG="${slug}" DESC="${desc}" perl -0pi -e '
    s/(?:^\n)?^[^\n]*\Q$ENV{START}\E\b.*?\Q$ENV{END}\E\b[^\n]*\n//msg;
    s/\Q$ENV{FROM_NAME}\E/$ENV{NAME}/g;
    s/\Q$ENV{FROM_SLUG}\E/$ENV{SLUG}/g;
    s/\Q$ENV{FROM_DESC}\E/$ENV{DESC}/g;
' "${files[@]}"

rm -- "${self}"

ok "${MSG_INIT_DONE}" "${name}" "${slug}"
echo

# The files are done either way, so a GitHub failure is reported and not fatal.
if ! DESC="${desc}" ENVS="${ENVS:-}" "${here}/github-setup.sh"; then
    fail "${MSG_INIT_NO_GITHUB}"
fi

say "${MSG_INIT_NEXT}"
