# The mutations of Wolly.SoundSearch and of /admin/find in examples/login,
# sourced by scripts/mutate.sh.
mutations+=(
	"SoundSearch.hiq|s/        return (((byte >= 'a') and (byte <= 'z')) or ((byte >= 'A') and (byte <= 'Z'))) or (byte >= 128);/        return ((byte >= 'a') and (byte <= 'z')) or (byte >= 128);/|capitals part words"
	"SoundSearch.hiq|s/                    return narrowed(\&~db, keys, first, second);/                    return Right(right => keys);/|a second word asks nothing"
	"SoundSearch.hiq|s/                if (limit >= 1) and (limit < 100) then/                if false then/|the limit is not held"
	"SoundSearch.hiq|s/        if (spanLength(key) = 0) or (spanLength(key) > mostKey()) then/        if spanLength(key) > mostKey() then/|an empty key is kept"
	"SoundSearch.hiq|s/:= \"DELETE FROM wolly_sounds WHERE key = ?\";/:= \"DELETE FROM wolly_sounds WHERE key = ? AND 0\";/|the codes of before stay"
	"examples/login/Login.hiq|0,/                if not granted then/s//                if false then/|a user without the role finds"
)
