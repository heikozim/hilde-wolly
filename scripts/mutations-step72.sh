# The mutations of RAMBO's logout form (Wolly.Rambo.logoutForm and
# logoutPolicy), sourced by scripts/mutate.sh and scripts/mutate-target.sh.
mutations+=(
	"src/Wolly/Rambo.hiq|s/let escaped: String := escapeCode(value);/let escaped: String := fromSpan(value);/|the fields are not escaped"
	"src/Wolly/Rambo.hiq|s/writeField(\&!out, \"id_token_hint\", idTokenHint);/skip;/|the form has no hint"
	"src/Wolly/Rambo.hiq|s/:= \"document.forms\[0\].submit();\";/:= \"\";/|the page does not submit itself"
	"src/Wolly/Rambo.hiq|s/8lDeP0UDwCO6/8lDeP0UDwCO7/|the policy allows another script"
	"src/Wolly/Rambo.hiq|s/form-action 'self' /form-action * /|forms to anywhere"
	"src/Wolly/Rambo.hiq|s/writeString(\&!out, \"%3B\");/writeByte(\&!out, byte);/|a semicolon of the issuer ends the directive"
	"src/Wolly/Rambo.hiq|s/<noscript>/<span>/|no button without script"
	"src/Wolly/Rambo.hiq|s/no-referrer/unsafe-url/|the page sends its address on"
)
