#!/usr/bin/env bash
# Runs inside the build image: the build of one example and its end-to-end runs,
# http and TLS -- the light check of a change to one example, without the
# unit tests and the other examples of scripts/test.sh.
#
# Inside the build image, from the root of the tree:
#
#     bash scripts/app-check.sh login
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || { echo "ABORT: bash ${BASH_VERSION} too old" >&2; exit 9; }
set -u
app=${1:?example}
[ -r "scripts/e2e-$app.sh" ] || { echo "ABORT: scripts/e2e-$app.sh missing -- nothing ran" >&2; exit 9; }
ONLY=$app bash scripts/build.sh || { echo "app-check: build failed"; exit 1; }
rc=0
bash scripts/e2e.sh "$app" || rc=1
TLS=1 bash scripts/e2e.sh "$app" || rc=1
echo "app-check: $app rc=$rc"
exit $rc
