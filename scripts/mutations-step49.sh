# The mutations of Wolly.Dashboard, sourced by scripts/mutate.sh and
# scripts/mutate-target.sh.
mutations+=(
	"Dashboard.hiq|s/constant panelsMost: Index := 32;/constant panelsMost: Index := 33;/|33 panels on a page"
	"Dashboard.hiq|s/constant nameMost: Index := 32;/constant nameMost: Index := 33;/|a panel name of 33 bytes"
	"Dashboard.hiq|s/or (byte = '-'));/or false);/|no hyphen in a panel name"
	"Dashboard.hiq|s/            if (title\[i\] < 32) or (title\[i\] = 127) then/            if false then/|a line end in a title"
	"Dashboard.hiq|s/        if not isMetricName(panel.metric) then/        if false then/|a panel of no metric"
	"Dashboard.hiq|s/constant stepLeast: Int64 := 60;/constant stepLeast: Int64 := 59;/|buckets of 59 seconds"
	"Dashboard.hiq|s/constant stepMost: Int64 := 31622400;/constant stepMost: Int64 := 31622401;/|buckets over 366 days"
	"Dashboard.hiq|s/constant bucketsLeast: Index := 2;/constant bucketsLeast: Index := 1;/|a chart of one bucket"
	"Dashboard.hiq|s/constant bucketsMost: Index := 1000;/constant bucketsMost: Index := 1001;/|1001 buckets"
	"Dashboard.hiq|s/                if equal(other.name, panel.name) then/                if false then/|a panel name twice"
	"Dashboard.hiq|s/        return (slots - buckets) \* step;/        return ((slots - buckets) + 1) * step;/|the buckets end one before the bucket of now"
	"Dashboard.hiq|s/                    if step < dayLength then/                    if false then/|hours labelled as days"
	"Dashboard.hiq|s/        return tileWithChange(title, last, before);/        return tileWithChange(title, before, last);/|a change the wrong way round"
	"Dashboard.hiq|s/                let pair: Index := 2;/                let pair: Index := 3;/|a change of three buckets"
	"Dashboard.hiq|s/        if not validPanels(panels) then/        if false then/|a page of panels that are not checked"
	"Dashboard.hiq|s/seconds => now, nanos => 0), 0) of/seconds => 0, nanos => 0), 0) of/|the page shows another time"
	"Dashboard.hiq|s/                return \"line\";/                return \"tile\";/|a line called a tile"
	"Dashboard.hiq|s/        return sheet;/        return \"\";/|no style sheet"
)
