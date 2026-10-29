# The mutations of Wolly.Asset and its route in examples/hello, sourced by
# scripts/mutate.sh.  The expressions use # as their delimiter, since the
# code they change holds slashes.
mutations+=(
	"Asset.hiq|s#if (next = '/') or (next = '.') then#if next = '/' then#|a segment may start with a dot"
	"Asset.hiq|s#if containsSymlink(asSpan(\&full)) then#if false then#|a symbolic link is followed"
	"Asset.hiq|s#return 16;#return 15;#|the version has 15 digits"
	"Asset.hiq|s#if (path\[0\] /= '/') or (path\[size - 1\] = '/') then#if path\[size - 1\] = '/' then#|a path need not start with a slash"
	"Asset.hiq|s#let upper: Bool := (byte >= 'A') and (byte <= 'Z');#let upper: Bool := (byte >= ' ') and (byte <= 'Z');#|a space and other marks pass"
	"examples/hello/Hello.hiq|s#:= \"www\";#:= \"www/static\";#|the root is one level too deep"
)
