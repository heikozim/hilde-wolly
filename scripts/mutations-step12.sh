# The mutations of Wolly.Limit, sourced by scripts/mutate.sh.
mutations+=(
	'Limit.hiq|s/if count >= limit then/if count > limit then/|one call past the limit goes through'
	'Limit.hiq|s/AND at <= ?";/AND at < ?";/|a call exactly a window old still counts'
	'Limit.hiq|s/let wait: Int64 := (first + window) - now;/let wait: Int64 := window;/|the wait is always the whole window'
	'Limit.hiq|s/WHERE scope = ? AND key = ?"/WHERE ? IS NOT NULL AND key = ?"/|two scopes share one count'
	'examples/login/Login.hiq|s/constant postLimit: Int64 := 100;/constant postLimit: Int64 := 101;/|the example lets one POST more through'
	'examples/login/Login.hiq|s/^        insertBack(&!befores, limitPosts);$//|the example has no limit on POST'
)
