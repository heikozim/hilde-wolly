# The mutations of Wolly.Acme that the unit tests see, sourced by
# scripts/mutate.sh and scripts/mutate-target.sh.  What only the run against
# Pebble sees is checked by scripts/e2e-acme-live.sh.
mutations+=(
	"Acme.hiq|s/constant tokenMost: Index := 128;/constant tokenMost: Index := 1280;/|a token of 129 bytes is a token"
	"Acme.hiq|s/constant namesMost: Index := 20;/constant namesMost: Index := 200;/|a certificate for 21 names"
	"Acme.hiq|s/constant thirtyDays: Int64 := 2592000;/constant thirtyDays: Int64 := 25920;/|renewal begins late"
	"Acme.hiq|s/or ((byte = 45) or (byte = 95))/or ((byte = 46) or (byte = 95))/|a dot in a token, no hyphen"
	"Acme.hiq|s/return (finish - at) < before;/return (finish - at) > before;/|renewal is turned round"
	"Acme.hiq|s/if contains(names, \"\*\") then/if contains(names, \"#\") then/|a wildcard name for http-01"
	"Acme.hiq|s/acme-challenge\//acme-challenges\//|the answer is written where the server does not look"
	"Acme.hiq|s/if not isDnsNameList(names) then/if false then/|a name list that is no list"
)
