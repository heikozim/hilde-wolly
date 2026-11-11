#!/usr/bin/env bash
# Runs inside the build image: the examples built, then scripts/e2e.sh of
# each over HTTP and over TLS with the browser cases, through the Lightpanda
# the image has.  A run of its own for the browser cases; scripts/test.sh
# runs them with the rest when the image has Lightpanda.
#
#     bash scripts/e2e-browser-run.sh
#
# Exit 0 when every run held, 1 when one failed, 9 when nothing ran.
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || { echo "ABORT: bash ${BASH_VERSION} too old" >&2; exit 9; }
set -u
lp=$(command -v lightpanda) || { echo "ABORT: no lightpanda in this image -- nothing ran" >&2; exit 9; }
bash scripts/build.sh > /tmp/build.log 2>&1 || { tail -20 /tmp/build.log; echo "ABORT: the build failed -- nothing ran" >&2; exit 9; }
port=18600
bad=0
runs=0
for app in hello login contact; do
	for tls in 0 1; do
		runs=$((runs + 1))
		PORT=$port TLS=$tls LIGHTPANDA=$lp bash scripts/e2e.sh "$app" > "/tmp/e2e-$app-$tls.log" 2>&1
		rc=$?
		echo "e2e $app tls=$tls rc=$rc $(grep -c '^ok    browser: ' "/tmp/e2e-$app-$tls.log") browser cases ok, $(grep -c '^FAIL' "/tmp/e2e-$app-$tls.log") failed"
		grep -E '^(FAIL|ok    browser)' "/tmp/e2e-$app-$tls.log" | sed 's/^/    /'
		[ "$rc" = 0 ] || bad=$((bad + 1))
		port=$((port + 2))
	done
done
# The control: a browser case that cannot hold must turn its run red.
BROWSER_CONTROL=1 PORT=$port TLS=0 LIGHTPANDA=$lp bash scripts/e2e.sh hello > /tmp/e2e-control.log 2>&1
crc=$?
cfail=$(grep -c '^FAIL  browser: the control' /tmp/e2e-control.log)
echo "e2e-browser-control rc=$crc (want not 0) control-failed=$cfail (want 1)"
{ [ "$crc" != 0 ] && [ "$cfail" = 1 ]; } || bad=$((bad + 1))
echo "e2e-browser runs=$runs bad=$bad lightpanda=$lp"
[ "$bad" = 0 ]
