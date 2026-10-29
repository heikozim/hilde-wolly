# The mutations of the access log of Wolly.Middleware and of examples/login,
# sourced by scripts/mutate.sh.  The last one breaks a file outside src and
# is caught by the end-to-end run or not at all.
mutations+=(
	"Middleware.hiq|s/orDash(requestPath(\&request))/orDash(requestParam(\&request, \"REQUEST_URI\"))/|the query goes into the log"
	"Middleware.hiq|s/statusOf(asSpan(\&output))/200/|every status is logged as 200"
	"Middleware.hiq|s/return fromSpan(\"-\");/return fromSpan(\"\");/|a missing method is logged empty"
	"Middleware.hiq|s/\"client\", asSpan(\&client)/\"client\", \"\"/|the client is left out"
	"examples/login/Login.hiq|s/let output: String := dispatchLogged(request, routes, befores, afters, \&!log);/let output: String := dispatchWith(request, routes, befores, afters);/|the example writes no access log"
)
