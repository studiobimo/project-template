#!/usr/bin/env bash
# PreToolUse guard for AI coding agents (Claude Code: .claude/settings.json,
# Codex: .codex/hooks.json). Both pass the tool call as JSON on stdin and
# treat exit code 2 with a reason on stderr as "block this call".
#
# Enforces the same rules as the git hooks, before the agent acts:
#   - gh pr create / gh stack submit / git push  -> PR size limit
#   - git checkout -b / git switch -c / git branch <name> -> Conventional Branch
#
# The rules themselves are the org's pre-commit hooks (studiobimo/.github), run by
# id, so this file only decides when to ask. CI (pr-checks) remains the
# authoritative gate; this is a guardrail.
#
# Managed by studiobimo/project-template; change it there.
set -euo pipefail

devtools="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v jq >/dev/null 2>&1 || exit 0
command -v uv >/dev/null 2>&1 || exit 0
cmd="$(jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[[ -n "${cmd}" ]] || exit 0

# run_hook <rule> <hook-id> [VAR=value ...]: blocks the call when the hook fails.
run_hook() {
    local rule="$1" id="$2" out status=0
    shift 2
    out="$(env "$@" uv --project "${devtools}" run --frozen \
        pre-commit run "${id}" --hook-stage manual 2>&1)" || status=$?
    # 1 is the hook saying no. Anything else is pre-commit itself failing (tools not
    # set up yet, the hook repo unreachable), which is not a reason to stop the agent.
    if [[ "${status}" -eq 1 ]]; then
        printf 'Blocked by agent-guard (%s):\n%s\n' "${rule}" "${out}" >&2
        exit 2
    fi
}

# Only the first line matters for matching; heredoc bodies can contain anything.
first_line="${cmd%%$'\n'*}"

if [[ "${first_line}" =~ [[:space:]](--help|-h)([[:space:]]|$) ]]; then
    exit 0
fi

if [[ "${first_line}" =~ (^|[[:space:]\;\&\|])(gh[[:space:]]+pr[[:space:]]+create|gh[[:space:]]+stack[[:space:]]+submit|git[[:space:]]+push)([[:space:]]|$) ]]; then
    size_env=()
    if [[ "${first_line}" =~ gh[[:space:]]+pr[[:space:]]+create.*(--base|-B)[[:space:]=]+[\"\']?([^[:space:]\"\']+) ]]; then
        size_env=("PR_BASE=${BASH_REMATCH[2]}")
    fi
    run_hook "PR size rule" pr-size ${size_env[@]+"${size_env[@]}"}
fi

new_branch=""
if [[ "${first_line}" =~ git[[:space:]]+(checkout|switch)[[:space:]]+(-b|-B|-c|-C|--create)[[:space:]]+[\"\']?([^[:space:];&|\"\']+) ]]; then
    new_branch="${BASH_REMATCH[3]}"
elif [[ "${first_line}" =~ git[[:space:]]+branch[[:space:]]+(-[mMcC]|--move|--copy)[[:space:]]+(.*)$ ]]; then
    # Rename/copy: `<new>` alone renames the current branch; with `<old> <new>`
    # the second name is the one being created.
    args="${BASH_REMATCH[2]%%[;&|<>]*}"
    args="${args% [0-9]}"
    names=()
    for b in ${args}; do
        b="${b//[\"\']/}"
        [[ -z "${b}" || "${b}" == -* ]] && continue
        names+=("${b}")
    done
    if ((${#names[@]} >= 2)); then
        new_branch="${names[1]}"
    elif ((${#names[@]} == 1)); then
        new_branch="${names[0]}"
    fi
elif [[ "${first_line}" =~ git[[:space:]]+branch[[:space:]]+[\"\']?([^-[:space:];&|\"\'][^[:space:];&|\"\']*)[\"\']?([[:space:]]|$) ]]; then
    new_branch="${BASH_REMATCH[1]}"
elif [[ "${first_line}" =~ gh[[:space:]]+stack[[:space:]]+(init|add)[[:space:]]+(.*)$ ]]; then
    # Stop at the next command separator or redirection.
    args="${BASH_REMATCH[2]%%[;&|<>]*}"
    args="${args% [0-9]}"
    for b in ${args}; do
        b="${b//[\"\']/}"
        [[ -z "${b}" || "${b}" == -* ]] && continue
        run_hook "branch naming rule" conventional-branch "BRANCH_NAME=${b}"
    done
fi

if [[ -n "${new_branch}" ]]; then
    run_hook "branch naming rule" conventional-branch "BRANCH_NAME=${new_branch}"
fi

exit 0
