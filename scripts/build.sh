#!/usr/bin/env bash
# Runs inside the build image: compiles every example under examples/ into
# _run/bin/<name>.  An example is a directory with one pair X.hih and X.hiq
# whose module has a main; its entry point is that module's main.
#
#     bash scripts/build.sh
#     VARIANT=memory bash scripts/build.sh
#
# Without VARIANT hilde compile builds the programme.  With a VARIANT hilde
# writes the C and cc builds it with the flags hilde test gives the same
# instrument: memory is ASan and UBSan, race is TSan, valgrind is -g with
# the runtime telling valgrind its task stacks; trap is UBSan without a
# runtime, a fault stops the programme with a trap; o1 is the first
# optimization level.  A variant
# builds with -Wall -Wextra like hilde and fails on a warning.
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || { echo "ABORT: bash ${BASH_VERSION} too old" >&2; exit 9; }
set -u
. scripts/env.sh

VARIANT=${VARIANT:-}
case "$VARIANT" in
	"") flags=() ;;
	memory) flags=(-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer -g -O1) ;;
	race) flags=(-fsanitize=thread -g -O1) ;;
	valgrind) flags=(-g -DHILDE_VALGRIND) ;;
	trap) flags=(-fsanitize=undefined -fsanitize-trap=undefined -g -O1) ;;
	o1) flags=(-O1) ;;
	*) echo "ABORT: unknown VARIANT $VARIANT" >&2; exit 9 ;;
esac
# UBSan's check of indirect calls (-fsanitize=function) reads the bytes in
# front of the function it calls.  OpenBSD maps code execute-only, so that
# read ends the programme with SIGSEGV at the first indirect call, a crash
# of the check and not a finding; linked with --no-execute-only the check
# runs.  Seen with examples/hello on OpenBSD 7.9.
if [ "$VARIANT" = trap ] && [ "$(uname -s)" = OpenBSD ]; then
	flags+=(-Wl,--no-execute-only)
fi
# --flags: only the flags of the variant, for a caller that asks the cc
# whether it builds with them (the BSD part of stage finalize).
if [ "${1:-}" = --flags ]; then
	echo "${flags[*]}"
	exit 0
fi
# The symbols a binary of the variant must hold, so that a flag that went
# missing is a failed build and not a run without the instrument.
case "$VARIANT" in
	memory) symbols=(__asan_init __ubsan_handle) ;;
	race) symbols=(__tsan_init) ;;
	*) symbols=() ;;
esac
if [ -n "$VARIANT" ]; then
	command -v pkg-config > /dev/null 2>&1 || { echo "ABORT: pkg-config not on PATH -- nothing ran" >&2; exit 9; }
fi

# The flags cc needs for one library of the link manifest: pkg-config under
# its name or under lib<name>, else -l<name>, as hilde compile asks.
library_flags() {
	local known
	for known in "$1" "lib$1"; do
		if pkg-config --exists "$known" 2> /dev/null; then
			pkg-config --cflags --libs "$known"
			return
		fi
	done
	echo "-l$1"
}

# Builds one example through its C with the flags of the variant.  The
# libraries come from the link manifest at the end of the C.
build_variant() {
	local name=$1 module=$2 mods=$3 c libs l rc warnings
	c=$RUN/c/$name.c
	# shellcheck disable=SC2086
	"$HILDE" compile $mods --target-type=c --entrypoint="$module:main" --output="$c" || return 1
	grep -q '^/\* hilde link libraries:' "$c" || { echo "cc-$name: no link manifest in the C"; return 1; }
	libs=$(sed -n 's#^/\* hilde link libraries:\(.*\) \*/$#\1#p' "$c")
	set --
	for l in $libs; do
		# shellcheck disable=SC2046
		set -- "$@" $(library_flags "$l")
	done
	cc -std=c17 -Wall -Wextra "${flags[@]}" "$c" "$@" -o "$RUN/bin/$name" > "$RUN/c/$name.cc.out" 2>&1
	rc=$?
	warnings=$(grep -c "warning:" "$RUN/c/$name.cc.out")
	echo "cc-$name: libraries [$libs] rc=$rc warnings=$warnings"
	if [ $rc -ne 0 ] || [ "$warnings" -ne 0 ]; then
		head -20 "$RUN/c/$name.cc.out"
		return 1
	fi
	# A binary without its instrument is not left for a run to take.
	instrumented "$RUN/bin/$name" || { rm -f "$RUN/bin/$name"; return 1; }
}

# Whether a binary holds every symbol of the variant.
instrumented() {
	local s missing=0
	for s in "${symbols[@]}"; do
		grep -q -a -- "$s" "$1" || { echo "instrument: $s missing in $1"; missing=1; }
	done
	echo "instrument: ${#symbols[@]} symbols looked for in $(basename "$1"), missing=$missing"
	[ $missing -eq 0 ]
}

# The controls of the variant: a programme with a known fault each, from
# scripts/controls/<variant>-*.c, built with the same flags into
# _run/control.  scripts/finalize-linux.sh runs them and wants the fault
# reported.
build_controls() {
	local c out n=0
	mkdir -p "$RUN/control" || return 1
	for c in scripts/controls/"$VARIANT"-*.c; do
		[ -r "$c" ] || continue
		out=$RUN/control/$(basename "$c" .c)
		cc -std=c17 -Wall -Wextra "${flags[@]}" "$c" -lpthread -o "$out" || return 1
		instrumented "$out" || return 1
		n=$((n + 1))
	done
	echo "controls-built=$n"
}

mkdir -p "$RUN/bin" "$RUN/c" || exit 9
echo "build variant=${VARIANT:-plain} flags=[${flags[*]}]"
built=0
failed=0
# CLI=1 builds the programmes under cli/ as well (the certificate tool,
# which needs a network and so has no end-to-end run of scripts/test.sh).
dirs=(examples/*/)
[ "${CLI:-0}" != 1 ] || dirs+=(cli/*/)
for dir in "${dirs[@]}"; do
	name=$(basename "$dir")
	# ONLY=<app> builds that example alone, for scripts/mutate-target.sh.
	if [ -n "${ONLY:-}" ] && [ "$name" != "$ONLY" ]; then continue; fi
	hih=$(ls "$dir"*.hih 2> /dev/null | head -1)
	[ -n "$hih" ] || { echo "ABORT: $dir has no .hih"; exit 9; }
	module=$(sed -n 's/^module \([A-Za-z.]*\) is.*/\1/p' "$hih" | head -1)
	pair="$hih,${hih%.hih}.hiq"
	if ! mods=$(program_modules "$pair"); then
		echo "build-$name: the modules were not found"
		failed=$((failed + 1))
		continue
	fi
	if [ -z "$VARIANT" ]; then
		# shellcheck disable=SC2086
		"$HILDE" compile $mods --entrypoint="$module:main" --output="$RUN/bin/$name"
	else
		build_variant "$name" "$module" "$mods"
	fi
	rc=$?
	echo "build-$name-rc=$rc ($module, $(echo "$mods" | wc -w) modules)"
	if [ $rc -eq 0 ]; then built=$((built + 1)); else failed=$((failed + 1)); fi
done
if [ -n "$VARIANT" ]; then
	build_controls || { echo "build-controls failed"; failed=$((failed + 1)); }
fi
echo "build: $built built, $failed failed"
[ $failed -eq 0 ] && [ $built -gt 0 ]
