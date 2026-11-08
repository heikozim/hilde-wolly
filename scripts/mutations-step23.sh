# The mutations of Wolly.Bearer and of /api/whoami in examples/login,
# sourced by scripts/mutate.sh.
mutations+=(
	"Bearer.hiq|s/let stored: Either\[DbError, Nat64\] := execute(\&~db, addToken, withInt64(withText(withText(noValues(), asSpan(\&digest)), name), now));/let stored: Either[DbError, Nat64] := execute(\&~db, addToken, withInt64(withText(withText(noValues(), asSpan(\&token)), name), now));/|the database keeps the token itself"
	"Bearer.hiq|s/if (not named) or (header\[6\] \/= ' ') then/if not named then/|Bearer without a space before the token is taken"
	"Bearer.hiq|s/let named: Bool := equal(asSpan(\&scheme), \"bearer\");/let named: Bool := true;/|any scheme is taken as Bearer"
	"Bearer.hiq|s/\"WWW-Authenticate\", \"Bearer\"/\"WWW-Authenticate\", \"Basic\"/|a refusal names the wrong scheme"
	"examples/login/Login.hiq|s/                                        return unauthorized();/                                        return plain(200, \"token of nobody\\\\n\");/|an unknown token is answered 200"
)
