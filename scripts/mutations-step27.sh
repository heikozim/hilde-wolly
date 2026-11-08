# The mutations of Wolly.Feed and of /feed.atom in examples/hello, sourced
# by scripts/mutate.sh.
mutations+=(
	"Feed.hiq|s/                writeString(\&~out, \"\&lt;\");/                writeByte(\&~out, byte);/|< is written into the XML as it is"
	"Feed.hiq|s/            if byte = '\&' then/            if false then/|\& is written into the XML as it is"
	"Feed.hiq|s/        if isSafeLink(link) then/        if true then/|an unsafe link is written"
	"Feed.hiq|s/case formatRfc3339(at, 0) of/case formatRfc3339(at, 3600) of/|the times are not in UTC"
	"Feed.hiq|s/        element(\&~out, \"summary\", summary);//|an entry has no summary"
	"examples/hello/Hello.hiq|s/beginFeed(\&!out, \"https:\/\/hello.example\/\", \"Hello \& news\"/beginFeed(\&!out, \"https:\/\/hello.example\/\", \"Hello news\"/|the feed has another title"
)
