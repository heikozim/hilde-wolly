# The mutations of Wolly.AuditLog and of its use in examples/login: the
# pseudonym of a removed user and the retention of 12 months,
# sourced by scripts/mutate.sh.  The two of Auth.hiq are named by path, so
# that the end-to-end run, which holds the lock in a second process, sees
# them.
mutations+=(
	"src/Wolly/Auth.hiq|s/                    if not isBusy(error) then/                    if true then/|after the busy time the line is lost"
	"src/Wolly/Auth.hiq|s/\"lock_retries\", retries)/\"lock_retries\", 0)/|the retries are not counted"
	"AuditLog.hiq|s/named := equal(asSpan(\&user), name);/named := spanLength(asSpan(\&user)) >= spanLength(name);/|a name that starts with the removed one is taken"
	"AuditLog.hiq|s/if equal(asSpan(\&member), \"user\") or equal(asSpan(\&member), \"client\") then/if equal(asSpan(\&member), \"user\") then/|the client keeps its value"
	"AuditLog.hiq|s/if kept and (changed > 0) then/if false then/|the rewritten log is not written"
	"AuditLog.hiq|s/                return Some(value => fromSpan(\"\"));/                return None();/|a missing log is an error"
	"AuditLog.hiq|s/old := seconds < cutoff;/old := seconds <= cutoff;/|the line at the cutoff goes"
	"AuditLog.hiq|s/return 31536000;/return 2592000;/|30 days instead of 12 months"
	"AuditLog.hiq|s/\"lines\", lines);/\"lines\", 0);/|the count is not noted"
	"examples/login/Login.hiq|s/case pseudonymize(auditPath, name, asSpan(\&alias)) of/case pseudonymize(auditPath, \"nobody\", asSpan(\&alias)) of/|deluser leaves the audit log as it was"
	"examples/login/Login.hiq|s/let noted: Bool := note(auditPath, \"audit-pseudonymize\", asSpan(\&alias), count);/let noted: Bool := true;/|the pseudonymization is not noted"
	"examples/login/Login.hiq|s/failed := not note(auditPath, \"audit-prune\", \"-\", count);/failed := not note(auditPath, \"audit-prune\", \"-\", 0);/|the retention run notes no count"
	"examples/login/Login.hiq|s/case prune(auditPath, now()) of/case prune(auditPath, 0) of/|the retention run removes nothing"
)
