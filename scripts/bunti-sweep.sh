#!/usr/bin/env bash
# Runs in the build environment, as a long run outside scripts/test.sh: the sweep of every payload length 0 to 4096 of Wolly.Bunti
# in both modes and at all four levels (sweep/BuntiSweepAll.test.hiq, 64
# tests, 32776 codes).  It takes most of an hour and a half on a 16-core
# arm64 host; src/Wolly/BuntiSweep.test.hiq is the sample of it that
# scripts/test.sh runs.
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || { echo "ABORT: bash ${BASH_VERSION} too old" >&2; exit 9; }
set -u
. scripts/env.sh
[ -r sweep/BuntiSweepAll.test.hiq ] || { echo "ABORT: no sweep/BuntiSweepAll.test.hiq -- nothing ran" >&2; exit 9; }
echo "== $(id -un 2> /dev/null || id -u) in $(uname -sr)"
"$HILDE" test --modules="$H/bindings/generated:$H/standard/src:$WOLLY/src" sweep/BuntiSweepAll.test.hiq
rc=$?
echo "sweep-rc=$rc"
exit $rc
