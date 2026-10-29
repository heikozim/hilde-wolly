# The mutations of the prune's query ordered by time (Wolly.LogStore,
# oldLinesPlan), sourced by scripts/mutate.sh and scripts/mutate-target.sh.
mutations+=(
	"LogStore.hiq|s/WHERE at < ? ORDER BY at, id LIMIT ?\";/WHERE at < ? ORDER BY id LIMIT ?\";/|a prune scans the whole table"
	"LogStore.hiq|s/return substring(oldLinesPlan, 19, spanLength(oldLinesPlan));/return substring(oldLinesPlan, 0, spanLength(oldLinesPlan));/|the prune runs the plan, not the query"
)
