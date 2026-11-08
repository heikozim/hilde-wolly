# The mutations of the RGB layer of Wolly.Image for Bunti, sourced by
# scripts/mutate.sh and scripts/mutate-target.sh.
mutations+=(
	"Image.hiq|s/                writeByte(\&!out, source\[at + 2\]);/                writeByte(\&!out, source[at + 1]);/|blue read as green"
	"Image.hiq|s/        case makeImage(width, height, Rgb(), pixels) of/        case makeImage(height, width, Rgb(), pixels) of/|width and height swapped"
)
