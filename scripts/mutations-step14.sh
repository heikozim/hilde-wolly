# The mutations of Wolly.FormGuard and examples/contact, sourced by
# scripts/mutate.sh.
mutations+=(
	'FormGuard.hiq|s/if spanLength(honeypot) > 0 then/if false then/|a filled honeypot passes'
	'FormGuard.hiq|s/if age < fastestSeconds() then/if age < 2 then/|2 seconds are fast enough'
	'FormGuard.hiq|s/if age > slowestSeconds() then/if age > (slowestSeconds() + 1) then/|1801 seconds are not too late'
	'FormGuard.hiq|s/let fits: Bool := constantTimeEqual(asSpan(&expected), mac);/let fits: Bool := true;/|any signature is taken'
	'FormGuard.hiq|s/INSERT OR IGNORE INTO wolly_used_stamps/INSERT OR REPLACE INTO wolly_used_stamps/|a stamp is good more than once'
	'FormGuard.hiq|s/if made > now then/if false then/|a stamp from the future is not called expired'
	'examples/contact/Contact.hiq|s/if sameOrigin(&request) then/if true then/|another site may post'
	'examples/contact/Contact.hiq|s/constant postLimit: Int64 := 3;/constant postLimit: Int64 := 4;/|the example takes one message more'
)
