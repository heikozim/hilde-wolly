# The mutations of Wolly.Jpeg (JPEG read in Hilde), sourced by
# scripts/mutate.sh and scripts/mutate-target.sh.
mutations+=(
	"Jpeg.hiq|s/        if (data\[0\] \/= (255 : Nat8)) or (data\[1\] \/= (216 : Nat8)) then/        if false then/|any bytes are a JPEG"
	"Jpeg.hiq|s/((width \* height) > maxPixels)/((width * height) >= maxPixels)/|exactly maxPixels pixels are refused"
	"Jpeg.hiq|s/                    if ((marker >= 195) and (marker <= 207)) and (marker \/= 196) then/                    if false then/|an arithmetic frame is skipped, not refused"
	"Jpeg.hiq|s/        if precision \/= 8 then/        if false then/|12-bit samples are read as 8"
	"Jpeg.hiq|s/            if (h > 2) or (v > 2) then/            if false then/|a sampling factor of 3 is read"
	"Jpeg.hiq|s/                    storeNth(\&~huff, (base + mostAt) + l, code);/                    storeNth(\&~huff, (base + mostAt) + l, code + 1);/|the greatest code of a length one too high"
	"Jpeg.hiq|s/                code := code \* 2;/                code := code;/|the codes of the next length not shifted"
	"Jpeg.hiq|s/            return real(v) - real(power(n) - 1);/            return real(v) - real(power(n));/|negative values extended one too low"
	"Jpeg.hiq|s/        let dc: Float64 := nth(\&predictions, c) + difference;/        let dc: Float64 := difference;/|the DC difference taken without its prediction"
	"Jpeg.hiq|s/                        storeNth(\&!predictions, 0, zero);/                        skip;/|the luma prediction kept over a restart"
	"Jpeg.hiq|s/        bits->left := (0 : Index);/        skip;/|the bits before a restart marker read on"
	"Jpeg.hiq|s/                if bitwiseAnd(s, (1 : Index)) = 0 then/                if bitwiseAnd(s, (1 : Index)) = 1 then/|the zigzag diagonals walked the wrong way"
	"Jpeg.hiq|s/                scale := 0.35355339059327373;/                scale := 0.5;/|the DC factor of the inverse DCT without the root of one half"
	"Jpeg.hiq|s/                let blue: Float64 := real(wide(nth(\&bluePlane, i))) - 128.0;/                let blue: Float64 := real(wide(nth(\&redPlane, i))) - 128.0;/|Cr taken for Cb"
	"Jpeg.hiq|s/        let wide2: Bool := h < hMost;/        let wide2: Bool := false;/|chroma of half the width not upsampled across"
	"Jpeg.hiq|s/        let high2: Bool := v < vMost;/        let high2: Bool := false;/|chroma of half the height not upsampled down"
	"Jpeg.hiq|s/        if bitwiseAnd(outRow, (1 : Index)) = 0 then/        if bitwiseAnd(outRow, (1 : Index)) = 1 then/|the row above taken for the lower output row"
	"Jpeg.hiq|s/                            value := (((here \* 3) + columnSum(planes, places, c, i - 1, sy, y, columns, rows)) + 8) \/ 16;/                            value := ((here * 4) + 8) \/ 16;/|the left neighbour left out of an even column"
	"Jpeg.hiq|s/        if height = 0 then/        if false then/|a frame of height 0 is read"
)
