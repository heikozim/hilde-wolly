# The mutations of Wolly.Dbsc and of the bound sessions of Wolly.Auth,
# sourced by scripts/mutate.sh.
mutations+=(
	"Dbsc.hiq|s/if not stringIs(header, \"\/typ\", proof_type) then/if false then/|a proof of another typ passes"
	"Dbsc.hiq|s/                return registering;/                return true;/|a jwk at a refresh passes"
	"Dbsc.hiq|s/if not (open and same) then/if false then/|a refresh signs any challenge"
	"Dbsc.hiq|s/AND fresh_until >= ?\"/AND fresh_until + 100000 >= ?\"/|a bound cookie outlives boundSeconds"
	"Dbsc.hiq|s/                fits := equal(columnText(\&cursor, 0), name);/                fits := true;/|an offer to one user binds another"
	"Dbsc.hiq|s/            if columnInt64(\&cursor, 1) >= now then/            if true then/|an offer that ran out passes"
	"Dbsc.hiq|s/if (not there) or (created_at < (now - boundLifeSeconds())) then/if not there then/|a binding outlives its life"
	"Auth.hiq|s/        case unbind(\&~db, token, now) of/        case unbind(\&~db, \"\", now) of/|a logout leaves the binding"
)
