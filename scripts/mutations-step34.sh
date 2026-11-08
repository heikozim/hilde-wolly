# The mutations of Wolly.Highlight and of /code in examples/hello, sourced
# by scripts/mutate.sh.  No mutation keeps the state of a lexer when no
# token matched: that one does not fail, it loops.
mutations+=(
	"Highlight.hiq|s/                writeString(\&~out, \"\&lt;\");/                writeByte(\&~out, byte);/|< is written as it is"
	"Highlight.hiq|s/                            if byte = 39 then/                            if false then/|a single quote is written as it is"
	"Highlight.hiq|s/                                if byte = 0 then/                                if false then/|NUL is written as it is"
	"Highlight.hiq|s/        if spanLength(code) > mostHighlightBytes() then/        if spanLength(code) > (mostHighlightBytes() + 1) then/|one byte more than mostHighlightBytes is lexed"
	"Highlight.hiq|s/                        turn := (turn + 1) - (((turn + 1) \/ 4) \* 4);/                        turn := turn;/|every pair takes the same class"
	"Highlight.hiq|s/                        turn := (turn + 3) - (((turn + 3) \/ 4) \* 4);/                        turn := (turn + 1) - (((turn + 1) \/ 4) \* 4);/|a closing bracket does not go back"
	"Highlight.hiq|s/                    state := step.next;/                    state := state;/|the lexer of HTML never leaves a tag"
	"Highlight.hiq|s/equal(ext, \"c\") or equal(ext, \"h\")/equal(ext, \"c\")/|h is no C"
	"Highlight.hiq|s/equal(ext, \"diff\") or equal(ext, \"patch\")/equal(ext, \"diff\")/|patch is no diff"
	"Highlight.hiq|s/                dot := i;/                skip;/|the first dot counts"
)
