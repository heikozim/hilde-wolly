# The mutations of Wolly.Markdown and of /markdown in examples/hello,
# sourced by scripts/mutate.sh.  Most of them open a way for a script.
mutations+=(
	"Markdown.hiq|s/                writeString(\&~out, \"\&lt;\");/                writeByte(\&~out, byte);/|< is written as it is"
	"Markdown.hiq|s/if byte = 39 then/if false then/|an apostrophe is written as it is"
	"Markdown.hiq|s/        if not ((scheme or path) or anchor) then/        if false then/|a link of any scheme is made"
	"Markdown.hiq|s/let path: Bool := (url\[0\] = '\/') and ((size = 1) or (url\[1\] \/= '\/'));/let path: Bool := url[0] = '\/';/|a link to \/\/another.host is made"
	"Markdown.hiq|s/            if bad then/            if false then/|a quote or a space in a URL passes"
	"Markdown.hiq|s/                            writeEscaped(\&~out, url);/                            writeString(\&~out, url);/|the URL is not escaped for the attribute"
	"Markdown.hiq|s/                if (close < size) and (close > (i + 2)) then/                if close < size then/|an empty strong is made"
	"Markdown.hiq|s/        if ((level >= 1) and (level <= 6))/        if ((level >= 1) and (level <= 7))/|a heading of a seventh level"
	"examples/hello/Hello.hiq|s/\"Content-Security-Policy\", \"default-src 'none'\"/\"X-Policy\", \"default-src 'none'\"/|the page of \/markdown may run scripts"
)
