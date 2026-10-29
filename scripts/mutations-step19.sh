# The mutations of the second factor: Wolly.Seal, Wolly.Totp, the code in
# Wolly.Auth and its pages in examples/login, sourced by scripts/mutate.sh.
mutations+=(
	"Seal.hiq|s/if spanLength(key) < sealKeyBytes() then/if false then/|a key shorter than 32 bytes seals"
	"Seal.hiq|s/return hmacSha256(key, purpose);/return hmacSha256(key, \"\");/|one key seals the same for every purpose"
	"Seal.hiq|s/asSpan(\&nonce), value, context)/asSpan(\&nonce), value, \"\")/|the context is not bound to the value"
	"Totp.hiq|s/ AND enabled = ? AND last_step < ?\";/ AND enabled = ? AND ? > 0\";/|a step taken is taken again"
	"Totp.hiq|s/let after: Bool := codeAt(seed, code, step + 1);/let after: Bool := false;/|no code of the step after now"
	"Totp.hiq|s/ WHERE wolly_totp.enabled = 0\";/\";/|a start replaces a seed that is on"
	"Totp.hiq|s/OtpSha256/OtpSha1/g|the codes are made with SHA-1"
	"Auth.hiq|s/                if second then/                if false then/|the password alone logs in a user with the factor"
	"Auth.hiq|s/((now - since) > pendingSeconds())/((now - since) > (pendingSeconds() * 2))/|the session waits for the code twice as long"
	"Auth.hiq|s/\"code-needed\");/\"code-needed\");\n                            let wiped: Option[AuthError] := clearFailures(\&~db, clearByName, name);/|the password clears the failures of the name"
	"examples/login/Login.hiq|s/redirect(\"\/login\/code\"), asSpan(\&waiting)/redirect(\"\/\"), asSpan(\&waiting)/|the login does not lead to the form for the code"
	"examples/login/Login.hiq|s/img-src data:; //|the page of the factor may show no image"
)
