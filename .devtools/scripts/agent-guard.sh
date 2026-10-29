#!/usr/bin/env bash
# PreToolUse guard for AI coding agents (Claude Code: .claude/settings.json,
# Codex: .codex/hooks.json). Both pass the tool call as JSON on stdin and
# treat exit code 2 with a reason on stderr as "block this call".
#
# Enforces the same rules as the git hooks, before the agent acts:
#   - gh pr create / gh stack submit / git push  -> PR size limit
#   - git checkout -b / git switch -c / git worktree add -b / git branch <name> /
#     gh stack init|add <name>                    -> Conventional Branch
#
# The rules themselves are the org's lefthook jobs (studiobimo/.github), run by
# name, so this file only decides when to ask. CI (pr-checks) remains the
# authoritative gate; this is a guardrail, so anything missing lets the call through.
#
# Managed by studiobimo/project-template; change it there.
set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0
command -v mise >/dev/null 2>&1 || exit 0
# shellcheck source-path=SCRIPTDIR
. "$(dirname "${BASH_SOURCE[0]}")/strings.sh" 2>/dev/null || exit 0
cmd="$(jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[[ -n "${cmd}" ]] || exit 0

# The patterns live in variables because bash reads a quoted pattern after =~ as a
# literal string. The pieces they are built from:
sp='[[:space:]]+'
quote="[\"']?"
# A branch name: everything up to a space, a quote, a separator or a redirection.
name="([^[:space:];&|<>\"']+)"
# Any other arguments before a flag, within the same command.
others='([^;&|]*[[:space:]])?'

re_help='[[:space:]](--help|-h)([[:space:]]|$)'
re_publish="(^|[[:space:];&|])(gh${sp}pr${sp}create|gh${sp}stack${sp}submit|git${sp}push)([[:space:]]|$)"
re_pr_base="gh${sp}pr${sp}create${sp}${others}(--base|-B)[[:space:]=]+${quote}${name}"
re_switch="git${sp}(checkout|switch)${sp}${others}(-b|-B|-c|-C|--create|--force-create)${sp}${quote}${name}"
re_worktree="git${sp}worktree${sp}add${sp}${others}(-b|-B)${sp}${quote}${name}"
re_rename="git${sp}branch${sp}(-[mMcC]|--move|--copy)${sp}(.*)$"
re_branch="git${sp}branch${sp}${quote}([^-[:space:];&|<>\"'][^[:space:];&|<>\"']*)${quote}([[:space:]]|$)"
re_stack="gh${sp}stack${sp}(init|add)${sp}(.*)$"

# run_hook <rule> <job> [VAR=value ...]: blocks the call when the job ran and said no.
run_hook() {
    local rule="$1" job="$2" out status=0 failed
    shift 2
    # Not set up yet (no tools, or the org's config never fetched) is not a reason to
    # stop the agent, so only a job that ran and said no blocks the call.
    mise exec -- lefthook version >/dev/null 2>&1 || return 0
    out="$(env "$@" mise exec -- lefthook run "${GUARD_HOOK}" --job "${job}" --no-tty 2>&1)" || status=$?
    # shellcheck disable=SC2059 # the format is GUARD_JOB_FAILED, never data
    printf -v failed "${GUARD_JOB_FAILED}" "${job}"
    if [[ "${status}" -ne 0 && "${out}" == *"${failed}"* ]]; then
        say "${MSG_GUARD_BLOCKED}" "${rule}" "${out}" >&2
        exit "${EXIT_BLOCK}"
    fi
}

# names_in <arguments>: each argument that is not a flag, one per line, up to the next
# command separator or redirection.
names_in() {
    local args="${1%%[;&|<>]*}" word
    args="${args% [0-9]}"
    set -f
    for word in ${args}; do
        word="${word//[\"\']/}"
        [[ -z "${word}" || "${word}" == -* ]] || printf '%s\n' "${word}"
    done
    set +f
}

# Only the first line matters for matching; heredoc bodies can contain anything.
first_line="${cmd%%$'\n'*}"
[[ ! "${first_line}" =~ ${re_help} ]] || exit 0

if [[ "${first_line}" =~ ${re_publish} ]]; then
    size_env=()
    if [[ "${first_line}" =~ ${re_pr_base} ]]; then
        size_env=("PR_BASE=${BASH_REMATCH[3]}")
    fi
    run_hook "${GUARD_RULE_PR_SIZE}" "${GUARD_JOB_PR_SIZE}" ${size_env[@]+"${size_env[@]}"}
fi

branches=()
if [[ "${first_line}" =~ ${re_switch} ]]; then
    branches=("${BASH_REMATCH[4]}")
elif [[ "${first_line}" =~ ${re_worktree} ]]; then
    branches=("${BASH_REMATCH[3]}")
elif [[ "${first_line}" =~ ${re_rename} ]]; then
    while IFS= read -r branch; do branches+=("${branch}"); done < <(names_in "${BASH_REMATCH[2]}")
    # `<new>` alone renames the current branch; with `<old> <new>` the second is created.
    if ((${#branches[@]} >= 2)); then
        branches=("${branches[1]}")
    fi
elif [[ "${first_line}" =~ ${re_branch} ]]; then
    branches=("${BASH_REMATCH[1]}")
elif [[ "${first_line}" =~ ${re_stack} ]]; then
    while IFS= read -r branch; do branches+=("${branch}"); done < <(names_in "${BASH_REMATCH[2]}")
fi

for branch in ${branches[@]+"${branches[@]}"}; do
    run_hook "${GUARD_RULE_BRANCH}" "${GUARD_JOB_BRANCH}" "BRANCH_NAME=${branch}"
done

exit 0
