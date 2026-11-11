#!/usr/bin/env bash
# Runs inside wolly-dev, from the root of the Wolly tree: the routes that
# scripts/route-tree.py derives from a tree of route modules.  Three parts:
#
#   - trees that are no route tree, refused by the generator with exit 1;
#   - trees with two routes of one method and one path, which the
#     generator writes and hilde check must refuse with H2015, so that a
#     duplicate is an error of the compiler;
#   - the tree of examples/pages, which must compile, and the tests of
#     examples/pages/Pages.test.hiq built with the module written from it:
#     segments, layouts, parameters and the routes set by hand.
#
#     bash scripts/route-tree.sh
#
# HILDE and H (the Hilde tree with standard/src) default to the image's.
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || { echo "ABORT: bash ${BASH_VERSION} too old" >&2; exit 9; }
set -u
[ -r src/Wolly/Tree.hih ] || { echo "ABORT: run from the root of the Wolly tree" >&2; exit 9; }
HILDE=${HILDE:-$(command -v hilde || echo /usr/local/bin/hilde)}
H=${H:-/opt/hilde}
[ -x "$HILDE" ] || { echo "ABORT: $HILDE missing -- nothing ran" >&2; exit 9; }
[ -d "$H/standard/src" ] || { echo "ABORT: $H/standard/src missing -- nothing ran" >&2; exit 9; }
WOLLY=$PWD
BASE=$H/bindings/generated:$H/standard/src:$WOLLY/src
WORK=$(mktemp -d "${TMPDIR:-/tmp}/wolly-route-tree.XXXXXX") || exit 9
trap 'rm -rf "$WORK"' EXIT

HEAD='import Standard.String (
    String,
    fromSpan
);
import Standard.FcgiServer (
    Request,
    destroyRequest
);
import Wolly.Response (
    makeResponse
);
import Wolly.Tree (
    Page,
    page
);'

# page <file without .hih> <module>: a page with get.
page() {
	mkdir -p "$(dirname "$1")" || exit 9
	printf '%s\nmodule %s is\n    function get(request: Request): Page;\nend module.\n' "$HEAD" "$2" > "$1.hih"
	printf '%s\nmodule body %s is\n    function get(request: Request): Page is\n        destroyRequest(request);\n        return page(makeResponse(200, "text/plain"), fromSpan("x"));\n    end;\nend module body.\n' "$HEAD" "$2" > "$1.hiq"
}

# layout <file without .hih> <module>: a module with layout.
layout() {
	mkdir -p "$(dirname "$1")" || exit 9
	printf '%s\nmodule %s is\n    function layout(content: String): String;\nend module.\n' "$HEAD" "$2" > "$1.hih"
	printf '%s\nmodule body %s is\n    function layout(content: String): String is\n        return content;\n    end;\nend module body.\n' "$HEAD" "$2" > "$1.hiq"
}

# param <file without .hih> <module>: a parameter module with a page.
param() {
	mkdir -p "$(dirname "$1")" || exit 9
	printf '%s\nmodule %s is\n    type Param: Free;\n    generic [R: Region]\n    function parse(text: Span[Nat8, R]): Option[Param];\n    function get(request: Request, p: Param): Page;\nend module.\n' "$HEAD" "$2" > "$1.hih"
	printf '%s\nmodule body %s is\n    record Param: Free is\n        n: Int64;\n    end;\n    generic [R: Region]\n    function parse(text: Span[Nat8, R]): Option[Param] is\n        return Some(value => Param(n => 1));\n    end;\n    function get(request: Request, p: Param): Page is\n        destroyRequest(request);\n        return page(makeResponse(200, "text/plain"), fromSpan("x"));\n    end;\nend module body.\n' "$HEAD" "$2" > "$1.hiq"
}

generate() {
	python3 -I "$WOLLY/scripts/route-tree.py" --hilde="$HILDE" --root="$1" --module=Wolly.RouteTreeCase.Routes --out="$2"
}

total=0
bad=0
# refused <case> <wanted part of the message>: the generator exits 1.
refused() {
	local name=$1 want=$2 out rc
	total=$((total + 1))
	out=$(generate "$WORK/$name" "$WORK/$name-gen" 2>&1)
	rc=$?
	if [ $rc -eq 1 ] && [[ "$out" == *"$want"* ]]; then
		echo "ok    $name refused by the generator: $want"
	else
		echo "FAIL  $name: wanted exit 1 and '$want', rc=$rc"
		echo "$out" | head -10
		bad=$((bad + 1))
	fi
}

# compiled <case> <H code or ok>: the generator writes the module, and
# hilde check refuses it with the code or, for ok, takes it.
compiled() {
	local name=$1 want=$2 root=$3 out rc dirs
	total=$((total + 1))
	out=$(generate "$root" "$WORK/$name-gen" 2>&1)
	rc=$?
	if [ $rc -ne 0 ]; then
		echo "FAIL  $name: the generator refused the tree (rc=$rc)"
		echo "$out" | head -10
		bad=$((bad + 1))
		return
	fi
	dirs=$(python3 -I "$WOLLY/scripts/route-tree.py" --root="$root" --dirs) || exit 9
	out=$("$HILDE" check "$WORK/$name-gen/Routes.hih,$WORK/$name-gen/Routes.hiq" --modules="$BASE:$dirs" 2>&1)
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
		echo "ok    $name refused by hilde with $want: $(echo "$out" | grep -m1 -o 'name `route_[A-Za-z0-9_]*`')"
	else
		echo "FAIL  $name: wanted $want, rc=$rc"
		echo "$out" | head -20
		bad=$((bad + 1))
	fi
}

echo "== trees that are no route tree"
page "$WORK/capital/About" Wolly.RouteTreeCase.About
refused capital "not a name of a route tree: About"
page "$WORK/no-layout/_admin" Wolly.RouteTreeCase.Admin
refused no-layout "a module with a leading underscore exports layout"
page "$WORK/no-parse/@id" Wolly.RouteTreeCase.Id
refused no-parse "a parameter module exports a type Param and parse"
page "$WORK/lone-dir/_admin/users" Wolly.RouteTreeCase.Users
refused lone-dir "a directory without its module"
layout "$WORK/layout-outside/about" Wolly.RouteTreeCase.About
refused layout-outside "layout only in a module with a leading underscore"
page "$WORK/link/about" Wolly.RouteTreeCase.About
ln -s "$WORK/link/about.hih" "$WORK/link/other.hih" || exit 9
ln -s "$WORK/link/about.hiq" "$WORK/link/other.hiq" || exit 9
refused link "a symbolic link in the tree"
page "$WORK/half/about" Wolly.RouteTreeCase.About
rm -f "$WORK/half/about.hiq"
refused half "a route module needs both files"

echo "== two routes of one method and one path"
page "$WORK/dup-index/about" Wolly.RouteTreeCase.About
page "$WORK/dup-index/about/index" Wolly.RouteTreeCase.About.Index
compiled dup-index H2015 "$WORK/dup-index"
param "$WORK/dup-param/post/@id" Wolly.RouteTreeCase.Post.Id
param "$WORK/dup-param/post/@slug" Wolly.RouteTreeCase.Post.Slug
compiled dup-param H2015 "$WORK/dup-param"
page "$WORK/dup-layout/users" Wolly.RouteTreeCase.Users
layout "$WORK/dup-layout/_admin" Wolly.RouteTreeCase.Admin
page "$WORK/dup-layout/_admin/users" Wolly.RouteTreeCase.Admin.Users
compiled dup-layout H2015 "$WORK/dup-layout"
page "$WORK/dup-root/index" Wolly.RouteTreeCase.Home
layout "$WORK/dup-root/_admin" Wolly.RouteTreeCase.Admin
page "$WORK/dup-root/_admin/index" Wolly.RouteTreeCase.Admin.Index
compiled dup-root H2015 "$WORK/dup-root"

echo "== controls"
page "$WORK/distinct/about" Wolly.RouteTreeCase.About
page "$WORK/distinct/about/index-page" Wolly.RouteTreeCase.About.IndexPage
param "$WORK/distinct/post/@id" Wolly.RouteTreeCase.Post.Id
page "$WORK/distinct/post/id" Wolly.RouteTreeCase.Post.Static
compiled distinct ok "$WORK/distinct"
compiled example ok "$WOLLY/examples/pages/routes"

echo "== tests of examples/pages"
total=$((total + 1))
mkdir -p "$WORK/gen" || exit 9
python3 -I "$WOLLY/scripts/route-tree.py" --hilde="$HILDE" --root=examples/pages/routes \
	--module=Wolly.Example.Pages.Routes --out="$WORK/gen" || exit 9
dirs=$(python3 -I "$WOLLY/scripts/route-tree.py" --root=examples/pages/routes --dirs) || exit 9
"$HILDE" test --modules="$BASE:$WORK/gen:$dirs" examples/pages
rc=$?
if [ $rc -eq 0 ]; then
	echo "ok    the tests of examples/pages"
else
	echo "FAIL  the tests of examples/pages (rc=$rc)"
	bad=$((bad + 1))
fi

echo "route-tree: $((total - bad)) of $total cases as wanted"
[ $bad -eq 0 ]
