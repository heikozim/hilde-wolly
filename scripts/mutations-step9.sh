# The mutations of the end-to-end run over TLS, sourced by scripts/mutate.sh.
# All three break a file outside src and are caught by the end-to-end run or
# not at all; the unit tests of Wolly.Guard do not set HTTPS.
mutations+=(
	"scripts/e2e.sh|s/SCHEME=https$/SCHEME=http/|the run over TLS asks over plain HTTP"
	"scripts/e2e.sh|s#\"\${tls_binding\[@\]}\" ##|Hiawatha does not speak TLS in the run over TLS"
	"src/Wolly/Guard.hiq|s#writeString(\&!origin, \"https://\");#writeString(\&!origin, \"http://\");#|a request over TLS expects an http Origin"
)
