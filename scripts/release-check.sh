#!/usr/bin/env bash
# Runs inside the build image: the step of a release.  scripts/check-version.pl with the tag, the self-test of
# scripts/about-check.pl, then every programme of cli/ and examples/ built with CLI=1 and asked
# what it says about itself: the version line on version, -V and --version, the full version on
# each of them with --full, with the libraries the programme links, and info.  Each answer must
# have its form and exit 0.
#
#     bash scripts/release-check.sh v0.1.0
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || { echo "ABORT: bash ${BASH_VERSION} too old" >&2; exit 9; }
set -u
. scripts/env.sh
tag=${1:?tag vX.Y.Z}
perl scripts/check-version.pl "$tag" || exit $?
perl scripts/about-check.pl --self-test || exit 1
release=${tag#v}
notice=$(perl -ne 'print $1 if /function notice\(\): Span\[Nat8, Static\] is\n/../end;/ and /return "([^"]+)";/' src/Wolly/Version.hiq)
[ -n "$notice" ] || { echo "ABORT: no notice in src/Wolly/Version.hiq -- nothing was checked" >&2; exit 9; }
# The C libraries each programme names on --full: those it links itself (ldd in the build image)
# that tell their version; libtls and libargon2 do not.
declare -A libraries=(
	[acme]=libcrypto [buntipng]= [qruri]= [sshrun]= [vault]=libcrypto [view]=libcrypto
	[contact]="libcrypto sqlcipher" [hello]=libcrypto [login]="libcrypto sqlcipher"
)
CLI=1 bash scripts/build.sh || { echo "release-check: the build failed"; exit 1; }
want=0
good=0
ask() {
	local mode=$1 name=$2
	shift 2
	want=$((want + 1))
	"$RUN/bin/$name" "$@" < /dev/null > "$RUN/about.out"
	local rc=$?
	# shellcheck disable=SC2086
	if [ "$rc" -eq 0 ] && perl scripts/about-check.pl "$mode" "$name" "$release" "$notice" ${libraries[$name]} < "$RUN/about.out"; then
		good=$((good + 1))
	else
		echo "release-check: $name $* gave rc=$rc"
	fi
}
n=0
for dir in cli/*/ examples/*/; do
	name=$(basename "$dir")
	[ -n "${libraries[$name]+x}" ] || { echo "release-check: $name has no line in the table of libraries"; exit 1; }
	n=$((n + 1))
	for word in version -V --version; do
		ask line "$name" "$word"
		ask full "$name" "$word" --full
	done
	ask info "$name" info
	# The servers have a sandbox, and so have qruri, buntipng, view and acme.
	case "$name" in
	hello | contact | login | qruri | buntipng | view | acme)
		ask sandbox "$name" sandbox
		ask sandbox "$name" -s
		;;
	esac
done
[ "$n" -eq "${#libraries[@]}" ] || { echo "release-check: $n programmes, the table has ${#libraries[@]}"; exit 1; }
# Each confined tool once at its work, in its sandbox: qruri prints a data URI, buntipng writes
# and reads back a PNG in a directory of its own, view checks the templates of login (they extend templates/base.jinja, found in examples/login), acme
# writes a key of mode 0600 and calls it due, as it is no certificate.
work=$(mktemp -d "${TMPDIR:-/tmp}/release-check.XXXXXX") || exit 9
runs=0
ran=0
runs=$((runs + 1))
"$RUN/bin/qruri" "release-check" < /dev/null > "$work/qr.out" && perl -ne 'exit(/\Adata:image\/png;base64,[A-Za-z0-9+\/=]+\n\z/ ? 0 : 1)' "$work/qr.out" && ran=$((ran + 1)) || echo "release-check: qruri at its work failed"
runs=$((runs + 1))
mkdir "$work/png" && "$RUN/bin/buntipng" "$work/png/code.png" "release-check" < /dev/null > "$work/png.out" && [ -s "$work/png/code.png" ] && ran=$((ran + 1)) || { echo "release-check: buntipng at its work failed"; cat "$work/png.out"; }
runs=$((runs + 1))
"$RUN/bin/view" check examples/login/templates examples/login < /dev/null > "$work/view.out" && ran=$((ran + 1)) || { echo "release-check: view at its work failed"; cat "$work/view.out"; }
runs=$((runs + 1))
mkdir "$work/key" && "$RUN/bin/acme" newkey "$work/key/account.pem" < /dev/null > "$work/key.out" && [ "$(stat -c %a "$work/key/account.pem")" = 600 ] \
	&& "$RUN/bin/acme" due "$work/key/account.pem" < /dev/null > "$work/due.out" && [ "$(cat "$work/due.out")" = due ] && ran=$((ran + 1)) \
	|| { echo "release-check: acme at its work failed"; cat "$work/key.out" "$work/due.out" 2> /dev/null; }
rm -rf "$work"
echo "release-check: $ran of $runs tools did their work in their sandbox"
# One answer of each kind word for word in the log.
for args in --version "--version --full" info sandbox; do
	echo "== hello $args"
	# shellcheck disable=SC2086
	"$RUN/bin/hello" $args < /dev/null
done
echo "release-check: $good of $want answers of $n programmes have their form for $tag"
[ $want -gt 0 ] && [ $good -eq $want ] && [ $ran -eq $runs ]
