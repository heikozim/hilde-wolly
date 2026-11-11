# The mutations of Wolly.Request and Wolly.Router, sourced by scripts/mutate.sh.
mutations+=(
	"Router.hiq|s/if aend = ai then/if false then/|an empty segment fits a parameter"
	"Router.hiq|s/if equal(segment, \"\\*\") and (pend = plen) then/if equal(segment, \"*\") then/|a star inside a pattern is a wildcard"
	"Router.hiq|s/return equal(verb, \"HEAD\") and equal(wanted, \"GET\");/return false;/|a request for the headers alone finds no GET route"
	"Router.hiq|s/writeString(\&!allow, r.verb);/skip;/|405 without the methods in Allow"
	"Router.hiq|s/while (i < length(routes)) and (not hit) do/while i < length(routes) do/|the last route that fits wins, not the first"
	"Request.hiq|s/replace(raw, \"+\", \" \")/replace(raw, \"+\", \"+\")/|a plus in a query stays a plus"
	"Request.hiq|s/return fromSpan(substring(uri, 0, at));/return fromSpan(uri);/|the query stays in the path"
	"Request.hiq|s/if matches and (spanLength(piece) > 0) then/if matches then/|an empty name matches an empty piece"
)
