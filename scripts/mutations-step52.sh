# The mutations of Wolly.Passkey.relyingPartyId, moved from examples/login,
# sourced by scripts/mutate.sh and scripts/mutate-target.sh.
mutations+=(
	"Passkey.hiq|s/        if (j < spanLength(origin)) and (origin\[j\] = '\[') then/        if false then/|an IPv6 address keeps its brackets"
	"Passkey.hiq|s/^            j := j + 1;\$/            j := j;/|the opening bracket is kept"
	"Passkey.hiq|s/        while (i + 2) < spanLength(origin) do/        while (i + 3) < spanLength(origin) do/|a scheme mark at the end is not seen"
	"Passkey.hiq|s/            while (j < spanLength(origin)) and (origin\[j\] \/= ':') do/            while (j < spanLength(origin)) and (origin[j] \/= ';') do/|the port is kept"
	"Passkey.hiq|s/                first := i + 3;/                first := i + 2;/|the slash before the host is kept"
	# deluser and what it takes along: the e2e
	# of gus in scripts/e2e-login.sh.
	"examples/login/Login.hiq|s/if not cleanedUp(removeTotp(&~db, name)) then/if not cleanedUp(removeTotp(\&~db, \"nobody-at-all\")) then/|deluser leaves the seed of the second factor"
	"examples/login/Login.hiq|s/if not cleanedUp(removePasskeys(&~db, name)) then/if not cleanedUp(removePasskeys(\&~db, \"nobody-at-all\")) then/|deluser leaves the passkeys"
)
