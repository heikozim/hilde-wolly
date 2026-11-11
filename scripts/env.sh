# Sourced by the scripts that build and test Wolly, from the root of the
# tree (or a copy of it).  Names the tools and the modules a Wolly programme
# is compiled with, in one of two places:
#
#   - inside the build image, which /etc/wolly-dev marks;
#   - in a BSD guest, where WOLLY_TOOLS names the
#     directory with the Hilde tree and the Hiawatha build made there, and
#     $WOLLY_TOOLS/wolly-tools says what they were built from.
if [ -r /etc/wolly-dev ]; then
	WOLLY_PLACE=image
	WOLLY_ID=/etc/wolly-dev
	H=/opt/hilde
	HILDE=/usr/local/bin/hilde
	HIAWATHA=/usr/local/sbin/hiawatha
	MIMETYPES=/opt/hiawatha/mimetype.conf
elif [ -n "${WOLLY_TOOLS:-}" ] && [ -r "$WOLLY_TOOLS/wolly-tools" ]; then
	WOLLY_PLACE=guest
	WOLLY_ID=$WOLLY_TOOLS/wolly-tools
	H=$WOLLY_TOOLS/hilde
	HILDE=$H/hilde
	HIAWATHA=$WOLLY_TOOLS/hiawatha/build/hiawatha
	MIMETYPES=$WOLLY_TOOLS/hiawatha/config/mimetype.conf
else
	echo "ABORT: neither in the image wolly-dev nor in a guest with WOLLY_TOOLS -- run inside the build image or in a prepared BSD guest" >&2
	exit 9
fi
# The root of a tree, or a copy of it that scripts/mutate.sh made.
[ -r scripts/env.sh ] && [ -d src/Wolly ] || { echo "ABORT: run from the root of the Wolly tree" >&2; exit 9; }

WOLLY=$PWD
# WOLLY_RUN: the run directory of one job of a parallel run (scripts/jobs.sh),
# so that two variants of a build do not share _run/bin.
RUN=${WOLLY_RUN:-$WOLLY/_run}
export TMPDIR=$RUN/tmp

for t in "$HILDE" "$HIAWATHA"; do
	[ -x "$t" ] || { echo "ABORT: $t missing -- nothing ran" >&2; exit 9; }
done
for t in cc curl python3; do
	command -v "$t" > /dev/null 2>&1 || { echo "ABORT: $t not on PATH -- nothing ran" >&2; exit 9; }
done
mkdir -p "$TMPDIR" || exit 9

# A server the runs start goes into a session of its own where setsid(1)
# exists, so that no signal meant for the caller reaches it; the BSDs have
# no setsid(1), and there it stays a background job of the script.
DETACH=()
command -v setsid > /dev/null 2>&1 && DETACH=(setsid)

# The permission bits of a file in octal: GNU stat, else BSD stat.
mode_of() {
	stat -c %a "$1" 2> /dev/null || stat -f %Lp "$1" 2> /dev/null
}

# The modules the programme of one pair interface,body needs, itself
# included, in the order of their imports (scripts/modules.py).
program_modules() {
	python3 -I "$WOLLY/scripts/modules.py" "$H/standard/src" "$H/bindings/generated" "$WOLLY/src" -- "$1"
}

# program_modules for the example in the directory $1 with the pair $2 and
# the module $3.  With a directory routes/ beside the pair, the module
# $3.Routes is first written from that tree into _run/gen/<example> by
# scripts/route-tree.py, and every directory of the tree is searched, as
# modules.py does not go into one whose name begins with _.
example_modules() {
	local dir=${1%/} pair=$2 module=$3 gen tree
	if [ ! -d "$dir/routes" ]; then
		program_modules "$pair"
		return
	fi
	gen=$RUN/gen/$(basename "$dir")
	python3 -I "$WOLLY/scripts/route-tree.py" --hilde="$HILDE" --root="$dir/routes" --module="$module.Routes" --out="$gen" >&2 || return 1
	IFS=: read -r -a tree <<< "$(python3 -I "$WOLLY/scripts/route-tree.py" --root="$dir/routes" --dirs)" || return 1
	python3 -I "$WOLLY/scripts/modules.py" "$H/standard/src" "$H/bindings/generated" "$WOLLY/src" "$gen" "${tree[@]}" -- "$pair"
}

# A TCP port on the loopback that nobody answers on, or exit.
port_free() {
	if curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$1/"; then
		echo "ABORT: something answers on port $1 -- nothing ran" >&2
		exit 9
	fi
}
