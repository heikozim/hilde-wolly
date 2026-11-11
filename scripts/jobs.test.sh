#!/usr/bin/env bash
# The test of scripts/jobs.sh, run by scripts/test.sh: jobs whose
# outcome is known, one at a time and four at once.  A failed job counts,
# the job after it does not start and counts with 9, the merged logs are
# in the order the jobs were added and the same for one slot and four, four
# slots are faster than one, and an argument with a space reaches the job.
#
#     bash scripts/jobs.test.sh
[ "${BASH_VERSINFO[0]:-0}" -ge 5 ] || { echo "ABORT: bash ${BASH_VERSION} too old for jobs.sh -- nothing ran" >&2; exit 9; }
set -u
. scripts/jobs.sh
d=$(mktemp -d "${TMPDIR:-/tmp}/jobs-test.XXXXXX") || exit 9
trap 'rm -rf "$d"' EXIT
checks=0
good=0
check() {
	local name=$1
	shift
	checks=$((checks + 1))
	if "$@"; then good=$((good + 1)); echo "ok    $name"; else echo "FAIL  $name"; fi
}
work() { sleep "$1"; echo "done $2"; return "$3"; }
declare -A took rc_of
for slots in 1 4; do
	JOB_NAME=() JOB_AFTER=() JOB_FIRST=() JOB_CMD=() JOB_RC=()
	jobs_add a - 0 work 0.6 a 0
	jobs_add b - 0 work 0.2 b 0
	jobs_add c a 0 work 0.1 c 0
	jobs_add f - 0 work 0.1 f 3
	jobs_add g f 0 work 0.1 g 0
	jobs_add h - 1 work 0.3 "h with space" 0
	start=$SECONDS
	t0=${EPOCHREALTIME/,/.}
	JOBS=$slots jobs_run "$d/s$slots" > "$d/run$slots.out"
	rc_of[$slots]=$?
	t1=${EPOCHREALTIME/,/.}
	took[$slots]=$(awk -v a="$t0" -v b="$t1" 'BEGIN { printf "%d", (b - a) * 1000 }')
	jobs_merge "$d/s$slots" | grep -v '^job-time' > "$d/merge$slots.out"
	check "$slots slots: the run fails, as one job does" [ "${rc_of[$slots]}" -ne 0 ]
	check "$slots slots: the failed job keeps its exit 3" [ "$(jobs_rc f)" = 3 ]
	check "$slots slots: the job after it does not start, exit 9" [ "$(jobs_rc g)" = 9 ]
	check "$slots slots: the job after a green one ran" [ "$(jobs_rc c)" = 0 ]
	check "$slots slots: two of six not with 0" grep -q "^jobs: 6 ended, 2 not with 0$" "$d/run$slots.out"
	check "$slots slots: the log of the job not started says why" grep -q "^not started: f ended with 3$" "$d/merge$slots.out"
	check "$slots slots: an argument with a space arrives whole" grep -q "^done h with space$" "$d/merge$slots.out"
done
# Two slots, five jobs of 0.3 s that need nothing: never more than two at
# once, by their start and end (scripts/jobs.sh writes them to <log>.time).
JOB_NAME=() JOB_AFTER=() JOB_FIRST=() JOB_CMD=() JOB_RC=()
for n in p q r s t; do jobs_add "$n" - 0 work 0.3 "$n" 0; done
JOBS=2 jobs_run "$d/two" > "$d/run2.out"
most=$(cat "$d"/two/*.time | tr ',' '.' | awk '{ print $1, 1; print $2, -1 }' | sort -k1,1n -k2,2n |
	awk '{ now += $2; if (now > most) most = now } END { print most + 0 }')
check "two slots: at most two jobs at once ($most)" [ "$most" -le 2 ]
check "two slots: the five ran" [ "$(ls "$d"/two/*.time | wc -l | tr -d ' ')" = 5 ]
order=$(grep '^== job ' "$d/merge4.out" | tr '\n' ' ')
check "the merged logs in the order of jobs_add" [ "$order" = "== job a == job b == job c == job f == job g == job h " ]
check "the merged logs the same for one slot and four" cmp -s "$d/merge1.out" "$d/merge4.out"
# One slot sleeps 1.3 s in all; four, along a then c, 0.7 s.
check "four slots faster than one (${took[4]} ms, ${took[1]} ms)" [ "${took[4]}" -lt $((took[1] - 300)) ]
echo "jobs.test: $good of $checks checks good"
[ "$good" -eq "$checks" ]
