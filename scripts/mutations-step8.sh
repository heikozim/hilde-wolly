# The mutations of the throttling per user name in Wolly.Auth,
# sourced by scripts/mutate.sh.
mutations+=(
	"Auth.hiq|s/if named >= failureLimit() then/if false then/|a name is never throttled"
	"Auth.hiq|s/case recordFailure(\&~db, addByName, name, now) of/case clearFailures(\&~db, clearByName, name) of/|a failure of a name is not counted"
	"Auth.hiq|s/case clearFailures(\&~db, clearByName, name) of/case clearFailures(\&~db, clearByClient, client) of/|a login does not clear the failures of the name"
	"Auth.hiq|s/case failuresSince(\&~db, countByName, name, now - failureWindowSeconds()) of/case failuresSince(\&~db, countByName, name, 0) of/|the failures of a name never age"
	"Auth.hiq|s/\"throttled-name\"/\"throttled\"/|the audit does not tell a throttled name from a throttled address"
)
