# The mutations of Wolly.Auth's externalLogin (a sign-in RAMBO vouched
# for), sourced by scripts/mutate.sh and scripts/mutate-target.sh.
mutations+=(
	"Auth.hiq|s/                if not there then/                if false then/|a name that is no user here is logged in"
	"Auth.hiq|s/audit(\&~db, auditPath, \"login-external\", name, client, \"ok\");/audit(\&~db, auditPath, \"login-external\", name, client, \"done\");/|the audit misses the outcome of the login"
)
