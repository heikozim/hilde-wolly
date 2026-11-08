# The mutations of Wolly.Pseudonym and of the client in examples/login,
# sourced by scripts/mutate.sh.
mutations+=(
	"Pseudonym.hiq|s/if spanLength(key) < keyBytes then/if false then/|a key shorter than 32 bytes makes pseudonyms"
	"Pseudonym.hiq|s/case hmacSha256(key, purpose) of/case hmacSha256(key, \"\") of/|the key of the pseudonyms has no purpose of its own"
	"Pseudonym.hiq|s/let mac: Option\[String\] := hmacSha256(asSpan(\&sub), value);/let mac: Option[String] := hmacSha256(key, value);/|the pseudonym is the HMAC under the key itself"
	"examples/login/Login.hiq|s/let made: Option\[String\] := pseudonym(asSpan(\&key), asSpan(\&address));/let made: Option[String] := Some(value => fromSpan(asSpan(\&address)));/|the example keeps and logs the address itself"
)
