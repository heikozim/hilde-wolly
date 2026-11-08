# The mutations of the Bunti page of examples/hello (GET /bunti), sourced by
# scripts/mutate.sh and scripts/mutate-target.sh.
mutations+=(
	"examples/hello/Hello.hiq|s/case encodeBunti(asSpan(\&text), Plain(), LevelM()) of/case encodeBunti(\"Wolly\", Plain(), LevelM()) of/|the page ignores its text"
	"examples/hello/Hello.hiq|s/let shown: String := escapeCode(text);/let shown: String := fromSpan(text);/|the text is not escaped"
	"examples/hello/Hello.hiq|s/img-src data:/img-src */|images from anywhere"
	"examples/hello/Hello.hiq|s/readBack := equal(asSpan(\&payload), text);/readBack := false;/|the read back is never seen"
	"examples/hello/Hello.hiq|s/let scale: Index := 8;/let scale: Index := 4;/|4 pixels a cell"
	"examples/hello/Hello.hiq|s#pattern => \"/bunti\"#pattern => \"/bunti/\"#|the page is not at /bunti"
)
