# The mutations of Wolly.OpDbsc and of the bound sessions of the provider in
# Wolly.OpBase and Wolly.OpStore, sourced by scripts/mutate.sh.
mutations+=(
	"OpBase.hiq|s/                                        if not alive then/                                        if false then/|a bound provider session outlives boundSeconds"
	"OpStore.hiq|s/\"UPDATE op_sessions SET token_hash = ? WHERE id = ? AND ended_at = 0\"/\"UPDATE op_sessions SET token_hash = token_hash WHERE ? <> '' AND id = ? AND ended_at = 0\"/|a refresh leaves the cookie value before alive"
	"OpDbsc.hiq|s/                        if not lives then/                        if false then/|a refresh renews a session past its limits"
	"OpDbsc.hiq|s/                if already then/                if false then/|a bound session registers a second key"
)
