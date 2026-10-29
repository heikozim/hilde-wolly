#!/usr/bin/env bash
# Runs inside the build image: the negative control of the unit tests.  Each mutation
# breaks one check of src in a copy under _run/mutate and runs hilde test on
# the copy; a mutation the tests do not notice is a test that checks
# nothing.  A mutation of a file outside src (its path has a slash) is
# tested with scripts/test.sh in a copy of the whole tree, the end-to-end
# runs included.  The unmutated copy runs first and must be green, or nothing
# after it means anything.
#
#     bash scripts/mutate.sh
#     bash scripts/mutate.sh finalize
#     bash scripts/mutate.sh only mutations-step3.sh mutations-step8.sh ...
#
# With only, the mutations are those of the five below and of the step files
# named, as in the first form; the run of a whole tree takes the step files
# in several parts on several hosts, and every part names its step files, so
# that together they are all of them.
#
# With finalize the mutations are those of scripts/finalize-mutations.sh,
# all of the tree, and each copy runs QUICK=1 scripts/finalize-linux.sh
# instead of scripts/test.sh: they break the checks of stage finalize.
#
# The mutations run as jobs of scripts/jobs.sh, $JOBS at once (default:
# the cores), each in a copy and a working directory of its own;
# the verdicts are printed in the order of the mutations.  JOBS=1 runs them
# one after the other.
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || { echo "ABORT: bash ${BASH_VERSION} too old" >&2; exit 9; }
set -u
. scripts/env.sh
. scripts/jobs.sh
M=$RUN/mutate
MODE=${1:-}
ONLY=
if [ "$MODE" = only ]; then
	shift
	ONLY=" $* "
	MODE=
	[ "$ONLY" != "  " ] || { echo "ABORT: only without a step file -- nothing ran" >&2; exit 9; }
	echo "mutate: only$ONLY"
fi

# file|sed expression|what it breaks -- the expression must change the file.
mutations=()
case "$MODE" in
"")
	mutations=(
		"Response.hiq|s/(byte < 32)/(byte < 10)/|CR and other control bytes pass as a header value"
		"Response.hiq|0,/refused => true/s//refused => refused/|a refused header name is not remembered"
		"Response.hiq|s/\"content-type\"/\"content-typ\"/|a second Content-Type is allowed"
		# The headers between the Content-Type line and the empty line are Standard.FcgiServer's since Hilde took them over.
		"Response.hiq|s/cgiResponseWith(status, contentType, asSpan(\&headers), content)/cgiResponseWith(200, contentType, asSpan(\&headers), content)/|every answer has the status 200"
		"Response.hiq|s/if refused or (not isHeaderBlock(asSpan(\&headers))) then/if false then/|a refused response is sent anyway"
	)
	for more in "$WOLLY"/scripts/mutations-*.sh; do
		if [ -n "$ONLY" ]; then
			case "$ONLY" in *" $(basename "$more") "*) ;; *) continue ;; esac
		fi
		. "$more"
	done
	tree_run() { bash scripts/test.sh; }
	;;
finalize)
	. "$WOLLY/scripts/finalize-mutations.sh"
	tree_run() { QUICK=1 bash scripts/finalize-linux.sh; }
	;;
*) echo "ABORT: unknown mode $MODE" >&2; exit 9 ;;
esac

run_copy() {
	# first, when set, is the unit test of the mutated module: run
	# alone before the rest, a failure there is a caught mutation at once,
	# as it would be in the whole run; when it passes, src runs whole.  The
	# tests write files under their working directory: that is $M, the
	# copy's own.
	if [ -n "${first:-}" ] && [ -r "$first" ]; then
		(cd "$M" && "$HILDE" test --modules="$H/bindings/generated:$H/standard/src:$M/src" "$first") > "$M.log" 2>&1 || return 1
	fi
	src_all > "$M.log" 2>&1
}
# All test files of the copy $M/src, one job each in a working directory of
# its own (scripts/jobs.sh), their logs in the order of the files; exit 0
# when every file is green.  A subshell, so that the jobs of the mutations
# around it are not touched.
one_file() {
	local w=$M/w/$(basename "$1" .test.hiq)
	mkdir -p "$w" && cd "$w" || return 9
	"$HILDE" test --modules="$H/bindings/generated:$H/standard/src:$M/src" "$1"
}
src_all() (
	JOB_NAME=() JOB_AFTER=() JOB_FIRST=() JOB_CMD=() JOB_RC=()
	for t in "$M"/src/Wolly/*.test.hiq; do
		jobs_add "unit-$(basename "$t" .test.hiq)" - 0 one_file "$t"
	done
	jobs_run "$M/jobs" > "$M/jobs.out"
	rc=$?
	jobs_merge "$M/jobs" | grep -v '^job-time'
	rm -rf "$M/w" "$M/jobs" "$M/jobs.out"
	exit $rc
)
# A mutation whose description begins with "pg: " changes a statement for
# PostgreSQL: the unit tests of the copy run on PostgreSQL,
# against the test server of scripts/db/server.sh (in UTF8, as
# scripts/test.sh starts it).  Each job starts its own, named by the job's
# process, and stops it when the job ends: a test drops the schema public of
# its database, and two jobs must not share one.
pgenv=
pg_up() {
	[ -n "$pgenv" ] && return 0
	pgname=wmut$BASHPID
	pgenv=$(LC_ALL=C.UTF-8 sh "$WOLLY/scripts/db/server.sh" start postgres "$pgname") || { echo "ABORT: the test server did not start" >&2; exit 9; }
	trap 'sh "$WOLLY/scripts/db/server.sh" stop postgres "$pgname" > /dev/null 2>&1' EXIT
}
run_copy_pg() {
	pg_up
	(eval "$(echo "$pgenv" | sed -E 's/^([A-Z_]+)=(.*)$/export \1="\2"/')" &&
		cd "$M" && WOLLY_DB=postgres "$HILDE" test --modules="$H/bindings/generated:$H/standard/src" "$M/src") > "$M.log" 2>&1
}
copy_tree() {
	rm -rf "$M/tree" && mkdir -p "$M/tree" || exit 9
	cp -r "$WOLLY/src" "$WOLLY/examples" "$WOLLY/scripts" "$M/tree/" || exit 9
}

base=$M
rm -rf "$base" && mkdir -p "$base" || exit 9
M=$base/unmutated
rm -rf "$M" && cp -r "$WOLLY/src" "$M.tmp" && mkdir -p "$M" && mv "$M.tmp" "$M/src" || exit 9
if [ -z "$MODE" ]; then
	run_copy
else
	copy_tree
	(cd "$M/tree" && tree_run) > "$M.log" 2>&1
fi
if [ $? -ne 0 ]; then
	echo "ABORT: the unmutated copy is not green"; tail -20 "$M.log"; exit 1
fi
echo "unmutated: green"
# The unmutated copy on PostgreSQL too, when a mutation needs it.
for m in "${mutations[@]}"; do
	case "${m##*|}" in
	"pg: "*)
		if ! (run_copy_pg); then
			echo "ABORT: the unmutated copy is not green on PostgreSQL"
			grep -E '^ {4}FAIL|^FAIL|^hilde test:' "$M.log"
			tail -20 "$M.log"
			exit 1
		fi
		echo "unmutated on PostgreSQL: green"
		break
		;;
	esac
done
rm -rf "$M" "$M.log"

# One mutation, a job of scripts/jobs.sh, in the copy $base/m-<n>;
# its verdict is the last line of its log.  A run of a whole tree inside it
# (test.sh, finalize-linux.sh) takes one job at a time when the mutations
# run side by side, and its end-to-end runs ports of its own.
mutation() {
	local n=$1 m=$2 file rest what expr target original rc
	file=${m%%|*}
	rest=${m#*|}
	what=${rest##*|}
	expr=${rest%|*}
	M=$base/m-$n
	# Its own runs (src_all, a whole tree) take one job at a time when the
	# mutations run side by side, so that the jobs do not multiply.
	[ "$(jobs_slots)" -gt 1 ] && export JOBS=1
	mkdir -p "$M" || exit 9
	case "$file" in
	*/*)
		# A mutation of the tree: a copy of it, and the tree's run there with
		# the build and the end-to-end runs.
		first=
		copy_tree
		target="$M/tree/$file"
		original="$WOLLY/$file"
		;;
	*)
		rm -rf "$M/src" && cp -r "$WOLLY/src" "$M/src" || exit 9
		target="$M/src/Wolly/$file"
		original="$WOLLY/src/Wolly/$file"
		first="$M/src/Wolly/${file%.hiq}.test.hiq"
		;;
	esac
	sed -i "$expr" "$target"
	if cmp -s "$original" "$target"; then
		rm -rf "$M"
		echo "BROKEN  the mutation changed nothing: $file $expr"
		return 0
	fi
	case "$file" in
	scripts/jobs.sh)
		# The tree's run goes through the mutated jobs.sh itself, so a
		# mutation that loses the exits loses the run's verdict too: its test
		# runs alone, as in mutate-target.sh.
		(cd "$M/tree" && bash scripts/jobs.test.sh) > "$M.log" 2>&1
		rc=$?
		;;
	*/*)
		(cd "$M/tree" && PORT_BASE=$((20000 + 16 * n)) tree_run) > "$M.log" 2>&1
		rc=$?
		;;
	*)
		case "$what" in
		"pg: "*) run_copy_pg; rc=$? ;;
		*) run_copy; rc=$? ;;
		esac
		;;
	esac
	if [ $rc -eq 0 ]; then
		echo "MISSED  $what"
	else
		echo "caught  $what ($(grep -c -E '^ {4}FAIL|^FAIL|^section .*: FAILED' "$M.log") failing)"
	fi
	rm -rf "$M" "$M.log"
	return 0
}

for i in "${!mutations[@]}"; do
	jobs_add "mutation-$i" - 0 mutation "$i" "${mutations[$i]}"
done
jobs_run "$base/jobs" > "$base/jobs.out"
caught=0
for i in "${!mutations[@]}"; do
	line=$(tail -1 "$(job_log "$base/jobs" "$i")")
	echo "$line"
	case "$line" in caught*) caught=$((caught + 1)) ;; esac
done
rm -rf "$base"
echo "mutate: $caught of ${#mutations[@]} caught"
[ "${#mutations[@]}" -gt 0 ] && [ "$caught" -eq "${#mutations[@]}" ]
