# The mutations of Wolly.Signature and of POST /inbox in examples/hello,
# sourced by scripts/mutate.sh.
mutations+=(
	"Signature.hiq|s/((sent - now) > freshSeconds()) or //|a date from the future is not stale"
	"Signature.hiq|s/((now - sent) > freshSeconds())/((now - sent) >= freshSeconds())/|a date 300 seconds old is stale"
	"Signature.hiq|s/if (spanLength(content) > 0) and (not digestFits(digest, content)) then/if false then/|a body need not fit its digest"
	"Signature.hiq|s/fits := constantTimeEqual(substring(digest, at + 8, stop), asSpan(\&wanted));/fits := true;/|any SHA-256= digest fits"
	"Signature.hiq|s/if not algorithmTaken(algorithm) then/if false then/|rsa-sha1 is taken"
	"Signature.hiq|s/listHolds(headers, \"host\")) and listHolds(headers, \"date\")/listHolds(headers, \"host\")) and true/|the date need not be signed"
	"Signature.hiq|s/((spanLength(content) > 0) and (not listHolds(headers, \"digest\")))/false/|the digest of a body need not be signed"
	"Signature.hiq|s/return Forged();/return Verified(keyId => fromSpan(keyId));/|a signature that does not fit passes"
	"Signature.hiq|s/            if named then/            if true then/|a parameter of another name is taken"
	"Signature.hiq|s/equal(substring(date, 25, 29), \" GMT\")/true/|a date in another zone is read"
	"Signature.hiq|s/instantOf(civil, 0)/instantOf(civil, 3600)/|a date is read an hour off"
	"Signature.hiq|s/if ((byte \/= 10) and (byte \/= 13)) and (byte \/= ' ') then/if true then/|the line breaks of a PEM are decoded"
	"src/Wolly/Signature.hiq|s/let lower: String := toLower(asSpan(\&verb));/let lower: String := fromSpan(asSpan(\&verb));/|the verb is signed as it is sent"
	"src/Wolly/Signature.hiq|s/writeString(\&!out, \"HTTP_\");/skip;/|the CGI name of a header has no HTTP_"
)
