#!/usr/bin/env bash
# Runs inside the build image: the check that every public function of the tree
# states its contract or why not (contracts are mandatory), the job
# contracts-stated of scripts/test.sh and the check scripts/mutate-target.sh
# runs for a mutation of an interface or of the check.  The self-test of
# scripts/check-contracts.pl, then the contract check of Hilde where the
# image has it, else the .pl, over those of src, cli and examples the
# tree has (the copies of scripts/mutate.sh have no cli).
#
#     bash scripts/check-contracts.test.sh
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || { echo "ABORT: bash ${BASH_VERSION} too old" >&2; exit 9; }
set -u
. scripts/env.sh
[ -d src ] || { echo "ABORT: no src -- nothing was checked" >&2; exit 9; }
dirs=()
for d in src cli examples; do
	[ -d "$d" ] && dirs+=("$d")
done
# The self-test of the .pl runs either way, so that a mutation of it is seen
# once the image has the .py too.
perl scripts/check-contracts.pl --self-test || exit 1
if [ -r "$H/scripts/check-contracts.py" ]; then
	python3 "$H/scripts/check-contracts.py" "${dirs[@]}"
else
	perl scripts/check-contracts.pl "${dirs[@]}"
fi
