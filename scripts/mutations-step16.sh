# The mutations of Wolly.Ban, the digits of Wolly.Response and the ban in
# examples/contact, sourced by scripts/mutate.sh.
mutations+=(
	"Ban.hiq|s/if asked > longestBanSeconds() then/if false then/|a ban longer than a day is asked for"
	"Ban.hiq|s/\"X-Hiawatha-Ban\"/\"X-Hiawatha-Bann\"/|the header has a name Hiawatha does not read"
	"Ban.hiq|s/return 86400;/return 86401;/|the longest ban is a second more than a day"
	# Wolly.Response.decimalText is Standard.Text.formatInt since Hilde gained it; its digits are Hilde's to mutate.
	"Response.hiq|s/        return formatInt(value);/        return formatInt(value + 1);/|a number is written one too high"
	"examples/contact/Contact.hiq|s/return trapped();/return sent();/|a filled honeypot is not banned"
)
