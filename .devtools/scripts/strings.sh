# shellcheck shell=bash
# Every name, path and message the .devtools scripts use, and the helpers that print them.
# Sourced, never run; a script loads it with
#
#   . "$(dirname "${BASH_SOURCE[0]}")/strings.sh" || exit 2
#
# Messages are printf formats. A caller passes the values after the format, so a path, a
# title or a branch name is always an argument and never part of a format.
#
# Bash 3.2, so template-sync.sh can load it on a stock macOS.
# Managed by studiobimo/project-template; change it there.

# shellcheck disable=SC2034 # each name is read by a script that sources this file

# --- Where things live --------------------------------------------------------------------

GITHUB_URL=https://github.com
TEMPLATE_REPO_DEFAULT=studiobimo/project-template
SETTINGS_REPO_DEFAULT=studiobimo/.github
# The floating tag of studiobimo/.github the workflows are called at and the hooks follow.
SETTINGS_REF_DEFAULT=v1
# Inside a settings checkout: the script that applies the org's settings and rulesets.
SETTINGS_SCRIPT=.devtools/repo-settings.sh
DEVTOOLS='make -C .devtools'

TEMPLATE_DIR=.template
TEMPLATE_MANIFEST=.template/manifest
TEMPLATE_IGNORE=.template-ignore
TEMPLATE_PROFILES=.template-profiles
TEMPLATE_VERSION=.template-version
MARK_START='>>> template:'
MARK_END='<<< template:'
# The one block init.sh deletes everywhere, with the template's own README and itself.
INIT_BLOCK=init

# The placeholders init.sh fills in. Nothing the manifest lists may contain them, and that
# includes this file: each is written in two halves, so init.sh's search passes over it.
PLACEHOLDER_NAME='Project'' Name'
PLACEHOLDER_SLUG='project''-slug'
PLACEHOLDER_DESC='One-line project'' description.'
RELEASE_MANIFEST=.release-please-manifest.json
RELEASE_MANIFEST_INITIAL='{\n  ".": "0.0.0"\n}'

# --- Exit codes ---------------------------------------------------------------------------

EXIT_OK=0
# --check found a difference.
EXIT_DIFFERS=1
# Anything else. The drift workflow relies on it never being 1.
EXIT_ERROR=2
# What Claude Code and Codex read as "block this tool call".
EXIT_BLOCK=2

# --- Output -------------------------------------------------------------------------------

GLYPH_OK='✔'
GLYPH_FAIL='✖'
GLYPH_SKIP='–'
GLYPH_WARN='!'

# say <format> [<value>...]: one line on stdout.
say() {
    local format="$1"
    shift
    # shellcheck disable=SC2059 # the format is one of the messages here, never data
    printf -- "${format}\n" "$@"
}

ok() { say "${GLYPH_OK} $1" "${@:2}"; }
skip() { say "${GLYPH_SKIP} $1" "${@:2}"; }
fail() { say "${GLYPH_FAIL} $1" "${@:2}" >&2; }
warn() { say "    ${GLYPH_WARN} $1" "${@:2}" >&2; }

# die <format> [<value>...]: fail, then exit with DIE_STATUS (EXIT_ERROR unless the script
# sets it).
die() {
    fail "$@"
    exit "${DIE_STATUS:-${EXIT_ERROR}}"
}

# need_value <flag> [<value>]: dies unless the flag was given a value. Call it with "$@"
# from an argument loop, before reading $2.
need_value() {
    [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || die "${MSG_NEEDS_VALUE}" "$1"
}

# usage_of <script>: the script's header comment, as its --help.
usage_of() {
    awk 'NR == 1 { next }
        /^# Managed by/ { next }
        /^#/ { sub(/^# ?/, ""); print; next }
        { exit }' "$1"
}

# --- Shared messages ----------------------------------------------------------------------

MSG_NOT_GIT_REPO='not inside a git repository'
MSG_UNKNOWN_ARG='unknown argument: %s (see --help)'
MSG_NEEDS_VALUE='%s needs a value (see --help)'
MSG_NEEDS_TOOL='%s is not installed (brew install %s)'
MSG_CANNOT_CLONE='cannot clone %s at %s'

# --- template-sync.sh ---------------------------------------------------------------------

MSG_SYNC_NO_RELEASE='cannot find a release tag on %s (no access, or nothing released yet)'
MSG_SYNC_NOT_TEMPLATE='%s has no %s; is it the template?'
MSG_SYNC_NOT_IN_TEMPLATE='manifest lists %s, but the template does not have it'
MSG_SYNC_NO_BLOCK="the template's %s has no '%s' block"
MSG_SYNC_TEMPLATE_MARKERS="the template's %s: %s"
MSG_SYNC_NEEDS_NAME='manifest: block %s needs a name'
MSG_SYNC_UNKNOWN_ENTRY="manifest: unknown entry '%s %s'"
MSG_SYNC_UNKNOWN_FLAG="manifest: unknown flag '%s' on %s"
# The flag on a manifest entry .template-ignore cannot switch off.
FLAG_REQUIRED=required
MSG_SYNC_REQUIRED='%s: the template requires it, so %s has no effect; remove it there'
MSG_SYNC_BAD_PROFILE="%s: '%s' is not a profile name"
MSG_SYNC_NO_PROFILE="%s lists '%s', but the template has no %s.%s"
MSG_SYNC_FINDING='%s: %s'
MSG_SYNC_IGNORED='%s: ignored by %s'
MSG_SYNC_DIFF_LABEL='b/%s (template %s)'

FINDING_MISSING='missing'
FINDING_DIFFERS='differs'
FINDING_MODE='executable bit differs'
FINDING_BLOCK_MISSING="block '%s' is missing"
FINDING_BLOCK_DIFFERS="block '%s' differs"
FINDING_REQUIRED='listed in %s, but the template requires it'
# What is wrong with a block's markers, by the name markers_of gives it.
FINDING_MARKERS_UNCLOSED="block '%s' has a '>>>' marker and no '<<<' marker after it; fix the markers by hand"
FINDING_MARKERS_UNOPENED="block '%s' has a '<<<' marker and no '>>>' marker before it; fix the markers by hand"
FINDING_MARKERS_REPEATED="block '%s' appears more than once; keep one copy"

MSG_SYNC_UPDATED='%s: updated'
MSG_SYNC_CREATED="%s: created with block '%s'"
MSG_SYNC_APPENDED="%s: block '%s' appended; move it to where it belongs"
MSG_SYNC_BLOCK_UPDATED="%s: block '%s' updated"

MSG_SYNC_DRIFT='%d difference(s) from %s@%s (last synced: %s).'
MSG_SYNC_DRIFT_FIX="Run: ${DEVTOOLS} sync"
MSG_SYNC_IN_STEP='In step with %s@%s'
MSG_SYNC_DONE='Synced with %s@%s (%d updated). Review with: git diff'
SYNC_NEVER='never'

# --- github-setup.sh ----------------------------------------------------------------------

MSG_GH_NO_REPO='cannot find this repository on GitHub: does it have a remote, and is gh signed in?'
MSG_GH_NOT_ADMIN='settings and rulesets need an admin of %s, and you are not one'
MSG_GH_BAD_ENV='not an environment name: %s'
MSG_GH_SHARED_FAILED='%s@%s could not apply its settings to %s (exit %s)'
MSG_GH_NO_SHARED='%s@%s has no %s, so the shared settings and rulesets were skipped; try another --ref'
MSG_GH_FINDING='    %s'
MSG_GH_DESCRIPTION='description: %s -> %s'
MSG_GH_ENV_MISSING='environment %s: missing'
MSG_GH_DIFFERS="%s differs. Apply with: ${DEVTOOLS} github"
MSG_GH_SET_UP='%s is set up%s'
MSG_GH_SKIPPED=', apart from the shared settings and rulesets'

# --- init.sh ------------------------------------------------------------------------------

MSG_INIT_DONE_ALREADY="no ${TEMPLATE_DIR}/ here: this project is already initialised"
MSG_INIT_USAGE="usage: ${DEVTOOLS} init NAME=\"My Project\" SLUG=my-project DESC=\"What it is.\""
MSG_INIT_BAD_SLUG='SLUG must be kebab-case (lowercase letters, digits, single hyphens): %s'
MSG_INIT_DONE='%s (%s) is initialised.'
MSG_INIT_NO_GITHUB="GitHub is not set up. Fix the above, then: ${DEVTOOLS} github"
# main only takes pull requests once the rulesets are on, so the first commit is one.
MSG_INIT_NEXT="
    Next:
    ${DEVTOOLS} setup    # pinned tools + git hooks
    ${DEVTOOLS} check    # confirm everything passes
    git switch -c chore/initialise-project
    git add -A && git commit -m \"chore: initialise from project-template\"
    git push -u origin HEAD && gh pr create --fill

    Then fill in AGENTS.md (Project, Layout, Conventions) and README.md."

# --- agent-guard.sh -----------------------------------------------------------------------

# The org's lefthook jobs (studiobimo/.github, lefthook/org.yml) the guard runs by name,
# and the line lefthook prints for a job that failed.
GUARD_HOOK=pre-push
GUARD_JOB_PR_SIZE=pr-size
GUARD_JOB_BRANCH=branch-name
GUARD_JOB_FAILED='🥊 %s'
GUARD_RULE_PR_SIZE='PR size rule'
GUARD_RULE_BRANCH='branch naming rule'
MSG_GUARD_BLOCKED='Blocked by agent-guard (%s):\n%s'
