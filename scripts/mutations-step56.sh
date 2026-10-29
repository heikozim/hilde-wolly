# The mutations of Wolly.Bunti (the format), sourced by
# scripts/mutate.sh and scripts/mutate-target.sh.
mutations+=(
	"Bunti.hiq|s/            return 'C';/            return 'G';/|C written as G"
	"Bunti.hiq|s/            byte := (byte \* 4) + base;/            byte := (byte * 4) + (3 - base);/|bases read the other way round"
	"Bunti.hiq|s/        return 154;/        return 152;/|level H with two parity bytes less"
	"Bunti.hiq|s/            parity := parity + 1;/            parity := parity;/|an odd number of parity bytes"
	"Bunti.hiq|s/                return headerAt(sequence, length(sequence) - headerCells, size);/                return None();/|the second copy of the header is not read"
	"Bunti.hiq|s/                        if crc32(asSpan(\&text)) = header.crc then/                        if true then/|the CRC-32 is not checked"
	"Bunti.hiq|s/        if ((x + 6) >= size) and ((y + 6) >= size) then/        if ((x + 5) >= size) and ((y + 5) >= size) then/|the separator of the corner pattern holds data"
	"Bunti.hiq|s/            return size - 9;/            return size - 10;/|the references of the bottom left one row higher"
	"Bunti.hiq|s/                insertBack(\&!out, nth(\&parities, (block \* parity) + pc));/                insertBack(\&!out, nth(\&parities, (pc * blocks) + block));/|the parity bytes taken from the wrong blocks"
	"Bunti.hiq|s/            return 170;/            return 171;/|A drawn in another green"
)
