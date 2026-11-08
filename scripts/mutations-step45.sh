# The mutations of Wolly.LogTail, sourced by scripts/mutate.sh and
# scripts/mutate-target.sh.
mutations+=(
	"LogTail.hiq|s/constant tailMost: Int64 := 1048576;/constant tailMost: Int64 := 8;/|a call reads 8 bytes"
	"LogTail.hiq|s/constant firstMost: Int64 := 4096;/constant firstMost: Int64 := 4;/|a fingerprint of 4 bytes"
	"LogTail.hiq|s/if origin > size then/if false then/|a cut file is not read from its start"
	"LogTail.hiq|s/if equal(columnText(\&cursor, 0), print) then/if true then/|a rotated file goes on at the old offset"
	"LogTail.hiq|s/if (take = 0) and (count = tailMost) then/if false then/|an endless line stops the file"
	"LogTail.hiq|s/            if text\[stop - 1\] = 10 then/            if text[stop - 1] = 13 then/|lines end at CR"
	"LogTail.hiq|s/            if text\[i\] = 10 then/            if false then/|no first line is ever whole"
	"LogTail.hiq|s/withText(noValues(), path), print), origin + taken)/withText(noValues(), path), print), origin)/|the offset does not move"
	"LogTail.hiq|s/if not sameKind(status.kind, kindRegular) then/if false then/|a directory is read"
	"LogTail.hiq|s/if (spanLength(columnText(\&cursor, 2)) = 0) or equal(columnText(\&cursor, 2), fileId) then/if true then/|a rotated file with the same first line goes on at the old offset"
	"LogTail.hiq|s/if (spanLength(columnText(\&cursor, 2)) = 0) or equal(columnText(\&cursor, 2), fileId) then/if spanLength(columnText(\&cursor, 2)) = 0 then/|a file once read is read from its start each time"
	"LogTail.hiq|s/                return addFileIdColumn(\&~db);/                return None();/|a table of before gets no column"
	"LogTail.hiq|s/if columns > 0 then/if true then/|a table of before gets no column on SQLite"
	"LogTail.hiq|s/ADD COLUMN IF NOT EXISTS file_id/ADD COLUMN file_id/|pg: a second prepare fails on a table that has the column"
	"LogTail.hiq|s/        let inode: String := formatNat(status.inode);/        let inode: String := formatNat(status.size);/|the size stands for the inode"
)
