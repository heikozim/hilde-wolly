# The mutations of Wolly.Passphrase and of its use in Wolly.Auth and
# examples/login, sourced by scripts/mutate.sh.
mutations+=(
	"Passphrase.hiq|s/            return 8;/            return 7;/|7 characters are enough with a second factor"
	"Passphrase.hiq|s/        return 256;/        return 255;/|256 characters are too long"
	"Passphrase.hiq|s/toNfkc/toNfc/g|passwords are brought to NFC, not NFKC"
	"Passphrase.hiq|s/let count: Index := characterCount(asSpan(\&normal));/let count: Index := length(\&normal);/|bytes are counted, not characters"
	"Passphrase.hiq|s/if (stop > start) and (list\[stop - 1\] = '.r') then/if false then/|a line of the list that ends in CRLF is never matched"
	"Passphrase.hiq|s/                    return Listed();/                    skip;/|a listed password is taken"
	"Passphrase.hiq|s/                return ListUnreadable();/                return PassphraseFits();/|without a list every password fits"
	"Passphrase.hiq|s/        if holds then/        if false then/|a password may hold the name"
	"Auth.hiq|s/if not isFit(checkPassphrase(next, name, second, listPath)) then/if false then/|a change takes any password"
	"Auth.hiq|s/(not isFit(checkPassphrase(password, name, false, listPath)))/false/|a new user takes any password"
	"Auth.hiq|s/case normalizedMatches(\&~db, name, password) of/case passwordMatches(\&~db, name, password) of/|the login does not bring the password to NFKC"
	"examples/login/Login.hiq|s/return substring(line, 0, stop);/return substring(line, 2, stop);/|the start of a password from the command line is cut"
)
