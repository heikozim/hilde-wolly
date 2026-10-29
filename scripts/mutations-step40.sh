# The mutations of Wolly.Net, sourced by scripts/mutate.sh and
# scripts/mutate-target.sh.
mutations+=(
	"Net.hiq|s/return bits > 0;/return true;/|a default route trusts every peer"
	"Net.hiq|s/if not isTrusted(peerAddress, trusted) then/if false then/|a stranger's forwarding header is believed"
	"Net.hiq|s/if not isTrusted(hop, trusted) then/if true then/|the hop next to the proxy wins, trusted or not"
	"Net.hiq|s/while (start > 0) and (forwarded\[start - 1\] \/= 44) do/while (start > 0) and (forwarded[start - 1] = 44) do/|the chain is not split at commas"
	"Net.hiq|s/                            return peerText(peer);/                            skip;/|a part that is no address is skipped, not the end"
	"Net.hiq|s/return not isPrivateOrReserved(address);/return true;/|a private address counts as public"
	"Net.hiq|s/if (length = 0) or (length > labelMost) then/if length = 0 then/|a label of 64 bytes"
	"Net.hiq|s/if (text\[labelStart\] = 45) or (text\[i - 1\] = 45) then/if false then/|a hyphen first or last"
	"Net.hiq|s/return (letter or digit) or (byte = 45);/return true;/|any byte in a host name"
	"Net.hiq|s/if (text\[i\] = 48) and groupStart then/if false then/|leading zeros pass"
	"Net.hiq|s/return size = 0;/return true;/|a list of spaces is a list"
	"Net.hiq|s/if narrowed > width then/if false then/|33 bits of IPv4"
)
