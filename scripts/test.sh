#!/usr/bin/env bash
# Runs inside the build image: the unit tests under
# src with hilde test, on SQLite and on PostgreSQL, then the build of every
# example and an end-to-end run of each behind Hiawatha, the check that
# every public function states its contract, and hilde test --contracts over
# each module that has one.  Exit 0 only when all six are green.
#
# The parts run as jobs of scripts/jobs.sh, $JOBS at once (default: the
# cores): each unit test file on SQLite, the RAMBO check, the test
# of scripts/jobs.sh itself (scripts/jobs.test.sh), the unit
# tests on PostgreSQL in shards of their own server each, the build of each
# example, and the two end-to-end runs of an example once its build is
# done.  A unit job works in a directory of its own, since the tests write
# files under their working directory; an end-to-end run has a port of its
# own.  JOBS=1 runs the same jobs one after the other.
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || { echo "ABORT: bash ${BASH_VERSION} too old" >&2; exit 9; }
set -u
. scripts/env.sh
. scripts/jobs.sh

echo "== $(id -un 2> /dev/null || id -u) in $(uname -sr)"
sed "s/^/   /" "$WOLLY_ID"
J=$RUN/jobs-test
rm -rf "$J" && mkdir -p "$J/work" || exit 9
# The order of the glob, the same on every machine.
LC_ALL=C
tests=(src/Wolly/*.test.hiq)
[ -r "${tests[0]}" ] || { echo "ABORT: no test file under src/Wolly"; exit 9; }
modules="$H/bindings/generated:$H/standard/src"

# One test file on SQLite, in a working directory of its own.
unit_file() {
	local w=$J/work/unit-$(basename "$1" .test.hiq)
	mkdir -p "$w" && cd "$w" || return 9
	"$HILDE" test --modules="$modules:$WOLLY/src" "$WOLLY/$1"
}

# Where libcrypto has no ML-DSA (LibreSSL) the Rambo tests take another branch
# and say so. The image's OpenSSL has it: on Linux that line must not be
# there and the token of RAMBO's form must have verified (--verbose shows both).
rambo_check() {
	local w=$J/work/rambo not_offered verified
	mkdir -p "$w" && cd "$w" || return 9
	"$HILDE" test --verbose --modules="$modules:$WOLLY/src" "$WOLLY/src/Wolly/Rambo.test.hiq" > "$w/rambo-verbose.out" 2>&1
	not_offered=$(grep -c "ML-DSA is not offered by this libcrypto" "$w/rambo-verbose.out")
	verified=$(grep -c "Assert: the payload under the key of its kid ok$" "$w/rambo-verbose.out")
	echo "rambo-ml-dsa not-offered=$not_offered verified=$verified (want 0 1)"
	[ "$not_offered" = 0 ] && [ "$verified" = 1 ]
}

# The same unit tests on PostgreSQL: Hilde's test server of
# scripts/db/server.sh, which refuses a uid without a name (the user wolly of
# the build image).  Wolly.TestDb opens it with WOLLY_DB=postgres.
# LC_ALL=C.UTF-8: initdb takes the locale of its environment, and in the C
# locale of the image the database is SQL_ASCII, where the text search of
# PostgreSQL does not know a letter beyond ASCII.  A shard has a
# server of its own, since a test drops the schema public of its database, and
# takes the next test file from a queue until it is empty, so that no shard is
# left with the long files while the others are done.
pg_take() {
	local n
	until mkdir "$J/pg.lock" 2> /dev/null; do sleep 0.05; done
	n=$(cat "$J/pg.next")
	echo $((n + 1)) > "$J/pg.next"
	rmdir "$J/pg.lock"
	[ "$n" -lt "${#queue[@]}" ] && echo "${queue[$n]}"
	return 0
}
pg_shard() {
	local name=wollytest$1 w=$J/work/pg-$1 env rc=0 t
	if ! id -nu > /dev/null 2>&1; then
		echo "ABORT: uid $(id -u) has no name, the PostgreSQL test server cannot start -- not run"
		return 9
	fi
	mkdir -p "$w" || return 9
	env=$(LC_ALL=C.UTF-8 sh scripts/db/server.sh start postgres "$name") || { echo "ABORT: the PostgreSQL test server did not start -- not run"; return 9; }
	(
		eval "$(echo "$env" | sed -E 's/^([A-Z_]+)=(.*)$/export \1="\2"/')"
		cd "$w" || exit 9
		while t=$(pg_take) && [ -n "$t" ]; do
			WOLLY_DB=postgres "$HILDE" test --modules="$modules:$WOLLY/src" "$WOLLY/$t" || rc=1
		done
		exit $rc
	)
	rc=$?
	sh scripts/db/server.sh stop postgres "$name"
	return $rc
}

build_app() {
	ONLY=$1 bash scripts/build.sh
}

e2e_app() {
	local app=$1 tls=$2 port=$3
	PORT=$port TLS=$tls bash scripts/e2e.sh "$app"
}

# The builds with their runs after them first, then the shards for
# PostgreSQL, then the unit files, the largest first: those that run long.
apps=()
for dir in examples/*/; do
	app=$(basename "$dir")
	[ -r "scripts/e2e-$app.sh" ] || { echo "ABORT: examples/$app has no scripts/e2e-$app.sh"; exit 9; }
	apps+=("$app")
	jobs_add "build-$app" - 1 build_app "$app"
done
# PORT_BASE: the first port of the end-to-end runs, for a run beside others
# (scripts/mutate.sh runs mutated trees side by side).
port=${PORT_BASE:-18493}
for app in "${apps[@]}"; do
	jobs_add "e2e-$app-http" "build-$app" 1 e2e_app "$app" 0 "$port"
	jobs_add "e2e-$app-https" "build-$app" 1 e2e_app "$app" 1 "$((port + 1))"
	port=$((port + 2))
done
# ls -S: by size, the largest first, ties by name.
mapfile -t queue < <(ls -S "${tests[@]}")
[ ${#queue[@]} -eq ${#tests[@]} ] || { echo "ABORT: ls -S gave ${#queue[@]} of ${#tests[@]} test files"; exit 9; }
echo 0 > "$J/pg.next" || exit 9
slots=$(jobs_slots)
shards=$((slots / 2))
[ "$shards" -ge 1 ] || shards=1
[ "$shards" -le ${#queue[@]} ] || shards=${#queue[@]}
for ((s = 0; s < shards; s++)); do
	jobs_add "pg-$s" - 1 pg_shard "$s"
done
for t in "${queue[@]}"; do
	jobs_add "unit-$(basename "$t" .test.hiq)" - 0 unit_file "$t"
done
jobs_add rambo-ml-dsa - 0 rambo_check
jobs_add jobs-test - 0 bash scripts/jobs.test.sh
# Every public function states a contract or why not.
jobs_add contracts-stated - 0 bash scripts/check-contracts.test.sh
# And the contracts hold: hilde test --contracts over each module that has one,
# the module alone, in a directory of its own (scripts/contracts.sh).
contracts_module() {
	CONTRACTS_OUT=$J/work/contracts-$1 bash scripts/contracts.sh "$1"
}
mapfile -t checked < <(bash scripts/contracts.sh --list)
[ ${#checked[@]} -gt 0 ] || { echo "ABORT: scripts/contracts.sh --list named no module"; exit 9; }
for m in "${checked[@]}"; do
	jobs_add "contracts-$m" - 0 contracts_module "$m"
done

jobs_run "$J/logs"
jobs_merge "$J/logs"

unit=0
for t in "${tests[@]}"; do
	[ "$(jobs_rc "unit-$(basename "$t" .test.hiq)")" = 0 ] || unit=1
done
[ "$(jobs_rc rambo-ml-dsa)" = 0 ] || unit=1
[ "$(jobs_rc jobs-test)" = 0 ] || unit=1
echo "unit-rc=$unit"
pg=0
for ((s = 0; s < shards; s++)); do
	rc=$(jobs_rc "pg-$s")
	if [ "$rc" = 9 ]; then pg=9; elif [ "$rc" != 0 ] && [ "$pg" = 0 ]; then pg=1; fi
done
echo "pg-rc=$pg"
build=0
for app in "${apps[@]}"; do
	[ "$(jobs_rc "build-$app")" = 0 ] || build=1
done
e2e=9
if [ $build -eq 0 ]; then
	e2e=0
	for app in "${apps[@]}"; do
		[ "$(jobs_rc "e2e-$app-http")" = 0 ] || e2e=1
		[ "$(jobs_rc "e2e-$app-https")" = 0 ] || e2e=1
	done
	echo "e2e-apps=${#apps[@]}"
	[ ${#apps[@]} -gt 0 ] || e2e=9
fi
echo "e2e-rc=$e2e"
contracts=$(jobs_rc contracts-stated)
echo "contracts-rc=$contracts"
held=0
good=0
for m in "${checked[@]}"; do
	if [ "$(jobs_rc "contracts-$m")" = 0 ]; then good=$((good + 1)); else held=1; fi
done
echo "contracts-checked: $good of ${#checked[@]} modules green"
echo "test: unit=$unit pg=$pg build=$build e2e=$e2e contracts=$contracts checked=$held"
[ $unit -eq 0 ] && [ $pg -eq 0 ] && [ $build -eq 0 ] && [ $e2e -eq 0 ] && [ "$contracts" = 0 ] && [ $held -eq 0 ]
