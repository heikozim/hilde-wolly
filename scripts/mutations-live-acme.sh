# The mutations of Wolly.Acme that only the run against Pebble sees, for
# the run of scripts/e2e-acme-live.sh beside Pebble (not for
# scripts/mutate.sh: they need a network).  Format as in mutations-step*.sh.
mutations+=(
	"Acme.hiq|s/publicOnly => not privateCa/publicOnly => true/|a server on a private address is never reached"
	"Acme.hiq|s/publicOnly => not privateCa/publicOnly => false/|a server on a private address is reached without the word"
	"Acme.hiq|s/let reused: Bool := equal(asSpan(\&status), \"valid\");/let reused: Bool := false;/|an authorization the server reuses is answered again"
	"Acme.hiq|s/let removed: Bool := removeFileIfThere(asSpan(\&path));/let removed: Bool := true;/|the answer file stays"
	"Acme.hiq|s/let answer: String := keyAuthorization(\&~account, asSpan(\&(challenge->token)));/let answer: String := fromSpan(asSpan(\&(challenge->token)));/|the answer is the token and not the key authorization"
	"Acme.hiq|s/certificateRequest(\&key, \"\", names)/certificateRequest(\&key, \"\", \"other.example.org\")/|the request asks for another name"
	"Acme.hiq|s/let put: Bool := putAnswer(webroot, asSpan(\&path), asSpan(\&answer));/let put: Bool := true;/|the answer is never written"
	"Acme.hiq|s/if ((not usableNames(names)) or/if ((false) or/|a wildcard goes to the server"
)
