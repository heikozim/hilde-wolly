# The mutations of Wolly.Gif (GIF read in Hilde), sourced by
# scripts/mutate.sh and scripts/mutate-target.sh.
mutations+=(
	"Gif.hiq|s/        let version: Bool := ((data\[4\] = '7') or (data\[4\] = '9')) and (data\[5\] = 'a');/        let version: Bool := true;/|any version is a GIF"
	"Gif.hiq|s/((screenWidth \* screenHeight) > maxPixels)/((screenWidth * screenHeight) >= maxPixels)/|exactly maxPixels pixels are refused"
	"Gif.hiq|s/                                if (next = power(width)) and (width < 12) then/                                if (next = (power(width) + 1)) and (width < 12) then/|the codes widen one entry late"
	"Gif.hiq|s/                            if walk = next then/                            if false then/|the code not yet in the table is not taken"
	"Gif.hiq|s/                                insertBack(\&!stack, first);/                                skip;/|KwKwK without its first byte"
	"Gif.hiq|s/            if code = clear then/            if false then/|a clear code is a colour"
	"Gif.hiq|s/                if bitwiseAnd(byte \/ power(shift), (1 : Index)) = 1 then/                if bitwiseAnd(byte \/ power(shift), (1 : Index)) = 0 then/|the bits of a code read inverted"
	"Gif.hiq|s/            return ((r - pass1) \* 8) + 4;/            return ((r - pass1) * 8) + 2;/|the second pass of an interlaced picture in the wrong rows"
	"Gif.hiq|s/        let interlaced: Bool := bitwiseAnd(frameFlags, (64 : Index)) = 64;/        let interlaced: Bool := false;/|an interlaced picture is read in coded order"
	"Gif.hiq|s/            globalSize := power(bitwiseAnd(flags, (7 : Index)) + 1);/            globalSize := power(bitwiseAnd(flags, (7 : Index)));/|the global table half its size"
	"Gif.hiq|s/        if (screenWidth = 0) or (screenHeight = 0) then/        if false then/|a screen 0 wide is read"
)
