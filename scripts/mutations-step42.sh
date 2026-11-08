# The mutations of Wolly.Doc and of the backslash escapes of Wolly.Markdown,
# sourced by scripts/mutate.sh and scripts/mutate-target.sh.
mutations+=(
	"Markdown.hiq|s/if (byte = 92) and ((i + 1) < size) then/if false then/|a backslash escapes nothing"
	"Markdown.hiq|s/let low: Bool := (byte >= 33) and (byte <= 47);/let low: Bool := (byte >= 33) and (byte <= 41);/|a star is no punctuation"
	"Doc.hiq|s/constant htmlMost: Index := 1048576;/constant htmlMost: Index := 1048577;/|a limit one byte off"
	"Doc.hiq|s/(((byte = '\*') or (byte = '\[')) or (byte = '\]'))/(((byte = '#') or (byte = '[')) or (byte = ']'))/|a star in text is read as emphasis"
	"Doc.hiq|s/return ((byte = '#') or (byte = '>')) or ((byte = '-') or (byte = '+'));/return ((byte = '!') or (byte = '>')) or ((byte = '-') or (byte = '+'));/|a hash first makes a heading"
	"Doc.hiq|s/ or (digits and (byte = '.'));/ or false;/|a number with a dot first makes a list"
	"Doc.hiq|s/(marksAnywhere(byte) or (atStart and marksAtStart(byte)))/(marksAnywhere(byte) or marksAtStart(byte))/|marks inside a line are escaped"
	"Doc.hiq|s/and (not contains(asSpan(\&href), \")\"))/and true/|a target with a parenthesis cuts the link"
	"Doc.hiq|s/return (equal(name, \"script\") or equal(name, \"style\"))/return (equal(name, \"noscript\") or equal(name, \"style\"))/|a script gives its text"
	"Doc.hiq|s/return equal(tokenText(doc, n + 1), tokenText(doc, n));/return false;/|an empty strong gives four stars"
	"Doc.hiq|s/if contains(tokenText(doc, i), /if false and contains(tokenText(doc, i), /|code with a backtick stays code"
	"Doc.hiq|s/if (byte = 10) or (pending = aLine) then/if pending = aLine then/|a paragraph of two lines becomes one"
	"Doc.hiq|s/writeString(\&~out, \"> \");/writeString(\&~out, \"\");/|a quote loses its marks"
	"Doc.hiq|s/writeString(\&~out, \"\\\\n\\\\n\");/writeString(\&~out, \"\\\\n\");/|blocks run together"
	"Doc.hiq|s/return fromSpan(substring(text, 0, stop + 1));/return fromSpan(substring(text, 0, stop));/|no line end at the end"
	"Doc.hiq|s/number := number + 1;/number := number;/|every item is number 1"
)
