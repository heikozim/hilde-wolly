# The mutations of Wolly.BuntiDna (mode 2 of Bunti), sourced by
# scripts/mutate.sh and scripts/mutate-target.sh.
mutations+=(
	"BuntiDna.hiq|s/    constant runMost: Index := 3;/    constant runMost: Index := 4;/|a run of four equal bases is let through"
	"BuntiDna.hiq|s/((gc \* 100) >= (size \* 45))/((gc * 100) >= (size * 40))/|40 percent G and C is let through"
	"BuntiDna.hiq|s/        if b = c then/        if false then/|the first copy of the seed wins against the two others"
	"BuntiDna.hiq|s/            if j = half then/            if j = (half + 1) then/|the middle copy of the seed one byte late"
	"BuntiDna.hiq|s/    constant bytesOfSegment: Index := 32;/    constant bytesOfSegment: Index := 16;/|segments of 16 bytes"
	"BuntiDna.hiq|s/            putByte(\&!out, bitwiseXor(wide(nth(codewords, first + j)), high(state)));/            putByte(\&!out, wide(nth(codewords, first + j)));/|the bytes not scrambled"
	"BuntiDna.hiq|s/            while (seed < 256) and (not placed) do/            while (seed < 1) and (not placed) do/|only seed 0 is tried"
	"BuntiDna.hiq|s/            let run: Index := tailRun(\&out);/            let run: Index := 0;/|a run is not counted on from the segment before"
)
