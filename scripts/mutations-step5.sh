# The mutations of Wolly.Middleware, of withHeader and of the templates and
# the chain of examples/login, sourced by scripts/mutate.sh.  The last three
# break files outside src and are caught by the end-to-end run or not at all.
mutations+=(
	"Middleware.hiq|s/return runBefores(passed, befores, at + 1);/return Next(request => passed);/|only the first step before runs"
	"Middleware.hiq|s/                return runAfters(output, afters, 0);/                return output;/|an answer of a step before skips the steps after"
	"Middleware.hiq|s/equal(verb, \"OPTIONS\")/equal(verb, \"TRACE\")/|TRACE is a known method"
	"Response.hiq|s/if hasHeader(substring(asSpan(\&output), 0, at + 2), name) then/if false then/|a header that is there is added again"
	"examples/login/templates/login.jinja|s/: {{ name }}{% endif %}/: {{ name|safe }}{% endif %}/|the typed name is written unescaped"
	"examples/login/Login.hiq|s/insertBack(\&!afters, securityHeaders);/skip;/|the security headers are left out"
	"examples/login/Login.hiq|s/insertBack(\&!befores, knownMethods);/skip;/|QUERY reaches the router"
)
