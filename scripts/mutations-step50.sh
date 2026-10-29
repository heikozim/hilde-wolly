# The mutations of Wolly.Dashboard with htmx (liveDashboardPage,
# livePanelFragment), sourced by scripts/mutate.sh and
# scripts/mutate-target.sh.
mutations+=(
	"Dashboard.hiq|s/constant livePathMost: Index := 128;/constant livePathMost: Index := 1;/|a path of two bytes is too long"
	"Dashboard.hiq|s/        if path\[0\] \/= '\/' then/        if false then/|a path without its slash first"
	"Dashboard.hiq|s/            if ((byte = '.') or (byte = '\/')) and (path\[i - 1\] = byte) then/            if false then/|two dots or two slashes in a row"
	"Dashboard.hiq|s/            let mark: Bool := ((byte = '-') or (byte = '_')) or ((byte = '.') or (byte = '\/'));/            let mark: Bool := true;/|any byte in a path"
	"Dashboard.hiq|s/        if live.base\[spanLength(live.base) - 1\] \/= '\/' then/        if false then/|a base without its slash at the end"
	"Dashboard.hiq|s/        if live.script\[spanLength(live.script) - 1\] = '\/' then/        if false then/|a script that is a directory"
	"Dashboard.hiq|s/constant everyLeast: Int64 := 5;/constant everyLeast: Int64 := 4;/|a panel asked for every 4 seconds"
	"Dashboard.hiq|s/constant everyMost: Int64 := 3600;/constant everyMost: Int64 := 3601;/|a panel asked for every 3601 seconds"
	"Dashboard.hiq|s/        writeString(\&!url, panel.name);/        skip;/|every panel asks for the base alone"
	"Dashboard.hiq|s/        return fragmentWith(\&~db, panel, now, finalize(url), live.every);/        return fragmentWith(\&~db, panel, now, finalize(url), 0);/|a live panel asked for every 0 seconds"
	"Dashboard.hiq|s/            return livePanelFragment(\&~db, panel, now, how);/            return panelFragment(\&~db, panel, now);/|the panels of a live page ask for nothing"
	"Dashboard.hiq|s/            return fromSpan(how.script);/            return fromSpan(\"\");/|a live page without its script"
	"Dashboard.hiq|s/                    quiet := how.every;/                    skip;/|a live page without its refresh for no script"
)
