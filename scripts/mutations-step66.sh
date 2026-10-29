# The mutations of the statements Wolly keeps for PostgreSQL,
# sourced by scripts/mutate-target.sh.  "pg: " in the description makes the unit
# test on PostgreSQL the only check of a mutation; the others are the SQLite
# statements the PostgreSQL tests made visible.
mutations+=(
	"Cache.hiq|s/(SELECT coalesce(max(used), 0) + 1 FROM wolly_cache WHERE scope = ?1))/(SELECT coalesce(max(used), 0) + 0 FROM wolly_cache WHERE scope = ?1))/|a put does not count as a use"
	"Cache.hiq|s/SET used = (SELECT max(used) + 1 FROM wolly_cache WHERE scope = ?1)/SET used = (SELECT max(used) FROM wolly_cache WHERE scope = ?1)/|a get uses a value as the newest one has been used"
	"Cache.hiq|s/ORDER BY used LIMIT \$2)\";/ORDER BY used DESC LIMIT \$2)\";/|pg: the value used last is dropped"
	"Cache.hiq|s/\$4, (SELECT coalesce(max(used), 0) + 1/\$4, (SELECT coalesce(max(used), 0) + 0/|pg: a put does not count as a use"
	"Cache.hiq|s/SET used = (SELECT max(used) + 1 FROM wolly_cache WHERE scope = \$1)/SET used = (SELECT max(used) FROM wolly_cache WHERE scope = \$1)/|pg: a get uses a value as the newest one has been used"
	"Cache.hiq|s/WHERE scope = \$1 AND key = \$2\";/WHERE scope = \$1\";/|pg: a get counts as a use of every value of the scope"
	"Cache.hiq|s/PRIMARY KEY (scope, key))\";/PRIMARY KEY (scope))\";/|pg: a key is unique across the scopes"
)
mutations+=(
	"Limit.hiq|s/at BIGINT NOT NULL)\";/at INTEGER NOT NULL)\";/|pg: the time of a hit a 32 bit column"
	"Metrics.hiq|s/value BIGINT NOT NULL CHECK (value >= 0))\";/value INTEGER NOT NULL CHECK (value >= 0))\";/|pg: the value of a sample a 32 bit column"
	"Entity.hiq|s/entity BIGINT NOT NULL, PRIMARY KEY (kind, field, value))\";/entity INTEGER NOT NULL, PRIMARY KEY (kind, field, value))\";/|pg: the entity of a unique value a 32 bit column"
	"Rambo.hiq|s/made BIGINT NOT NULL)\";/made INTEGER NOT NULL)\";/|pg: the time of a login a 32 bit column"
	"Passkey.hiq|s/public_key BYTEA NOT NULL/public_key TEXT NOT NULL/|pg: a public key kept as text"
)
