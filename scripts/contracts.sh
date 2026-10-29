#!/usr/bin/env bash
# Runs inside the build image, from the root of the Wolly tree: hilde test
# --contracts over each named module of src/Wolly (every module with a
# requires or ensures in its interface when none is named), the module alone
# in a directory of its own and the rest of src beside it, seed and rounds
# fixed, as the test run of an application does it (contracts are mandatory).
#
#     bash scripts/contracts.sh [Module ...]
#     bash scripts/contracts.sh --list    # the modules it takes when none is named
#
# scripts/test.sh runs it as one job per module of --list.
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || { echo "ABORT: bash ${BASH_VERSION} too old" >&2; exit 9; }
set -u
[ -d src/Wolly ] || { echo "ABORT: run from the root of the Wolly tree" >&2; exit 9; }
# Every module with a requires or ensures in its interface, in the order of the glob.
with_contracts() {
	local hih
	for hih in src/Wolly/*.hih; do
		grep -q -E '^[[:space:]]+(requires|ensures) ' "$hih" && basename "$hih" .hih
	done
	return 0
}
if [ "${1:-}" = --list ]; then
	LC_ALL=C with_contracts
	exit 0
fi
. scripts/env.sh
BASE=$H/bindings/generated:$H/standard/src
OUT=${CONTRACTS_OUT:-/tmp/wolly-contracts}
SEED=${SEED:-20261017} ROUNDS=${ROUNDS:-500}
rm -rf "$OUT" && mkdir -p "$OUT" || exit 9
modules=("$@")
[ ${#modules[@]} -gt 0 ] || mapfile -t modules < <(LC_ALL=C with_contracts)
bad=0
good=0
for m in "${modules[@]}"; do
	[ -r "src/Wolly/$m.hih" ] || { echo "ABORT: no src/Wolly/$m.hih" >&2; exit 9; }
	c=$OUT/$m
	mkdir -p "$c/one/Wolly" "$c/rest" || exit 9
	cp -r src/Wolly "$c/rest/" || exit 9
	mv "$c/rest/Wolly/$m.hih" "$c/rest/Wolly/$m.hiq" "$c/one/Wolly/" || exit 9
	rm -f "$c/rest/Wolly/$m.test.hiq"
	[ ! -d src/Wolly/templates ] || cp -r src/Wolly/templates "$c/one/Wolly/" || exit 9
	"$HILDE" test --contracts --seed="$SEED" --rounds="$ROUNDS" --modules="$BASE:$c/rest" "$c/one" > "$c.log" 2>&1
	r=$?
	echo "contracts $m rc=$r $(grep -E '^(ok|FAIL) ' "$c.log" | tail -1)"
	if [ $r -eq 0 ]; then
		good=$((good + 1))
	else
		bad=$((bad + 1))
		tail -15 "$c.log"
	fi
done
echo "contracts: $good of ${#modules[@]} modules green"
[ "$bad" -eq 0 ] && [ "$good" -gt 0 ]
