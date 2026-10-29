# Sourced by the test scripts: runs the sections of a run as jobs, at most
# $JOBS at once, each with its own log, and puts the logs together in the
# order the jobs were added, so that the output does not depend on which
# job ended first.  JOBS=1 runs them one after the other in that order, the
# reference a parallel run is compared with.
#
#     jobs_add <name> <after> <first> <function> [args...]
#     jobs_run <directory>      # exit 0 when every job ended with 0
#     jobs_merge <directory>    # the logs, in the order of jobs_add
#     jobs_rc <name>            # the exit of one job after jobs_run
#
# <after> is the name of a job this one needs, or -; a job whose <after>
# failed is not started and counts with exit 9, its log says why.  <first>
# is 0 or 1: among the jobs ready to start, those with 1 start before the
# others (a long chain, such as a build with end-to-end runs after it), in
# the order they were added.  A job runs in a subshell; what it needs from
# the caller is in functions and variables set before jobs_run.
JOB_NAME=()
JOB_AFTER=()
JOB_FIRST=()
JOB_CMD=()
declare -A JOB_RC=()

jobs_add() {
	local name=$1 after=$2 first=$3
	shift 3
	case "$name" in *[!A-Za-z0-9._-]*) echo "ABORT: job name $name" >&2; exit 9 ;; esac
	JOB_NAME+=("$name")
	JOB_AFTER+=("$after")
	JOB_FIRST+=("$first")
	JOB_CMD+=("$(printf '%q ' "$@")")
}

# The number of slots: JOBS, else the cores of the machine.
jobs_slots() {
	local n=${JOBS:-}
	[ -n "$n" ] || n=$(nproc 2> /dev/null || sysctl -n hw.ncpu 2> /dev/null || echo 1)
	case "$n" in '' | *[!0-9]* | 0) n=1 ;; esac
	echo "$n"
}

# Runs the command $1 of a job and writes its start and end, in seconds since
# the epoch, to $2.time; the exit is the command's.
job_timed() {
	local start=$EPOCHREALTIME rc
	(eval "$1")
	rc=$?
	echo "$start $EPOCHREALTIME" > "$2.time"
	return $rc
}

# The log of job $2 in the directory $1.
job_log() {
	printf '%s/%03d-%s.log' "$1" "$2" "${JOB_NAME[$2]}"
}

jobs_run() {
	local dir=$1 slots i k running=0 pid rc order=() failed=0 started
	local -A pid_of=() state=()
	slots=$(jobs_slots)
	mkdir -p "$dir" || exit 9
	# wait -n -p needs bash 5.1; an older bash runs the jobs one by one.
	if [ "$slots" -gt 1 ] && { [ "${BASH_VERSINFO[0]}" -lt 5 ] || { [ "${BASH_VERSINFO[0]}" -eq 5 ] && [ "${BASH_VERSINFO[1]}" -lt 1 ]; }; }; then
		echo "jobs: bash $BASH_VERSION has no wait -n -p, one job at a time"
		slots=1
	fi
	for i in "${!JOB_NAME[@]}"; do [ "${JOB_FIRST[$i]}" = 1 ] && order+=("$i"); done
	for i in "${!JOB_NAME[@]}"; do [ "${JOB_FIRST[$i]}" = 1 ] || order+=("$i"); done
	for i in "${!JOB_NAME[@]}"; do state[$i]=pending; done
	echo "jobs: ${#JOB_NAME[@]} jobs, $slots at once"
	while :; do
		started=0
		for i in "${order[@]}"; do
			[ "${state[$i]}" = pending ] || continue
			if [ "${JOB_AFTER[$i]}" != - ]; then
				rc=${JOB_RC[${JOB_AFTER[$i]}]:-}
				[ -n "$rc" ] || continue
				if [ "$rc" -ne 0 ]; then
					echo "not started: ${JOB_AFTER[$i]} ended with $rc" > "$(job_log "$dir" "$i")"
					state[$i]=9
					JOB_RC[${JOB_NAME[$i]}]=9
					started=1
					continue
				fi
			fi
			[ "$running" -lt "$slots" ] || break
			if [ "$slots" -eq 1 ]; then
				job_timed "${JOB_CMD[$i]}" "$(job_log "$dir" "$i")" > "$(job_log "$dir" "$i")" 2>&1 < /dev/null
				rc=$?
				state[$i]=$rc
				JOB_RC[${JOB_NAME[$i]}]=$rc
				started=1
				# One at a time: start again from the front of the order.
				break
			fi
			job_timed "${JOB_CMD[$i]}" "$(job_log "$dir" "$i")" > "$(job_log "$dir" "$i")" 2>&1 < /dev/null &
			pid_of[$!]=$i
			state[$i]=running
			running=$((running + 1))
			started=1
		done
		[ "$started" = 1 ] && [ "$slots" -eq 1 ] && continue
		if [ "$running" -eq 0 ]; then
			[ "$started" = 1 ] && continue
			break
		fi
		wait -n -p pid
		rc=$?
		k=${pid_of[$pid]}
		unset "pid_of[$pid]"
		state[$k]=$rc
		JOB_RC[${JOB_NAME[$k]}]=$rc
		running=$((running - 1))
	done
	for i in "${!JOB_NAME[@]}"; do
		case "${state[$i]}" in
		0) ;;
		pending) echo "jobs: ${JOB_NAME[$i]} never ran"; JOB_RC[${JOB_NAME[$i]}]=9; failed=$((failed + 1)) ;;
		*) failed=$((failed + 1)) ;;
		esac
	done
	echo "jobs: ${#JOB_NAME[@]} ended, $failed not with 0"
	[ "$failed" -eq 0 ]
}

# Each log after a line "== job <name>", in the order of jobs_add; the
# times go to the end, one line per job, apart from the logs.
jobs_merge() {
	local dir=$1 i log t
	for i in "${!JOB_NAME[@]}"; do
		echo "== job ${JOB_NAME[$i]}"
		cat "$(job_log "$dir" "$i")"
	done
	for i in "${!JOB_NAME[@]}"; do
		log=$(job_log "$dir" "$i")
		t=-
		[ -r "$log.time" ] && t=$(awk '{ gsub(",", "."); printf "%.1f", $2 - $1 }' "$log.time")
		echo "job-time ${JOB_NAME[$i]} ${t} s rc=${JOB_RC[${JOB_NAME[$i]}]:-9}"
	done
}

jobs_rc() {
	echo "${JOB_RC[$1]:-9}"
}
