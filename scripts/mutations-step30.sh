# The mutations of the notes of examples/login, a table of its own,
# sourced by scripts/mutate.sh.
mutations+=(
	"examples/login/Login.hiq|s/WHERE owner = ? ORDER BY id DESC LIMIT 100/WHERE owner <> ? ORDER BY id DESC LIMIT 100/|a user sees the notes of the others"
	"examples/login/Login.hiq|s/ORDER BY id DESC LIMIT 100/ORDER BY id LIMIT 100/|the oldest note comes first"
	"examples/login/Login.hiq|s/(spanLength(text) > noteLength) then/(spanLength(text) > (noteLength + 1)) then/|a note of 501 bytes is taken"
	"examples/login/Login.hiq|s/if (text\[i\] < 32) or (text\[i\] = 127) then/if text[i] = 127 then/|a note with a line feed is taken"
	"examples/login/Login.hiq|s/        return isValid(text);/        return true;/|a note that is no UTF-8 is taken"
)
