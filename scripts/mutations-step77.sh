# The mutations of the refusal of a template with a second hard link
# (Wolly.ViewCompile), sourced by scripts/mutate.sh and
# scripts/mutate-target.sh.  The load and the open each refuse it; a
# mutation of one alone is not caught, since the other still refuses, so
# both go at once.
mutations+=(
	"ViewCompile.hiq|s/if found.links > 1 then/if false then/; s/ or (now.links > 1);/;/|a template of two names is read"
	"ViewCompile.hiq|s/if found.links > 1 then/if found.links > 2 then/; s/ or (now.links > 1);/ or (now.links > 2);/|a template of two names passes, of three not"
)
