# The mutations of Wolly.Cache, sourced by scripts/mutate.sh
# and scripts/mutate-target.sh.
mutations+=(
	"Cache.hiq|s/WHERE scope = ? AND key = ? AND expires > ?\";/WHERE scope = ? AND key = ? AND expires >= ?\";/|a value is given in the second it runs out"
	"Cache.hiq|s/                if count > most then/                if count > (most + 1) then/|a scope holds one more than most"
	"Cache.hiq|s/ORDER BY used LIMIT ?2)\";/ORDER BY used DESC LIMIT ?2)\";/|the value used last is dropped"
	"Cache.hiq|s/        case execute(\&~db, dropRunOut, withInt64(withText(noValues(), scope), now)) of/        case execute(\&~db, dropRunOut, withInt64(withText(noValues(), scope), 0)) of/|values that ran out are not dropped first"
	"Cache.hiq|s/                return marked(\&~db, scope, key, text);/                let some: Option[String] := Some(value => text);\n                    return Right(right => some);/|a get is no use"
	"Cache.hiq|s/                let there: Bool := dropped > 0;/                let there: Bool := true;/|a drop always finds a value"
	"Cache.hiq|s/ON CONFLICT (scope, key) DO UPDATE SET value = excluded.value, expires = excluded.expires, used = excluded.used\";/ON CONFLICT (scope, key) DO NOTHING\";/|a put keeps the old value"
	"Cache.hiq|s/    constant dropScope: Span\[Nat8, Static\] := \"DELETE FROM wolly_cache WHERE scope = ?\";/    constant dropScope: Span[Nat8, Static] := \"DELETE FROM wolly_cache WHERE scope = ? OR 1\";/|a clear takes every scope"
	"Cache.hiq|s/now + seconds)) of/now)) of/|a value runs out at once"
)
