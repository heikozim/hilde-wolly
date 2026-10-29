# The mutations of Wolly.Image (PNG vacuumed), sourced by
# scripts/mutate.sh and scripts/mutate-target.sh.
mutations+=(
	"Image.hiq|s/            h := (h \* boxWidth) \/ w;/            h := h;/|the height is not scaled with the width"
	"Image.hiq|s/^            h := boxHeight;\$/            h := h;/|a tall image keeps its height"
	"Image.hiq|s/            w := (w \* boxHeight) \/ h;/            w := w;/|the width is not scaled with the height"
	"Image.hiq|s/writeByte(\&!out, narrow(sum \/ count));/writeByte(\&!out, narrow(sum \/ (count + 1)));/|the mean divides by one more"
	"Image.hiq|s/^                        y := y + 1;\$/                        y := y + 2;/|every other row of the box is skipped"
	"Image.hiq|s/let tooWide: Bool := (imageWidth(\&image) > sideMost) or (imageHeight(\&image) > sideMost);/let tooWide: Bool := false;/|any side is read"
	"Image.hiq|s/            boxWidth := (w \* 3) \/ 4;/            boxWidth := w;/;s/            boxHeight := (h \* 3) \/ 4;/            boxHeight := h;/|a PNG too large is not scaled further"
	"Image.hiq|s/                        return Left(left => ImageTooLarge());/                        return Left(left => NotAnImage());/|too many pixels counts as no image"
	"Image.hiq|s/        if side > sideMost then/        if false then/|a side above 16000 multiplied as it is"
)
