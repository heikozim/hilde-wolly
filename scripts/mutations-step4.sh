# The mutations of Wolly.Auth, Wolly.Secret, Wolly.Guard and the form of
# Wolly.Request, sourced by scripts/mutate.sh.
mutations+=(
	"Auth.hiq|s/if failures >= failureLimit() then/if false then/|a client is never throttled"
	"Auth.hiq|s/case recordFailure(\&~db, addByClient, client, now) of/case clearFailures(\&~db, clearByClient, client) of/|a failure is not counted"
	"Auth.hiq|/when DoesNotMatch do/{n;s/return Right(right => false);/return Right(right => true);/}|a wrong password matches"
	"Auth.hiq|s/audit(\&~db, auditPath, \"login\", name, client, \"refused\")/audit(\&~db, auditPath, \"login\", password, client, \"refused\")/|a password that was tried goes into the audit"
	"Auth.hiq|s/(spanLength(name) > 64)/(spanLength(name) > 65)/|a name of 65 bytes is taken"
	"Passphrase.hiq|s/            return 15;/            return 14;/|a password of 14 characters is enough without a second factor"
	"Auth.hiq|s/case rotateSession(\&~db, token, defaultSessionLimits(), now) of/case loadSession(\&~db, token, defaultSessionLimits(), now) of/|the login keeps the old token"
	"Secret.hiq|s/let closed: Bool := bitwiseAnd(status.mode, groupAndOthers) = noBits;/let closed: Bool := true;/|a key its group or others may read is taken"
	"Secret.hiq|s/let smallest: Nat64 := 32;/let smallest: Nat64 := 31;/|a key of 31 bytes is taken"
	"Guard.hiq|s/if not fromOwnOrigin(request) then/if false then/|a request from another site is taken"
	"Guard.hiq|s/let valid: Bool := csrfValid(key, sessionToken, asSpan(\&submitted));/let valid: Bool := true;/|any token is taken"
	"Guard.hiq|s/changing := changingMethod(asSpan(\&verb));/changing := false;/|no method needs the token"
	"Request.hiq|s/return exact or withParameters;/return true;/|a body of any type is read as a form"
)
