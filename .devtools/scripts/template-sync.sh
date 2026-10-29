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
# .template-ignore, one per line with an optional `# reason`, are left alone, unless the
# manifest marks the entry `required`.
#
# A project can also opt in to profiles, one per line in its .template-profiles. A
# profile is a second manifest, .template/manifest.<name>, whose files and blocks are
# read from .template/profiles/<name>/ instead of the template's root, so a language's
# files do not sit in every new project.
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
# shellcheck source-path=SCRIPTDIR
. "$(dirname "${BASH_SOURCE[0]}")/strings.sh" || exit 2

template_repo="${TEMPLATE_REPO:-${TEMPLATE_REPO_DEFAULT}}"
mode=sync
from=""
ref=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check) mode=check; shift ;;
        --from) need_value "$@"; from="$2"; shift 2 ;;
        --ref) need_value "$@"; ref="$2"; shift 2 ;;
        -h | --help) usage_of "${BASH_SOURCE[0]}"; exit "${EXIT_OK}" ;;
        *) die "${MSG_UNKNOWN_ARG}" "$1" ;;
    esac
done

root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "${MSG_NOT_GIT_REPO}"
cd "${root}"

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

if [[ -z "${from}" ]]; then
    url="${GITHUB_URL}/${template_repo}"
    if [[ -z "${ref}" ]]; then
        # Highest version tag; `^{}` lines are the peeled side of annotated tags.
        ref="$(git ls-remote --tags --sort=-v:refname "${url}" 'v*' 2>/dev/null \
            | grep -v '\^{}$' | head -n 1 | sed 's#.*refs/tags/##')" || true
        [[ -n "${ref}" ]] || die "${MSG_SYNC_NO_RELEASE}" "${url}"
    fi
    from="${work}/template"
    git clone --quiet --depth 1 --branch "${ref}" "${url}" "${from}" 2>/dev/null \
        || die "${MSG_CANNOT_CLONE}" "${url}" "${ref}"
fi

[[ -f "${from}/${TEMPLATE_MANIFEST}" ]] || die "${MSG_SYNC_NOT_TEMPLATE}" "${from}" "${TEMPLATE_MANIFEST}"
if [[ -z "${ref}" ]]; then
    ref="$(git -C "${from}" describe --tags --always 2>/dev/null || echo unknown)"
fi

# entries_of <file>: its non-blank lines, without `#` comments or surrounding space. The
# last line counts even with no newline after it.
entries_of() {
    [[ -f "$1" ]] || return 0
    sed -E -e 's/(^|[[:space:]])#.*$//' -e 's/^[[:space:]]+//' -e 's/[[:space:]]+$//' "$1" \
        | grep -v '^$' || true
}

entries_of "${TEMPLATE_IGNORE}" >"${work}/ignored"
ignored() { grep -Fxq -- "$1" "${work}/ignored"; }

# The awk programs below find a block by its marker lines. A marker names the block in
# full: `template:base` is not the start of `template:baseline`.
# shellcheck disable=SC2016 # awk's own $0, not the shell's
marks='function marks(line, tag,   at) {
    at = index(line, tag)
    return at > 0 && substr(line, at + length(tag), 1) !~ /[A-Za-z0-9_-]/
}'

# markers_of <file> <name>: ok, absent, unclosed, unopened or repeated.
markers_of() {
    awk -v start="${MARK_START}$2" -v finish="${MARK_END}$2" "${marks}"'
        marks($0, start) { starts++; if (inside) bad = "repeated"; inside = 1 }
        marks($0, finish) { if (!inside && !bad) bad = "unopened"; inside = 0 }
        END {
            if (bad) print bad
            else if (inside) print "unclosed"
            else if (starts > 1) print "repeated"
            else if (starts == 0) print "absent"
            else print "ok"
        }' "$1"
}

# block_of <file> <name>: the marked region, marker lines included.
block_of() {
    awk -v start="${MARK_START}$2" -v finish="${MARK_END}$2" "${marks}"'
        marks($0, start) { inside = 1 }
        inside { print }
        marks($0, finish) { inside = 0 }' "$1"
}

# with_block <file> <name> <block-file>: the file, with its region replaced.
with_block() {
    awk -v start="${MARK_START}$2" -v finish="${MARK_END}$2" -v src="$3" "${marks}"'
        marks($0, start) {
            while ((getline line < src) > 0) print line
            close(src)
            inside = 1
        }
        !inside { print }
        marks($0, finish) { inside = 0 }' "$1"
}

# finding_for <markers-state> <name>: what to say about a block whose markers are wrong.
finding_for() {
    case "$1" in
        unclosed) say "${FINDING_MARKERS_UNCLOSED}" "$2" ;;
        unopened) say "${FINDING_MARKERS_UNOPENED}" "$2" ;;
        repeated) say "${FINDING_MARKERS_REPEATED}" "$2" ;;
    esac
}

drift=0
changed=0

# report <path> <what> [<ours> <theirs>]: one finding, with a diff when there is one.
report() {
    drift=$((drift + 1))
    say "${GLYPH_FAIL} ${MSG_SYNC_FINDING}" "$1" "$2"
    if [[ $# -eq 4 ]]; then
        diff -u --label "a/$1" --label "$(say "${MSG_SYNC_DIFF_LABEL}" "$1" "${ref}")" "$3" "$4" || true
        echo
    fi
}

# Where the manifest being applied reads its files from: the template's root for the base
# manifest, a profile's directory for a profile.
src_root="${from}"

sync_file() {
    local path="$1" src="${src_root}/$1"
    [[ -f "${src}" ]] || die "${MSG_SYNC_NOT_IN_TEMPLATE}" "${path}"

    local finding=""
    if [[ ! -f "${path}" ]]; then
        finding="${FINDING_MISSING}"
    elif ! cmp -s "${path}" "${src}"; then
        finding="${FINDING_DIFFERS}"
    elif [[ -x "${src}" && ! -x "${path}" ]] || [[ ! -x "${src}" && -x "${path}" ]]; then
        finding="${FINDING_MODE}"
    fi
    [[ -n "${finding}" ]] || return 0

    if [[ "${mode}" == check ]]; then
        if [[ "${finding}" == "${FINDING_DIFFERS}" ]]; then
            report "${path}" "${finding}" "${path}" "${src}"
        else
            report "${path}" "${finding}"
        fi
        return 0
    fi

    mkdir -p "$(dirname "${path}")"
    cp "${src}" "${path}"
    if [[ -x "${src}" ]]; then chmod +x "${path}"; else chmod -x "${path}"; fi
    changed=$((changed + 1))
    ok "${MSG_SYNC_UPDATED}" "${path}"
}

sync_block() {
    local path="$1" name="$2" src="${src_root}/$1" state
    [[ -f "${src}" ]] || die "${MSG_SYNC_NOT_IN_TEMPLATE}" "${path}"

    state="$(markers_of "${src}" "${name}")"
    case "${state}" in
        ok) ;;
        absent) die "${MSG_SYNC_NO_BLOCK}" "${path}" "${name}" ;;
        *) die "${MSG_SYNC_TEMPLATE_MARKERS}" "${path}" "$(finding_for "${state}" "${name}")" ;;
    esac
    block_of "${src}" "${name}" >"${work}/theirs"

    state=absent
    [[ ! -f "${path}" ]] || state="$(markers_of "${path}" "${name}")"
    case "${state}" in
        ok | absent) ;;
        # Replacing a region with no end would take the rest of the file with it.
        *)
            [[ "${mode}" == check ]] || die "${MSG_SYNC_FINDING}" "${path}" "$(finding_for "${state}" "${name}")"
            report "${path}" "$(finding_for "${state}" "${name}")"
            return 0
            ;;
    esac

    if [[ "${state}" == ok ]]; then
        block_of "${path}" "${name}" >"${work}/ours"
        ! cmp -s "${work}/ours" "${work}/theirs" || return 0
    fi

    if [[ "${mode}" == check ]]; then
        if [[ "${state}" == absent ]]; then
            report "${path}" "$(say "${FINDING_BLOCK_MISSING}" "${name}")"
        else
            report "${path}" "$(say "${FINDING_BLOCK_DIFFERS}" "${name}")" "${work}/ours" "${work}/theirs"
        fi
        return 0
    fi

    if [[ ! -f "${path}" ]]; then
        mkdir -p "$(dirname "${path}")"
        cp "${work}/theirs" "${path}"
        ok "${MSG_SYNC_CREATED}" "${path}" "${name}"
    elif [[ "${state}" == absent ]]; then
        # No markers to aim at, so the end of the file is the only safe place.
        { echo; cat "${work}/theirs"; } >>"${path}"
        ok "${MSG_SYNC_APPENDED}" "${path}" "${name}"
    else
        with_block "${path}" "${name}" "${work}/theirs" >"${work}/merged"
        cat "${work}/merged" >"${path}"
        ok "${MSG_SYNC_BLOCK_UPDATED}" "${path}" "${name}"
    fi
    changed=$((changed + 1))
}

# apply_manifest <manifest>: sync, or check, every entry in it. An entry is
# `file <path> [required]` or `block <path> <name> [required]`.
apply_manifest() {
    local kind path name flag _
    while read -r kind path name flag _; do
        case "${kind}" in
            file) flag="${name}"; name="" ;;
            block) [[ -n "${name}" && "${name}" != "${FLAG_REQUIRED}" ]] || die "${MSG_SYNC_NEEDS_NAME}" "${path}" ;;
            *) die "${MSG_SYNC_UNKNOWN_ENTRY}" "${kind}" "${path}" ;;
        esac
        [[ -z "${flag}" || "${flag}" == "${FLAG_REQUIRED}" ]] || die "${MSG_SYNC_UNKNOWN_FLAG}" "${flag}" "${path}"

        if ignored "${path}"; then
            if [[ "${flag}" != "${FLAG_REQUIRED}" ]]; then
                skip "${MSG_SYNC_IGNORED}" "${path}" "${TEMPLATE_IGNORE}"
                continue
            fi
            # Ignoring it would switch off a guard every repo relies on, so the entry is
            # applied anyway, and the line in .template-ignore stays drift until it goes.
            if [[ "${mode}" == check ]]; then
                report "${path}" "$(say "${FINDING_REQUIRED}" "${TEMPLATE_IGNORE}")"
            else
                say "${GLYPH_FAIL} ${MSG_SYNC_REQUIRED}" "${path}" "${TEMPLATE_IGNORE}"
            fi
        fi
        case "${kind}" in
            file) sync_file "${path}" ;;
            block) sync_block "${path}" "${name}" ;;
        esac
    done < <(entries_of "$1")
}

apply_manifest "${from}/${TEMPLATE_MANIFEST}"

# Profiles come after the base manifest, in the order the project lists them.
while read -r profile _; do
    [[ "${profile}" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "${MSG_SYNC_BAD_PROFILE}" "${TEMPLATE_PROFILES}" "${profile}"
    [[ -f "${from}/${TEMPLATE_MANIFEST}.${profile}" ]] \
        || die "${MSG_SYNC_NO_PROFILE}" "${TEMPLATE_PROFILES}" "${profile}" "${TEMPLATE_MANIFEST}" "${profile}"
    src_root="${from}/${TEMPLATE_DIR}/profiles/${profile}"
    apply_manifest "${from}/${TEMPLATE_MANIFEST}.${profile}"
done < <(entries_of "${TEMPLATE_PROFILES}")

recorded="$(cat "${TEMPLATE_VERSION}" 2>/dev/null || true)"

if [[ "${mode}" == check ]]; then
    if ((drift > 0)); then
        say "${MSG_SYNC_DRIFT}" "${drift}" "${template_repo}" "${ref}" "${recorded:-${SYNC_NEVER}}"
        say "${MSG_SYNC_DRIFT_FIX}"
        exit "${EXIT_DIFFERS}"
    fi
    ok "${MSG_SYNC_IN_STEP}" "${template_repo}" "${ref}"
    exit "${EXIT_OK}"
fi

if [[ "${recorded}" != "${ref}" ]]; then
    echo "${ref}" >"${TEMPLATE_VERSION}"
fi
ok "${MSG_SYNC_DONE}" "${template_repo}" "${ref}" "${changed}"
exit "${EXIT_OK}"
}
