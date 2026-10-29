# The mutations of Wolly.Svg, sourced by scripts/mutate.sh and
# scripts/mutate-target.sh.
mutations+=(
	"Svg.hiq|s/constant pointsMost: Index := 1000;/constant pointsMost: Index := 1001;/|more than 1000 points are drawn"
	"Svg.hiq|s/constant labelsMost: Index := 31;/constant labelsMost: Index := 32;/|32 bars get labels"
	"Svg.hiq|s/writeString(\\&~out, asSpan(\\&escaped));/writeString(\\&~out, text);/|text goes into the SVG unescaped"
	"Svg.hiq|s/y := baseline - ((plotHeight \* barHeight(v - lowest, highest - lowest)) \/ 100);/y := baseline - ((plotHeight * barHeight(v, highest)) \/ 100);/|the line is not scaled from the lowest value"
	"Svg.hiq|s/if highest > lowest then/if true then/|equal values fall to the baseline"
	"Svg.hiq|s/let x: Int64 := left + ((plotWidth \* k) \/ last);/let x: Int64 := left + (plotWidth * k);/|the points run off the chart"
	"Svg.hiq|s/if v < lowest then/if v > lowest then/|the lowest value is the highest"
	"Svg.hiq|s/if value < 0 then/if false then/|a value below 0 is drawn below the baseline"
	"Svg.hiq|s/let x: Int64 := (left + (k \* slot)) + ((slot - width) \/ 2);/let x: Int64 := left + (k * slot);/|bars are not centred in their slot"
	"Svg.hiq|s/if n = 1 then/if false then/|one value is no dot"
	"Svg.hiq|s/size := zero - tenths;/size := tenths;/|a fall is shown with a negative size"
	"Svg.hiq|s/writeNumber(\&!out, size \/ 10);/writeNumber(\&!out, size);/|the tenths are shown as whole numbers"
	"Svg.hiq|s/if tenths \/= 0 then/if true then/|no change shows a change"
	"Svg.hiq|s/if (i = size) or (labels\[i\] = 10) then/if i = size then/|all labels are one"
)
