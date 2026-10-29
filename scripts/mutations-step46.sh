# The mutations of Wolly.LogStore, sourced by scripts/mutate.sh and
# scripts/mutate-target.sh.
mutations+=(
	"LogStore.hiq|s/constant lineMost: Index := 16384;/constant lineMost: Index := 4;/|a line is cut after 4 bytes"
	"LogStore.hiq|s/if (level\[i\] < 97) or (level\[i\] > 122) then/if (level[i] < 65) or (level[i] > 122) then/|upper case in a level"
	"LogStore.hiq|s/if (source\[i\] < 32) or (source\[i\] = 127) then/if (source[i] < 9) or (source[i] = 127) then/|a line end in a source"
	"LogStore.hiq|s/if ((byte < 32) and (byte \/= 9)) or (byte = 127) then/if false then/|control bytes are kept"
	"LogStore.hiq|s/if ((not validHostname(host)) or/if ((false) or/|a line without a host name is kept"
	"LogStore.hiq|s/or ((not isLevel(level)) or (at < 0)) then/or ((not isLevel(level)) or false) then/|a line with a time below 0 is kept"
	"LogStore.hiq|s/\"<mark>\", \"<\/mark>\"/\"<b>\", \"<\/b>\"/|the words found are not marked"
	"LogStore.hiq|s/writeByte(\&!out, 9);/writeByte(\&!out, 32);/|the fields are not separated by tabs"
	"LogStore.hiq|s/WHERE at < ? ORDER BY at, id LIMIT ?/WHERE at <= ? ORDER BY at, id LIMIT ?/|a prune takes the line at its time"
	"LogStore.hiq|s/removeDocument(\&~db, asSpan(\&key));/removeDocument(\&~db, \"0\");/|a pruned line stays in the full-text index"
	# The index written through Standard.Search, in the caller's transaction.
	"LogStore.hiq|s/        writeString(\&!title, level);/        writeString(\&!title, \"info\");/|the title of a line without its level"
	"LogStore.hiq|s/titleOf(columnText(\&cursor, 0), columnText(\&cursor, 1), level)/titleOf(columnText(\&cursor, 0), columnText(\&cursor, 1), \"info\")/|a new level not in the title"
	"LogStore.hiq|s/withInt64(withText(noValues(), level), id)) of/withInt64(withText(noValues(), \"info\"), id)) of/|a new level not in the table"
	"LogStore.hiq|s/        if not isLevel(level) then/        if false then/|a level that is none is set"
	"LogStore.hiq|s/                    return changed(false);/                    return changed(true);/|no line is said to be changed"
	"LogStore.hiq|s/removeSounds(\&~db, asSpan(\&key));/removeSounds(\&~db, \"0\");/|a pruned line stays in the sound index"
	"LogStore.hiq|s/constant pruneMost: Int64 := 1000;/constant pruneMost: Int64 := 1;/|a prune takes one line"
)
