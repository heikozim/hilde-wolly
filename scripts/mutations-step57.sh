# The mutations of Wolly.BuntiScan (Bunti read from pixels), sourced by
# scripts/mutate.sh and scripts/mutate-target.sh.
mutations+=(
	"BuntiScan.hiq|s/        return topAt(pixels, width, x, y) <= darkMost;/        return topAt(pixels, width, x, y) > darkMost;/|dark and light the other way round"
	"BuntiScan.hiq|s/        let slack: Float64 := cell \/ 2.0;/        let slack: Float64 := cell \/ 8.0;/|a pattern must be almost exact"
	"BuntiScan.hiq|s/        if turn > 0.0 then/        if turn < 0.0 then/|top right and bottom left swapped"
	"BuntiScan.hiq|s/            if c.corner and fits then/            if false then/|the corner pattern is never used"
	"BuntiScan.hiq|s/        return narrow(best - ((best \/ 4) \* 4));/        return narrow(best \/ 4);/|a cell gets the number of its finder, not its base"
	"BuntiScan.hiq|s/project(t, fl(x) + 0.5, fl(y) + 0.5)/project(t, fl(x), fl(y))/|a cell sampled at its corner"
	"BuntiScan.hiq|s/                        if buntiHeaderReads(\&code) then/                        if true then/|the first size tried is taken"
	"BuntiScan.hiq|s/        if ((width < 21) or (height < 21)) or (spanLength(pixels) \/= (count \* 3)) then/        if (width < 21) or (height < 21) then/|pixels of the wrong length are read"
)
