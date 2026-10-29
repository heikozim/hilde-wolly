#!/usr/bin/env bash
# Runs inside the build image: the Linux
# part of stage finalize.  The unit tests under each instrument of hilde
# test (--memory, --race, --valgrind), then for each variant of
# scripts/build.sh every example built that way and run end to end over
# http and over https, the valgrind build under valgrind.  Before the runs
# of a variant its controls, programmes with a known fault, must be
# reported by the instrument, or a green run means nothing.  A section that
# could not run counts as failed, not as passed.
#
#     bash scripts/finalize-linux.sh
#     QUICK=1 bash scripts/finalize-linux.sh   # for scripts/mutate.sh finalize
#
# QUICK leaves out the unit tests and runs only examples/hello over http.
#
# The parts run as jobs of scripts/jobs.sh, $JOBS at once (default: the
# cores): each test file under each instrument in a working
# directory of its own, the build of each variant in a run directory of its
# own (WOLLY_RUN), and after it its controls and each end-to-end run, each
# on a port of its own.  JOBS=1 runs the same jobs one after the other.
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || { echo "ABORT: bash ${BASH_VERSION} too old" >&2; exit 9; }
set -u
. scripts/env.sh
. scripts/jobs.sh
QUICK=${QUICK:-0}

echo "== $(id -un 2> /dev/null || id -u) in $(uname -srm)"
sed "s/^/   /" "$WOLLY_ID"
echo "cc: $(cc --version | head -1)"
command -v valgrind > /dev/null 2>&1 || { echo "ABORT: valgrind not on PATH -- nothing ran" >&2; exit 9; }
echo "valgrind: $(valgrind --version)"
J=$RUN/jobs-finalize
rm -rf "$J" && mkdir -p "$J/work" || exit 9
# The order of the glob, the same on every machine.
LC_ALL=C
tests=(src/Wolly/*.test.hiq)
modules="$H/bindings/generated:$H/standard/src"

# A section line; the count is taken from the lines of all jobs at the end.
section() {
	local name=$1 rc=$2
	if [ "$rc" -eq 0 ]; then
		echo "section $name: ok"
	else
		echo "section $name: FAILED rc=$rc"
	fi
}

valgrind_wrap=(valgrind --quiet --error-exitcode=66 --leak-check=full --errors-for-leak-kinds=definite --show-leak-kinds=definite)

# control <binary> <pattern> [wrapper...]: the binary must end with a status
# other than 0 and its output must name the fault.
control() {
	local bin=$1 pattern=$2 rc
	shift 2
	"$@" "$bin" > "$bin.out" 2>&1 < /dev/null
	rc=$?
	echo "control $(basename "$bin"): rc=$rc, report $(grep -c -E -- "$pattern" "$bin.out") lines"
	[ $rc -ne 0 ] && grep -q -E -- "$pattern" "$bin.out" && return 0
	head -20 "$bin.out" | sed 's/^/      /'
	return 1
}

# The report each control must bring, by the name of its file.
declare -A reports=(
	[memory-asan]="AddressSanitizer: heap-use-after-free"
	[memory-ubsan]="runtime error: signed integer overflow"
	[race-tsan]="ThreadSanitizer: data race"
	[valgrind-memcheck]="Conditional jump or move depends on uninitialised value"
)

# One test file under one instrument, in a working directory of its own.
unit_file() {
	local instrument=$1 file=$2 w
	w=$J/work/unit-$instrument-$(basename "$file" .test.hiq)
	mkdir -p "$w" && cd "$w" || return 9
	"$HILDE" test --"$instrument" --modules="$modules:$WOLLY/src" "$WOLLY/$file"
}

# The build of a variant in a run directory of its own.  A failed build
# still runs what it built (controls and examples): the job ends with 0 and
# its section says how the build went.
build_variant() {
	local variant=$1
	echo "== build $variant"
	WOLLY_RUN=$J/run-$variant VARIANT=$variant bash scripts/build.sh
	section "build-$variant" $?
	return 0
}

controls_of() {
	local variant=$1 bin name controls=0
	for bin in "$J/run-$variant"/control/*; do
		case "$bin" in *.out) continue ;; esac
		[ -x "$bin" ] || continue
		name=$(basename "$bin")
		[ -n "${reports[$name]:-}" ] || { section "control-$name-has-a-report" 1; continue; }
		controls=$((controls + 1))
		if [ "$variant" = valgrind ]; then
			control "$bin" "${reports[$name]}" "${valgrind_wrap[@]}"
		else
			control "$bin" "${reports[$name]}"
		fi
		section "control-$name" $?
	done
	echo "controls-run=$controls"
}

e2e_of() {
	local variant=$1 app=$2 tls=$3 port=$4 wrap= scheme=http over= instrumented=0
	[ "$tls" = 1 ] && scheme=https over=", over TLS"
	[ -x "$J/run-$variant/bin/$app" ] || { echo "e2e $app, $variant: not built, not run"; return 0; }
	[ "$variant" = valgrind ] && wrap=${valgrind_wrap[*]}
	# memory and race are built with sanitizers, many times slower: the
	# waits of valgrind for them (scripts/e2e.sh).
	case "$variant" in memory | race) instrumented=1 ;; esac
	echo "== end to end: $app, $variant$over"
	WOLLY_RUN=$J/run-$variant PORT=$port WRAP=$wrap INSTRUMENTED=$instrumented TLS=$tls bash scripts/e2e.sh "$app"
	section "e2e-$app-$variant-$scheme" $?
	return 0
}

if [ "$QUICK" != 1 ]; then
	for instrument in memory race valgrind; do
		for t in "${tests[@]}"; do
			jobs_add "unit-$instrument-$(basename "$t" .test.hiq)" - 0 unit_file "$instrument" "$t"
		done
	done
fi
# PORT_BASE: the first port of the end-to-end runs, for a run beside others
# (scripts/mutate.sh runs mutated trees side by side).
port=${PORT_BASE:-18493}
for variant in o1 memory race valgrind; do
	jobs_add "build-$variant" - 1 build_variant "$variant"
	jobs_add "controls-$variant" "build-$variant" 1 controls_of "$variant"
	for dir in examples/*/; do
		app=$(basename "$dir")
		[ "$QUICK" = 1 ] && [ "$app" != hello ] && continue
		jobs_add "e2e-$app-$variant-http" "build-$variant" 1 e2e_of "$variant" "$app" 0 "$port"
		port=$((port + 1))
		[ "$QUICK" = 1 ] && continue
		jobs_add "e2e-$app-$variant-https" "build-$variant" 1 e2e_of "$variant" "$app" 1 "$port"
		port=$((port + 1))
	done
done

jobs_run "$J/logs"
jobs_merge "$J/logs" > "$J/merged.log"
cat "$J/merged.log"

# The unit tests under an instrument are one section, as in a run of all of
# src: green when every file is.
if [ "$QUICK" != 1 ]; then
	for instrument in memory race valgrind; do
		rc=0
		for t in "${tests[@]}"; do
			[ "$(jobs_rc "unit-$instrument-$(basename "$t" .test.hiq)")" = 0 ] || rc=1
		done
		section "unit-$instrument" $rc >> "$J/merged.log"
		section "unit-$instrument" $rc
	done
fi
# A job that ended otherwise than with 0 lost its sections: a section of its own.
for i in "${!JOB_NAME[@]}"; do
	case "${JOB_NAME[$i]}" in unit-*) continue ;; esac
	rc=$(jobs_rc "${JOB_NAME[$i]}")
	[ "$rc" = 0 ] || { section "job-${JOB_NAME[$i]}" "$rc" >> "$J/merged.log"; section "job-${JOB_NAME[$i]}" "$rc"; }
done

# Each control of the variants run here, once: memory has two, race and
# valgrind one.
want=$(( ${#reports[@]} ))
seen=$(ls scripts/controls/memory-*.c scripts/controls/race-*.c scripts/controls/valgrind-*.c | wc -l)
echo "control-files=$seen (want $want)"
[ "$seen" -eq "$want" ] || { section "control-files" 1 >> "$J/merged.log"; section "control-files" 1; }
sections=$(grep -c '^section ' "$J/merged.log")
good=$(grep -c '^section .*: ok$' "$J/merged.log")
echo "finalize-linux: $good of $sections sections good"
[ "$sections" -gt 0 ] && [ "$good" -eq "$sections" ]
