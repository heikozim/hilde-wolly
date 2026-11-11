#!/usr/bin/env bash
# Runs inside wolly-dev, from the root of the Wolly tree: Wolly.Memo hands
# one result out to every caller of an argument, so a linear argument or
# result must stop the compiler, not the running programme.  Each case is
# one statement put into a small module beside a prelude of functions;
# hilde check must refuse it with the error code named and with a message
# that sets the Free universe against Linear, and the control, a right use,
# must pass, so that a refusal is the case's and not a broken prelude's.
#
#     bash scripts/memo-refusals.sh
#
# HILDE and H (the Hilde tree with standard/src) default to the image's.
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || { echo "ABORT: bash ${BASH_VERSION} too old" >&2; exit 9; }
set -u
[ -r src/Wolly/Memo.hih ] || { echo "ABORT: run from the root of the Wolly tree" >&2; exit 9; }
HILDE=${HILDE:-$(command -v hilde || echo /usr/local/bin/hilde)}
H=${H:-/opt/hilde}
[ -x "$HILDE" ] || { echo "ABORT: $HILDE missing -- nothing ran" >&2; exit 9; }
[ -d "$H/standard/src" ] || { echo "ABORT: $H/standard/src missing -- nothing ran" >&2; exit 9; }
WOLLY=$PWD
WORK=$(mktemp -d "${TMPDIR:-/tmp}/wolly-memo-refusals.XXXXXX") || exit 9
trap 'rm -rf "$WORK"' EXIT

prelude() {
	cat <<'EOF'
import Standard.Order (
    TotalOrder
);
import Standard.String (
    String,
    fromSpan,
    destroyString
);
import Wolly.Memo (
    Memoized,
    Memo,
    memoized,
    openMemo,
    memoCall,
    closeMemo
);

module body Wolly.MemoRefusal is
    function tenfold(n: Nat64): Nat64 is
        return n * 10;
    end;

    function named(n: Nat64): String is
        return fromSpan("seven");
    end;

    function measured(text: String): Nat64 is
        destroyString(text);
        return 7;
    end;

    function drop(made: Option[Memo[Nat64, Nat64]]): Unit is
        case made of
            when Some(value as memo: Memo[Nat64, Nat64]) do
                let seventy: Nat64 := memoCall(&memo, 7);
                closeMemo(memo);
            when None do
                skip;
        end case;
        return nil;
    end;

    function probe(): Unit is
EOF
}

# One case: its name, the error code wanted (ok for the control) and the
# statements of probe.
total=0
bad=0
probe() {
	local name=$1 want=$2 body=$3 out rc
	total=$((total + 1))
	mkdir -p "$WORK/$name/Wolly" || exit 9
	printf 'module Wolly.MemoRefusal is\nend module.\n' > "$WORK/$name/Wolly/MemoRefusal.hih"
	{
		prelude
		printf '        %s\n' "$body"
		printf '        return nil;\n    end;\nend module body.\n'
	} > "$WORK/$name/Wolly/MemoRefusal.hiq"
	out=$("$HILDE" check "$WORK/$name/Wolly/MemoRefusal.hih,$WORK/$name/Wolly/MemoRefusal.hiq" \
		--modules="$H/standard/src:$H/bindings/generated:$WOLLY/src" 2>&1)
	rc=$?
	if [ "$want" = ok ]; then
		if [ $rc -eq 0 ]; then
			echo "ok    $name compiles"
		else
			echo "FAIL  $name: the control does not compile (rc=$rc)"
			echo "$out" | head -20
			bad=$((bad + 1))
		fi
	elif [ $rc -ne 0 ] && echo "$out" | grep -q "Error code: $want\$" && echo "$out" | grep -q "Free.*Linear"; then
		echo "ok    $name refused with $want"
	else
		echo "FAIL  $name: wanted $want, Free against Linear, rc=$rc"
		echo "$out" | head -20
		bad=$((bad + 1))
	fi
}

probe control ok 'let m: Memoized[Nat64, Nat64] := memoized(tenfold); drop(openMemo(m, 16));'
probe linear-result H3063 'let m: Memoized[Nat64, String] := memoized(named);'
probe linear-argument H3063 'let m: Memoized[String, Nat64] := memoized(measured);'
probe linear-result-inferred H3004 'let f: Fn[Nat64, String] := named; drop(openMemo(memoized(f), 16));'
probe linear-argument-inferred H3004 'let f: Fn[String, Nat64] := measured; drop(openMemo(memoized(f), 16));'

echo "memo-refusals: $((total - bad)) of $total cases as wanted"
[ $bad -eq 0 ]
