# The mutations of Wolly.Metrics, sourced by scripts/mutate.sh and
# scripts/mutate-target.sh.
mutations+=(
	"Metrics.hiq|s/constant bucketsMost: Index := 1000;/constant bucketsMost: Index := 2000;/|2000 buckets"
	"Metrics.hiq|s/constant nameMost: Index := 64;/constant nameMost: Index := 65;/|a name of 65 bytes"
	"Metrics.hiq|s/constant stepMost: Int64 := 31622400;/constant stepMost: Int64 := 31622401;/|a step above a year"
	"Metrics.hiq|s/let lower: Bool := (byte >= 97) and (byte <= 122);/let lower: Bool := (byte >= 65) and (byte <= 122);/|upper case in a name"
	"Metrics.hiq|s/if ((not isMetricName(name)) or (value < 0)) or (at < 0) then/if (not isMetricName(name)) or (at < 0) then/|a value below 0 is kept"
	"Metrics.hiq|s/or (value < 0)) or (at < 0) then/or (value < 0)) or false then/|a time below 0 is kept"
	"Metrics.hiq|s/WHERE name = ? AND at >= ? AND at < ? GROUP BY 1 ORDER BY 1\";/WHERE name = ? AND at >= ? GROUP BY 1 ORDER BY 1\";/|samples after the series count"
	"Metrics.hiq|s/SELECT (at - ?) \/ ?, SUM(value) FROM wolly_metrics WHERE name = ? AND at >= ?/SELECT (at - ?) \/ ?, SUM(value) FROM wolly_metrics WHERE name = ? AND at >= ? - 60/|samples before the series count"
	"Metrics.hiq|s/SELECT (at - ?) \/ ?, MAX(value)/SELECT (at - ?) \/ ?, SUM(value)/|the largest is the sum"
	"Metrics.hiq|s/ORDER BY at DESC, rowid DESC LIMIT 1/ORDER BY at ASC, rowid DESC LIMIT 1/|the latest is the earliest"
	"Metrics.hiq|s/DELETE FROM wolly_metrics WHERE at < ?/DELETE FROM wolly_metrics WHERE at <= ?/|a prune takes the sample at its time"
	"Metrics.hiq|s/if count > bucketsMost then/if false then/|buckets are not cut"
)
