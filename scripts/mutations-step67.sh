# More mutations of the statements Wolly keeps for PostgreSQL, as step 66:
# "pg: " in the description makes the unit tests on PostgreSQL the only checks of a mutation.
mutations+=(
	"Metrics.hiq|s/ORDER BY at DESC, rowid DESC LIMIT 1/ORDER BY at DESC, rowid ASC LIMIT 1/|of two samples in one second the first is the latest"
	"Metrics.hiq|s/ORDER BY at DESC, id DESC LIMIT 1/ORDER BY at ASC, id DESC LIMIT 1/|pg: the latest is the earliest"
	"Metrics.hiq|s/ORDER BY at DESC, id DESC LIMIT 1/ORDER BY at DESC, id ASC LIMIT 1/|pg: of two samples in one second the first is the latest"
	"Metrics.hiq|s/CAST(SUM(value) AS BIGINT)/CAST(MAX(value) AS BIGINT)/|pg: the total is the largest"
	"Metrics.hiq|s/WHERE name = ? AND at >= ? AND at < ? GROUP BY 1 ORDER BY 1\";/WHERE name = ? AND at >= ? GROUP BY 1 ORDER BY 1\";/|pg: samples after the series count"
	"Passkey.hiq|s/WHERE credential = ? AND (sign_count < ? OR (sign_count = 0 AND CAST/WHERE credential = ? AND (sign_count <= ? OR (sign_count = 0 AND CAST/|pg: the same counter passes twice"
	"Rambo.hiq|s/DO UPDATE SET token = excluded.token, made = excluded.made\";/DO NOTHING\";/|pg: a newer ID token does not replace the old"
	"Rambo.hiq|s/ON CONFLICT (id) DO UPDATE SET jwks = excluded.jwks, made = excluded.made\";/ON CONFLICT (id) DO NOTHING\";/|pg: new keys do not replace the old"
	"Rambo.hiq|s/VALUES (?, ?, ?, ?, ?) ON CONFLICT DO NOTHING\";/VALUES (?, ?, ?, ?, ?)\";/|pg: a state seen twice is an error"
	"Role.hiq|s/(role, action) VALUES (?, ?) ON CONFLICT DO NOTHING\";/(role, action) VALUES (?, ?)\";/|pg: a second grant of an action is an error"
	"Role.hiq|s/(name, role) VALUES (?, ?) ON CONFLICT DO NOTHING\";/(name, role) VALUES (?, ?)\";/|pg: a second assignment of a role is an error"
	"FormGuard.hiq|s/(mac, until) VALUES (?, ?) ON CONFLICT DO NOTHING\";/(mac, until) VALUES (?, ?)\";/|pg: a stamp used twice is an error, not a refusal"
	"Edges.hiq|s/ORDER BY node LIMIT 10000\";/ORDER BY node LIMIT 2\";/|pg: the nodes below an origin cut after two"
	"Edges.hiq|s/WHERE e.kind = ?) SELECT node FROM r ORDER BY node LIMIT 10000\";/WHERE e.kind = ?) SELECT node FROM r ORDER BY node DESC LIMIT 10000\";/|pg: the nodes in descending order"
	"Entity.hiq|s/value TEXT NOT NULL, entity BIGINT NOT NULL, PRIMARY KEY (kind, field, value))/value TEXT NOT NULL, entity BIGINT NOT NULL, PRIMARY KEY (kind, value))/|pg: a value is unique across the fields of a kind"
	"Cache.hiq|s/ON CONFLICT (scope, key) DO UPDATE SET value = excluded.value, expires = excluded.expires, used = excluded.used\";/ON CONFLICT (scope, key) DO NOTHING\";/|pg: a put keeps the old value"
	"Blob.hiq|s/content BYTEA NOT NULL)/content TEXT NOT NULL)/|pg: the content of a blob kept as text"
	"Totp.hiq|s/seed BYTEA NOT NULL/seed TEXT NOT NULL/|pg: a seed kept as text"
)
