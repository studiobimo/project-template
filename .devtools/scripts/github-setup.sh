#!/usr/bin/env bash
# Makes this repository's GitHub side match the organization's: merge options,
# Actions permissions, security features, rulesets, and deployment environments.
#
# Usage: github-setup.sh [--check] [--from <dir>] [--ref <ref>]
#
#   (no flag)    apply
#   --check      change nothing; print what differs and exit 1 if anything does
#   --from <dir> use a checkout of the settings repo already on disk
#   --ref <ref>  tag or branch of the settings repo to use (default: v1)
#
#   DESC="..."                 also set the repository description
#   ENVS="staging production"  also create these deployment environments
#
# The settings and rulesets are not in this file. They live in studiobimo/.github
# (settings/ and rulesets/), next to the script that applies them, so every
# repository gets the same ones. This only points that script at this repository
# and adds the parts that are the project's own.
#
# Needs gh, signed in as an admin of the repository, and jq.
# Exit codes: 0 in step (or applied), 1 differences found by --check, 2 anything else.
#
# Managed by studiobimo/project-template; change it there.
set -euo pipefail

settings_repo="${SETTINGS_REPO:-studiobimo/.github}"
desc="${DESC:-}"
envs="${ENVS:-}"
mode=apply
from=""
ref=v1

die() {
    echo "✖ $*" >&2
    exit 2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check) mode=check; shift ;;
        --from) from="${2:?--from needs a directory}"; shift 2 ;;
        --ref) ref="${2:?--ref needs a tag or branch}"; shift 2 ;;
        -h | --help) sed -n '2,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
done

command -v gh >/dev/null 2>&1 || die "gh is not installed (brew install gh)"
command -v jq >/dev/null 2>&1 || die "jq is not installed (brew install jq)"

info="$(gh repo view --json nameWithOwner,description,viewerCanAdminister 2>/dev/null)" \
    || die "cannot find this repository on GitHub: does it have a remote, and is gh signed in?"
repo="$(jq -r .nameWithOwner <<<"${info}")"
[[ "$(jq -r .viewerCanAdminister <<<"${info}")" == true ]] \
    || die "settings and rulesets need an admin of ${repo}, and you are not one"

for env in ${envs}; do
    [[ "${env}" =~ ^[A-Za-z0-9._-]+$ ]] || die "not an environment name: ${env}"
done

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

if [[ -z "${from}" ]]; then
    from="${work}/settings"
    git clone --quiet --depth 1 --branch "${ref}" "https://github.com/${settings_repo}" "${from}" 2>/dev/null \
        || die "cannot clone ${settings_repo} at ${ref}"
fi

differences=0
skipped=""

# differs <what>: one finding, in the shared script's layout.
differs() {
    differences=$((differences + 1))
    echo "    $*"
}

shared="${from}/.devtools/repo-settings.sh"
if [[ -f "${shared}" ]]; then
    flags=()
    [[ "${mode}" == apply ]] || flags=(--check)
    status=0
    ORG="${repo%%/*}" bash "${shared}" ${flags[@]+"${flags[@]}"} "${repo#*/}" || status=$?
    if [[ "${mode}" == check && "${status}" -eq 1 ]]; then
        differences=$((differences + 1))
    elif [[ "${status}" -ne 0 ]]; then
        die "${settings_repo}@${ref} could not apply its settings to ${repo} (exit ${status})"
    fi
else
    echo "${repo}"
    echo "    ! ${settings_repo}@${ref} has no .devtools/repo-settings.sh, so the shared" >&2
    echo "      settings and rulesets were skipped; try another --ref" >&2
    skipped=", apart from the shared settings and rulesets"
fi

if [[ -n "${desc}" && "$(jq -r '.description // ""' <<<"${info}")" != "${desc}" ]]; then
    differs "description: $(jq '.description // ""' <<<"${info}") -> $(jq -n --arg d "${desc}" '$d')"
    if [[ "${mode}" == apply ]]; then
        gh repo edit "${repo}" --description "${desc}" >/dev/null
    fi
fi

for env in ${envs}; do
    gh api "repos/${repo}/environments/${env}" >/dev/null 2>&1 && continue
    differs "environment ${env}: missing"
    if [[ "${mode}" == apply ]]; then
        gh api -X PUT "repos/${repo}/environments/${env}" >/dev/null
    fi
done

if ((differences > 0)) && [[ "${mode}" == check ]]; then
    echo "✖ ${repo} differs. Apply with: make -C .devtools github"
    exit 1
fi
echo "✔ ${repo} is set up${skipped}"
