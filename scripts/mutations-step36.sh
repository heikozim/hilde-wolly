# The mutations of the findings of a security review (Auth, Passkey) and of
# login deluser, Role.unassignAll and the cap on notes in examples/login,
# sourced by scripts/mutate.sh.  Auth.hiq is named by its path, so that the
# end-to-end runs see the mutation: no unit test reaches confirmPassword or
# a session of a removed user.
mutations+=(
	"Role.hiq|s/:= \"DELETE FROM wolly_holders WHERE name = ?\";/:= \"DELETE FROM wolly_holders WHERE name = ? AND role = ''\";/|unassignAll takes no role"
	"Passkey.hiq|s/if held >= mostPasskeys() then/if held > mostPasskeys() then/|a 21st passkey is kept"
	"Passkey.hiq|s/AND purpose = ?\";/AND purpose = ? AND 0\";/|an earlier challenge stays"
	"src/Wolly/Auth.hiq|s/                if matched then/                if true then/|any password confirms"
	"src/Wolly/Auth.hiq|s/if isUserName(user) then/if true then/|the audit keeps what is no name"
	"src/Wolly/Auth.hiq|s/                                    if there then/                                    if true then/|a session of a removed user opens"
	"examples/login/Login.hiq|s/(count < mostNotes)/(count <= mostNotes)/|a 101st note is kept"
	"examples/login/Login.hiq|s/removeUser(\&~db, name)/removeUser(\&~db, \"nobody\")/|deluser leaves the user"
	"examples/login/Login.hiq|s/unassignAll(\&~db, name)/unassignAll(\&~db, \"nobody\")/|deluser leaves the roles"
	"examples/login/Login.hiq|s/revokeTokens(\&~db, name)/revokeTokens(\&~db, \"nobody\")/|deluser leaves the tokens"
	"examples/login/Login.hiq|s/removeSounds(\&~db, name)/removeSounds(\&~db, \"nobody\")/|deluser leaves the sound of the name"
	"examples/login/Login.hiq|s/DELETE FROM notes WHERE owner = ?/DELETE FROM notes WHERE owner = ? AND id < 0/|deluser leaves the notes"
)
