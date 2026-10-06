#!/usr/bin/env bash
# Keeps the files studiobimo/project-template manages in step with it.
#
# Usage: template-sync.sh [--check] [--from <dir>] [--ref <tag>]
#
#   (no flag)    overwrite the managed files and blocks with the template's
#   --check      change nothing; print what differs and exit 1 if anything does
#   --from <dir> use a template checkout already on disk instead of cloning one
#   --ref <tag>  template release to use (default: the latest); with --from it only
#                names the version in the output
#
# The template's .template/manifest says what is managed: whole files, and marked
# blocks inside files the project otherwise owns. Paths listed in this repo's
# .template-ignore are left alone.
#
# Exit codes: 0 in step (or synced), 1 drift found by --check, 2 anything else.
# The template-drift workflow depends on that split, so a failure of this script is
# never mistaken for "no drift".
#
# Bash 3.2 and git only, so it runs on a stock macOS and on a CI runner alike.
# Managed by studiobimo/project-template; change it there.
set -euo pipefail

# Bash reads a brace group whole before running it. Without the braces, syncing a
# newer copy of this file over itself would change the script mid-run.
{
template_repo="${TEMPLATE_REPO:-studiobimo/project-template}"
mode=sync
from=""
ref=""

die() {
    echo "✖ $*" >&2
    exit 2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check) mode=check; shift ;;
        --from) from="${2:?--from needs a directory}"; shift 2 ;;
        --ref) ref="${2:?--ref needs a tag}"; shift 2 ;;
        -h | --help) sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
done

root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git repository"
cd "${root}"

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

if [[ -z "${from}" ]]; then
    url="https://github.com/${template_repo}"
    if [[ -z "${ref}" ]]; then
        # Highest version tag; `^{}` lines are the peeled side of annotated tags.
        ref="$(git ls-remote --tags --sort=-v:refname "${url}" 'v*' 2>/dev/null \
            | grep -v '\^{}$' | head -n 1 | sed 's#.*refs/tags/##')" || true
        [[ -n "${ref}" ]] || die "cannot find a release tag on ${url} (no access, or nothing released yet)"
    fi
    from="${work}/template"
    git clone --quiet --depth 1 --branch "${ref}" "${url}" "${from}" 2>/dev/null \
        || die "cannot clone ${url} at ${ref}"
fi

manifest="${from}/.template/manifest"
[[ -f "${manifest}" ]] || die "${from} has no .template/manifest; is it the template?"
if [[ -z "${ref}" ]]; then
    ref="$(git -C "${from}" describe --tags --always 2>/dev/null || echo unknown)"
fi

ignored() {
    [[ -f .template-ignore ]] || return 1
    grep -v '^[[:space:]]*#' .template-ignore | sed 's/[[:space:]]*$//' | grep -Fxq "$1"
}

# block_of <file> <name>: the marked region, marker lines included.
block_of() {
    awk -v start=">>> template:$2" -v finish="<<< template:$2" '
        index($0, start) { inside = 1 }
        inside { print }
        index($0, finish) { inside = 0 }' "$1"
}

# with_block <file> <name> <block-file>: the file, with its region replaced.
with_block() {
    awk -v start=">>> template:$2" -v finish="<<< template:$2" -v src="$3" '
        index($0, start) {
            while ((getline line < src) > 0) print line
            close(src)
            inside = 1
        }
        !inside { print }
        index($0, finish) { inside = 0 }' "$1"
}

drift=0
changed=0

# report <path> <what> [<ours> <theirs>]: one finding, with a diff when there is one.
report() {
    drift=$((drift + 1))
    echo "✖ $1: $2"
    if [[ $# -eq 4 ]]; then
        diff -u --label "a/$1" --label "b/$1 (template ${ref})" "$3" "$4" || true
        echo
    fi
}

sync_file() {
    local path="$1" src="${from}/$1"
    [[ -f "${src}" ]] || die "manifest lists ${path}, but the template does not have it"

    local same=true
    if [[ ! -f "${path}" ]]; then
        same=false
    elif ! cmp -s "${path}" "${src}"; then
        same=false
    elif [[ -x "${src}" && ! -x "${path}" ]] || [[ ! -x "${src}" && -x "${path}" ]]; then
        same=false
    fi
    [[ "${same}" == false ]] || return 0

    if [[ "${mode}" == check ]]; then
        if [[ ! -f "${path}" ]]; then
            report "${path}" "missing"
        elif cmp -s "${path}" "${src}"; then
            report "${path}" "executable bit differs"
        else
            report "${path}" "differs" "${path}" "${src}"
        fi
        return 0
    fi

    mkdir -p "$(dirname "${path}")"
    cp "${src}" "${path}"
    if [[ -x "${src}" ]]; then chmod +x "${path}"; else chmod -x "${path}"; fi
    changed=$((changed + 1))
    echo "✔ ${path}: updated"
}

sync_block() {
    local path="$1" name="$2" src="${from}/$1"
    [[ -f "${src}" ]] || die "manifest lists ${path}, but the template does not have it"

    block_of "${src}" "${name}" >"${work}/theirs"
    [[ -s "${work}/theirs" ]] || die "the template's ${path} has no '${name}' block"

    if [[ -f "${path}" ]]; then
        block_of "${path}" "${name}" >"${work}/ours"
    else
        : >"${work}/ours"
    fi
    if cmp -s "${work}/ours" "${work}/theirs"; then
        return 0
    fi

    if [[ "${mode}" == check ]]; then
        if [[ ! -s "${work}/ours" ]]; then
            report "${path}" "block '${name}' is missing"
        else
            report "${path}" "block '${name}' differs" "${work}/ours" "${work}/theirs"
        fi
        return 0
    fi

    if [[ ! -f "${path}" ]]; then
        mkdir -p "$(dirname "${path}")"
        cp "${work}/theirs" "${path}"
        echo "✔ ${path}: created with block '${name}'"
    elif [[ ! -s "${work}/ours" ]]; then
        # No markers to aim at, so the end of the file is the only safe place.
        { echo; cat "${work}/theirs"; } >>"${path}"
        echo "✔ ${path}: block '${name}' appended; move it to where it belongs"
    else
        with_block "${path}" "${name}" "${work}/theirs" >"${work}/merged"
        cat "${work}/merged" >"${path}"
        echo "✔ ${path}: block '${name}' updated"
    fi
    changed=$((changed + 1))
}

while read -r kind path name _; do
    case "${kind}" in
        '' | '#'*) continue ;;
    esac
    if ignored "${path}"; then
        echo "– ${path}: ignored by .template-ignore"
        continue
    fi
    case "${kind}" in
        file) sync_file "${path}" ;;
        block) sync_block "${path}" "${name:?manifest: block ${path} needs a name}" ;;
        *) die "manifest: unknown entry '${kind} ${path}'" ;;
    esac
done <"${manifest}"

recorded="$(cat .template-version 2>/dev/null || true)"

if [[ "${mode}" == check ]]; then
    if ((drift > 0)); then
        echo "${drift} difference(s) from ${template_repo}@${ref} (last synced: ${recorded:-never})."
        echo "Run: make -C .devtools sync"
        exit 1
    fi
    echo "✔ In step with ${template_repo}@${ref}"
    exit 0
fi

if [[ "${recorded}" != "${ref}" ]]; then
    echo "${ref}" >.template-version
fi
echo "✔ Synced with ${template_repo}@${ref} (${changed} updated). Review with: git diff"
exit 0
}
