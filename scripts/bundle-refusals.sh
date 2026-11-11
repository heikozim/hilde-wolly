#!/usr/bin/env bash
# Runs inside wolly-dev, from the root of the Wolly tree: an asset of
# Wolly.Bundle names its file through @bytes, so a file that is not there
# must stop the compiler and not the running programme.  Each case is one
# module under testdata/bundle-refusals/<case>/Wolly; hilde check must refuse
# it with the error code named, and the control, the same module with its
# file, must pass, so that a refusal is the missing file's and not a broken
# module's.
#
#     bash scripts/bundle-refusals.sh
#
# HILDE and H (the Hilde tree with standard/src) default to the image's.
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || { echo "ABORT: bash ${BASH_VERSION} too old" >&2; exit 9; }
set -u
[ -r src/Wolly/Bundle.hih ] || { echo "ABORT: run from the root of the Wolly tree" >&2; exit 9; }
HILDE=${HILDE:-$(command -v hilde || echo /usr/local/bin/hilde)}
H=${H:-/opt/hilde}
[ -x "$HILDE" ] || { echo "ABORT: $HILDE missing -- nothing ran" >&2; exit 9; }
[ -d "$H/standard/src" ] || { echo "ABORT: $H/standard/src missing -- nothing ran" >&2; exit 9; }
CASES=testdata/bundle-refusals
# The case missing is only a case while its file is really absent.
[ -r "$CASES/present/Wolly/static/app.css" ] || { echo "ABORT: the control has no file" >&2; exit 9; }
[ ! -e "$CASES/missing/Wolly/static/app.css" ] || { echo "ABORT: the file of the case missing is there" >&2; exit 9; }

total=0
bad=0
probe() {
	local name=$1 want=$2 dir out rc
	total=$((total + 1))
	dir=$CASES/$name/Wolly
	[ -r "$dir/BundleProbe.hiq" ] || { echo "ABORT: no $dir/BundleProbe.hiq" >&2; exit 9; }
	out=$("$HILDE" check "$dir/BundleProbe.hih,$dir/BundleProbe.hiq" \
		--modules="$H/standard/src:$H/bindings/generated:$PWD/src" 2>&1)
	rc=$?
	if [ "$want" = ok ]; then
		if [ $rc -eq 0 ]; then
			echo "ok    $name compiles"
		else
			echo "FAIL  $name: the control does not compile (rc=$rc)"
			echo "$out" | head -20
			bad=$((bad + 1))
		fi
	elif [ $rc -ne 0 ] && echo "$out" | grep -q "Error code: $want\$"; then
		echo "ok    $name refused with $want"
	else
		echo "FAIL  $name: wanted $want, rc=$rc"
		echo "$out" | head -20
		bad=$((bad + 1))
	fi
}

probe present ok
probe missing H6002
probe outside H6001

echo "bundle-refusals: $((total - bad)) of $total cases as wanted"
[ $bad -eq 0 ]
