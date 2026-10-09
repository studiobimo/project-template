#!/usr/bin/env bash
# Finds JVMs this project's builds left behind: Gradle daemons and Minecraft dev
# runs that outlived the build that started them.
#
# A dev run forks a Minecraft JVM that can survive if the build is interrupted --
# a hung `runClientGameTest`, a cancelled task, a closed terminal. Those show up
# as gigabyte-sized `java` processes with nothing left to stop them.
#
# Only orphans (parent PID 1) whose command line names this project are matched,
# so an editor's Java language server and its Gradle daemon, a running build, and
# a dev server you started on purpose are all left alone.
#
#   stray-java.sh          list what would be stopped (exit 1 if any)
#   stray-java.sh --kill   stop them (SIGTERM, then SIGKILL)
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
kill_them=false
[[ "${1:-}" == "--kill" ]] && kill_them=true

# pid<TAB>rss-in-kb<TAB>command, for orphaned JVMs that mention this project.
strays="$(
    ps -axo pid=,ppid=,rss=,command= |
        awk -v root="${root}" '
            $2 == 1 && $4 ~ /\/java$/ && index($0, root) > 0 {
                pid = $1; rss = $3
                $1 = $2 = $3 = ""
                sub(/^ +/, "")
                printf "%s\t%s\t%s\n", pid, rss, $0
            }' || true
)"

[[ -n "${strays}" ]] || exit 0

total=0
while IFS=$'\t' read -r pid rss command; do
    total=$((total + rss))
    printf 'stray JVM %s (%d MB): %.120s\n' "${pid}" "$((rss / 1024))" "${command}" >&2
done <<<"${strays}"
printf '%s orphaned build JVM(s), %d MB total\n' "$(wc -l <<<"${strays}" | tr -d ' ')" "$((total / 1024))" >&2

if [[ "${kill_them}" != true ]]; then
    printf 'Stop them with: make -C .devtools kill-stray\n' >&2
    exit 1
fi

pids=()
while IFS=$'\t' read -r pid _; do
    pids+=("${pid}")
done <<<"${strays}"

kill "${pids[@]}" 2>/dev/null || true
for _ in 1 2 3 4 5; do
    sleep 1
    ps -p "$(
        IFS=,
        printf '%s' "${pids[*]}"
    )" >/dev/null 2>&1 || exit 0
done
kill -9 "${pids[@]}" 2>/dev/null || true
