# The mutations of Wolly.Blob, sourced by scripts/mutate.sh and
# scripts/mutate-target.sh.
mutations+=(
	"Blob.hiq|s/constant blobMost: Index := 16777216;/constant blobMost: Index := 4;/|a blob of 12 bytes is too large"
	"Blob.hiq|s/if spanLength(text) \/= (xidBytes \* 2) then/if spanLength(text) \/= xidBytes then/|an xid of 16 digits"
	"Blob.hiq|s/let letter: Bool := (byte >= 97) and (byte <= 102);/let letter: Bool := (byte >= 97) and (byte <= 103);/|a g in an xid"
	"Blob.hiq|s/if slashes \/= 1 then/if slashes = 0 then/|two slashes in a media type"
	"Blob.hiq|s/return (slashAt > 0) and ((slashAt + 1) < size);/return true;/|an empty type or subtype"
	"Blob.hiq|s/((byte = 47) or (byte = 92))/((byte = 0) or (byte = 92))/|a slash in a name"
	"Blob.hiq|s/SELECT xid FROM wolly_blobs WHERE hash = ?/SELECT xid FROM wolly_blobs WHERE hash = ? AND 0/|the same content is kept twice"
	"Blob.hiq|s/DELETE FROM wolly_blob_names WHERE xid = ?/DELETE FROM wolly_blob_names WHERE xid = ? AND 0/|the names stay after a delete"
	"Blob.hiq|s/case sha256(content) of/case sha256(name) of/|the hash is of the name, not the content"
	"Blob.hiq|s/let removed: Bool := blobs > 0;/let removed: Bool := true;/|a delete of nothing says it removed"
	"Blob.hiq|s/if ((size = 0) or (size > blobMost)) or/if (size > blobMost) or/|an empty blob is kept"
)
