#!/usr/bin/env bash
# Runs inside the build image: the mutations of the step files given, each in a
# copy of the tree and against the checks that can see it, instead of
# scripts/test.sh whole:
#
#   - src/Wolly/X.hiq or .hih (named X.hiq or by its path): the unit test
#     src/Wolly/X.test.hiq, and the build and the end-to-end runs, http and
#     TLS, of every example whose programme holds Wolly.X, directly or
#     through another module;
#   - examples/<app>/... and scripts/e2e-<app>.sh: the build and the
#     end-to-end runs of that example.
#
# A mutation whose description begins with "pg: " changes a statement for
# PostgreSQL: only the unit tests of the module and of the
# schema (src/Wolly/Schema.test.hiq) see it, run
# with WOLLY_DB=postgres against the test server of scripts/db/server.sh, which
# each job that needs it starts and stops (it needs the user for uid 1000 that
# the build image makes).
#
# The unmutated checks and then the mutations run as jobs of
# scripts/jobs.sh, $JOBS at once (default: the cores), each in a
# copy of its own with ports of its own; the verdicts are printed in the
# order of the mutations.  JOBS=1 runs them one after the other.
#
# A mutation with no check to see it, or of any other file, aborts the
# run: it belongs to scripts/mutate.sh.  Before the mutations the same
# checks run on the unmutated tree and must be green.  The whole run --
# test.sh, mutate.sh, mutate.sh finalize, finalize-linux.sh -- is the check
# of a release.
#
#     bash scripts/mutate-target.sh [--shard=K/N] scripts/mutations-step36.sh ...
#
# --shard=K/N runs only the mutations whose place in the list, from 0, is K
# modulo N, so that N hosts share a round;
# the unmutated checks run on each.
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || { echo "ABORT: bash ${BASH_VERSION} too old" >&2; exit 9; }
set -u
. scripts/env.sh
. scripts/jobs.sh
shard=0
shards=1
case "${1:-}" in
--shard=*)
	spec=${1#--shard=}
	shard=${spec%/*}
	shards=${spec#*/}
	case "$shard/$shards" in
	*[!0-9/]* | /* | */) echo "ABORT: --shard=$spec is not K/N -- nothing ran" >&2; exit 9 ;;
	esac
	[ "$shards" -ge 1 ] && [ "$shard" -lt "$shards" ] || { echo "ABORT: --shard=$spec needs 0 <= K < N -- nothing ran" >&2; exit 9; }
	shift
	;;
esac
[ $# -gt 0 ] || { echo "ABORT: no step file given -- nothing ran" >&2; exit 9; }
M=$RUN/mutate-target
mutations=()
for step in "$@"; do
	[ -r "$step" ] || { echo "ABORT: $step not readable -- nothing ran" >&2; exit 9; }
	# shellcheck disable=SC1090
	. "$step"
done
[ ${#mutations[@]} -gt 0 ] || { echo "ABORT: the step files hold no mutation -- nothing ran" >&2; exit 9; }
if [ "$shards" -gt 1 ]; then
	all=${#mutations[@]}
	kept=()
	for i in "${!mutations[@]}"; do
		[ $((i % shards)) -eq "$shard" ] && kept+=("${mutations[$i]}")
	done
	mutations=("${kept[@]}")
	echo "shard $shard/$shards: ${#mutations[@]} of $all mutations"
	[ ${#mutations[@]} -gt 0 ] || { echo "mutate-target: 0 of 0 caught"; exit 0; }
fi

# The examples, and the modules of each programme, read once from the
# unmutated tree.
declare -A holds
apps=()
for dir in examples/*/; do
	app=$(basename "$dir")
	hih=$(ls "$dir"*.hih 2> /dev/null | head -1)
	[ -n "$hih" ] || { echo "ABORT: $dir has no .hih" >&2; exit 9; }
	mods=$(program_modules "$hih,${hih%.hih}.hiq") || { echo "ABORT: the modules of $app were not found" >&2; exit 9; }
	holds[$app]=" $mods "
	apps+=("$app")
done

# The path of the mutated file, from the first field of a mutation.
path_of() {
	case "$1" in
	*/*) echo "$1" ;;
	*) echo "src/Wolly/$1" ;;
	esac
}

# The checks of a file, as words: unit:<test file>, unitpg:<test file> and
# app:<example>.  $2 is the description of the mutation: "pg: ..." has the
# unit test on PostgreSQL as its only check.
checks_of() {
	local path=$1 what=${2:-} base module app t
	case "$path" in
	src/Wolly/*.hiq | src/Wolly/*.hih)
		base=${path#src/Wolly/}
		base=${base%.*}
		case "$what" in
		"pg: "*)
			for t in "src/Wolly/$base.test.hiq" "src/Wolly/${base}Part"[0-9]*.test.hiq; do
				[ -r "$t" ] && echo "unitpg:$t"
			done
			# the tables of all modules in one database: their types (src/Wolly/Schema.test.hiq)
			[ "$base" = Schema ] || echo "unitpg:src/Wolly/Schema.test.hiq"
			return 0
			;;
		esac
		# The unit test of the module and its parts (X.test.hiq, XPart1.test.hiq
		# and so on: a long one cut so that no file runs over a minute).
		for t in "src/Wolly/$base.test.hiq" "src/Wolly/${base}Part"[0-9]*.test.hiq; do
			[ -r "$t" ] && echo "unit:$t"
		done
		# A test cut by its topic, not by its module, names the modules it
		# checks on a line "-- Checks: A B" of its head.
		for t in src/Wolly/*.test.hiq; do
			case "$t" in "src/Wolly/$base.test.hiq" | "src/Wolly/${base}Part"[0-9]*.test.hiq) continue ;; esac
			grep -qE "^-- Checks:( [A-Za-z]+)* $base( |\$)" "$t" && echo "unit:$t"
		done
		for app in "${apps[@]}"; do
			case "${holds[$app]}" in
			*"/Wolly/$base.hih,"*) echo "app:$app" ;;
			esac
		done
		# An interface states its contracts.
		case "$path" in *.hih) echo "sh:scripts/check-contracts.test.sh" ;; esac
		;;
	examples/*/*)
		app=${path#examples/}
		echo "app:${app%%/*}"
		;;
	scripts/e2e-*.sh)
		app=${path#scripts/e2e-}
		echo "app:${app%.sh}"
		;;
	scripts/jobs.sh)
		echo "sh:scripts/jobs.test.sh"
		;;
	scripts/check-contracts.pl | scripts/check-contracts.test.sh)
		echo "sh:scripts/check-contracts.test.sh"
		;;
	esac
}

# The test server for PostgreSQL, started on the first check of a job that
# needs it; its HILDE_PG_* lines are in pgenv.  A job is a subshell of its
# own (scripts/jobs.sh), so each job has its own server, named by the
# process of the job, and stops it when the job ends: a test drops the
# schema public of its database, and two jobs must not share one.
pgenv=
pg_up() {
	[ -n "$pgenv" ] && return 0
	pgname=wmut$BASHPID
	# UTF8, not the SQL_ASCII of the C locale (scripts/test.sh)
	pgenv=$(LC_ALL=C.UTF-8 sh "$WOLLY/scripts/db/server.sh" start postgres "$pgname") || { echo "ABORT: the test server did not start" >&2; exit 9; }
	trap 'sh "$WOLLY/scripts/db/server.sh" stop postgres "$pgname" > /dev/null 2>&1' EXIT
}

# Runs the checks given as words in the tree $1, the end-to-end runs on the
# ports $PORT and $PORT + 1; exit 0 when all are green.
run_checks() {
	local tree=$1 check rc=0
	shift
	for check in "$@"; do
		case "$check" in
		unit:*)
			echo "== unit ${check#unit:}"
			(cd "$tree" && "$HILDE" test --modules="$H/bindings/generated:$H/standard/src:$tree/src" "${check#unit:}") || rc=1
			;;
		unitpg:*)
			echo "== unit on PostgreSQL ${check#unitpg:}"
			pg_up
			(cd "$tree" && eval "$(echo "$pgenv" | sed -E 's/^([A-Z_]+)=(.*)$/export \1="\2"/')" \
				&& WOLLY_DB=postgres "$HILDE" test --modules="$H/bindings/generated:$H/standard/src:$tree/src" "${check#unitpg:}") || rc=1
			;;
		app:*)
			echo "== build and end to end ${check#app:}"
			(cd "$tree" && ONLY=${check#app:} bash scripts/build.sh && bash scripts/e2e.sh "${check#app:}" && PORT=$((PORT + 1)) TLS=1 bash scripts/e2e.sh "${check#app:}") || rc=1
			;;
		sh:*)
			echo "== ${check#sh:}"
			(cd "$tree" && bash "${check#sh:}") || rc=1
			;;
		esac
	done
	return $rc
}

# A copy of the tree for one job.
copy_tree() {
	rm -rf "$1/tree" && mkdir -p "$1/tree" || exit 9
	cp -r "$WOLLY/src" "$WOLLY/examples" "$WOLLY/scripts" "$1/tree/" || exit 9
}

# Every mutation has a check; their union runs first, unmutated, one job a
# check, each in a copy of its own.
declare -A union
for m in "${mutations[@]}"; do
	file=${m%%|*}
	what=${m##*|}
	found=$(checks_of "$(path_of "$file")" "$what")
	[ -n "$found" ] || { echo "ABORT: no check sees the mutation \"$what\" of $file -- it belongs to mutate.sh" >&2; exit 9; }
	for c in $found; do union[$c]=1; done
done
rm -rf "$M" && mkdir -p "$M" || exit 9

# One unmutated check in the copy $M/u-<n>.
unmutated() {
	local n=$1 check=$2
	copy_tree "$M/u-$n"
	export PORT=$((18493 + 2 * n))
	run_checks "$M/u-$n/tree" "$check"
	local rc=$?
	rm -rf "$M/u-$n"
	return $rc
}

# One mutation in the copy $M/m-<n>: its verdict is the last line of the job.
mutation() {
	local n=$1 m=$2 file rest what expr path start rc
	file=${m%%|*}
	rest=${m#*|}
	what=${rest##*|}
	expr=${rest%|*}
	path=$(path_of "$file")
	copy_tree "$M/m-$n"
	sed -i "$expr" "$M/m-$n/tree/$path"
	if cmp -s "$WOLLY/$path" "$M/m-$n/tree/$path"; then
		echo "BROKEN  the mutation changed nothing: $file $expr"
		rm -rf "$M/m-$n"
		return 0
	fi
	start=$SECONDS
	# shellcheck disable=SC2046
	export PORT=$((18493 + 2 * n))
	run_checks "$M/m-$n/tree" $(checks_of "$path" "$what") > "$M/m-$n.log" 2>&1
	rc=$?
	if [ $rc -eq 0 ]; then
		echo "MISSED  $what ($((SECONDS - start)) s)"
	else
		echo "caught  $what ($(grep -c -E '^ {4}FAIL|^FAIL|^section .*: FAILED' "$M/m-$n.log") failing, $((SECONDS - start)) s)"
	fi
	rm -rf "$M/m-$n" "$M/m-$n.log"
	return 0
}

start=$SECONDS
n=0
checks=()
for c in "${!union[@]}"; do checks+=("$c"); done
mapfile -t checks < <(printf '%s\n' "${checks[@]}" | LC_ALL=C sort)
for c in "${checks[@]}"; do
	jobs_add "unmutated-$n" - 1 unmutated "$n" "$c"
	n=$((n + 1))
done
if ! jobs_run "$M/unmutated" > "$M/unmutated.out"; then
	echo "ABORT: the unmutated checks are not green"
	jobs_merge "$M/unmutated" | grep -E '^== job |FAIL|ABORT|rc=' | tail -40
	exit 1
fi
echo "unmutated: green (${#checks[@]} checks: ${checks[*]}) $((SECONDS - start)) s"

JOB_NAME=() JOB_AFTER=() JOB_FIRST=() JOB_CMD=() JOB_RC=()
for i in "${!mutations[@]}"; do
	jobs_add "mutation-$i" - 0 mutation "$i" "${mutations[$i]}"
done
jobs_run "$M/mutations" > "$M/mutations.out"
caught=0
for i in "${!mutations[@]}"; do
	line=$(tail -1 "$(job_log "$M/mutations" "$i")")
	echo "$line"
	case "$line" in caught*) caught=$((caught + 1)) ;; esac
done
rm -rf "$M"
echo "mutate-target: $caught of ${#mutations[@]} caught"
[ "$caught" -eq "${#mutations[@]}" ]
