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

# shellcheck source-path=SCRIPTDIR
. "$(dirname "${BASH_SOURCE[0]}")/strings.sh" || exit 2

settings_repo="${SETTINGS_REPO:-${SETTINGS_REPO_DEFAULT}}"
desc="${DESC:-}"
envs=()
read -r -a envs <<<"${ENVS:-}" || true
mode=apply
from=""
ref="${SETTINGS_REF_DEFAULT}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check) mode=check; shift ;;
        --from) need_value "$@"; from="$2"; shift 2 ;;
        --ref) need_value "$@"; ref="$2"; shift 2 ;;
        -h | --help) usage_of "${BASH_SOURCE[0]}"; exit "${EXIT_OK}" ;;
        *) die "${MSG_UNKNOWN_ARG}" "$1" ;;
    esac
done

for tool in gh jq; do
    command -v "${tool}" >/dev/null 2>&1 || die "${MSG_NEEDS_TOOL}" "${tool}" "${tool}"
done

info="$(gh repo view --json nameWithOwner,description,viewerCanAdminister 2>/dev/null)" \
    || die "${MSG_GH_NO_REPO}"
repo="$(jq -r .nameWithOwner <<<"${info}")"
[[ "$(jq -r .viewerCanAdminister <<<"${info}")" == true ]] || die "${MSG_GH_NOT_ADMIN}" "${repo}"

# Bash 3.2 calls an empty array unset, hence the ${envs[@]+...} on every expansion.
for env in ${envs[@]+"${envs[@]}"}; do
    [[ "${env}" =~ ^[A-Za-z0-9._-]+$ ]] || die "${MSG_GH_BAD_ENV}" "${env}"
done

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

if [[ -z "${from}" ]]; then
    from="${work}/settings"
    git clone --quiet --depth 1 --branch "${ref}" "${GITHUB_URL}/${settings_repo}" "${from}" 2>/dev/null \
        || die "${MSG_CANNOT_CLONE}" "${settings_repo}" "${ref}"
fi

differences=0
skipped=""

# differs <format> [<value>...]: one finding, in the shared script's layout.
differs() {
    differences=$((differences + 1))
    say "${MSG_GH_FINDING}" "$(say "$@")"
}

shared="${from}/${SETTINGS_SCRIPT}"
if [[ -f "${shared}" ]]; then
    flags=()
    [[ "${mode}" == apply ]] || flags=(--check)
    status=0
    ORG="${repo%%/*}" bash "${shared}" ${flags[@]+"${flags[@]}"} "${repo#*/}" || status=$?
    if [[ "${mode}" == check && "${status}" -eq "${EXIT_DIFFERS}" ]]; then
        differences=$((differences + 1))
    elif [[ "${status}" -ne "${EXIT_OK}" ]]; then
        die "${MSG_GH_SHARED_FAILED}" "${settings_repo}" "${ref}" "${repo}" "${status}"
    fi
else
    say '%s' "${repo}"
    warn "${MSG_GH_NO_SHARED}" "${settings_repo}" "${ref}" "${SETTINGS_SCRIPT}"
    skipped="${MSG_GH_SKIPPED}"
fi

if [[ -n "${desc}" && "$(jq -r '.description // ""' <<<"${info}")" != "${desc}" ]]; then
    differs "${MSG_GH_DESCRIPTION}" "$(jq '.description // ""' <<<"${info}")" "$(jq -n --arg d "${desc}" '$d')"
    if [[ "${mode}" == apply ]]; then
        gh repo edit "${repo}" --description "${desc}" >/dev/null
    fi
fi

for env in ${envs[@]+"${envs[@]}"}; do
    gh api "repos/${repo}/environments/${env}" >/dev/null 2>&1 && continue
    differs "${MSG_GH_ENV_MISSING}" "${env}"
    if [[ "${mode}" == apply ]]; then
        gh api -X PUT "repos/${repo}/environments/${env}" >/dev/null
    fi
done

if ((differences > 0)) && [[ "${mode}" == check ]]; then
    fail "${MSG_GH_DIFFERS}" "${repo}"
    exit "${EXIT_DIFFERS}"
fi
ok "${MSG_GH_SET_UP}" "${repo}" "${skipped}"
