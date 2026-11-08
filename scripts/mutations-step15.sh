# The mutations of Wolly.Role and its page in examples/login, sourced by
# scripts/mutate.sh.
mutations+=(
	"Role.hiq|s/let granted: Bool := count > 0;/let granted: Bool := count >= 0;/|every user may do everything"
	"Role.hiq|s/JOIN wolly_grants g ON g.role = h.role/JOIN wolly_grants g/|a user may what any role was granted"
	"Role.hiq|s/WHERE h.name = ? AND g.action = ?/WHERE h.name = ? AND g.action <> ?/|a user may every action but the one asked"
	"Role.hiq|s/if not (isName(role) and isName(action)) then/if false then/|a role that is no name is granted"
	"Role.hiq|s/if not (isName(user) and isName(role)) then/if false then/|a role that is no name is assigned"
	"Role.hiq|s/let done: Bool := (not any) or (changed > 0);/let done: Bool := true;/|a revoke that found nothing says it removed a grant"
	"Role.hiq|s/(spanLength(name) > 64)/(spanLength(name) > 65)/|a name of 65 bytes is a name"
	"Role.hiq|s/(byte <= 'z')/(byte <= '{')/|a brace is part of a name"
	"Role.hiq|s/makeResponse(403,/makeResponse(200,/|forbidden answers 200"
	"examples/login/Login.hiq|s/if granted then/if true then/|the page admin opens for a user without the role"
)
