# The mutations of Wolly.Chart and of /stats in examples/hello, sourced by
# scripts/mutate.sh.
mutations+=(
	"Chart.hiq|s/        if ((value - (tenths \* tenth)) \* 2) >= tenth then/        if false then/|the tenth is cut, not rounded"
	"Chart.hiq|s/        if value >= million then/        if value > million then/|a million reads as 1000.0 k"
	"Chart.hiq|s/            found := below + ((found - below) \/ 2);/            found := below;/|the median of an even number is the lower middle"
	"Chart.hiq|s/        if value >= most then/        if false then/|a bar above the most passes 100"
	"Chart.hiq|s/            return (difference + (middle \/ 2)) \/ middle;/            return difference \/ middle;/|a change is cut, not rounded"
	"Chart.hiq|s/            return today \* 10;/            return today;/|a median of 0 gives today in ones"
	"examples/hello/Hello.hiq|s/        while (i < length(\&pieces)) and (i < 100) do/        while (i < length(\&pieces)) and (i < 1) do/|\/stats reads only the first count"
)
