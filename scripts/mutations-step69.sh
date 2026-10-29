# The mutations of Wolly.LogStore and Wolly.Query on PostgreSQL (the full-text index of PostgreSQL), sourced by
# scripts/mutate-target.sh: "pg: " makes the unit tests on PostgreSQL the only checks of a mutation.
mutations+=(
	"LogStore.hiq|s/plainto_tsquery('wolly'::regconfig, ?) AS q WHERE words @@ q ORDER BY/plainto_tsquery('wolly'::regconfig, ?) AS q WHERE true ORDER BY/|pg: a search finds every line"
	"LogStore.hiq|s/'StartSel=' || chr(1)/'StartSel=' || chr(3)/|pg: the words found are not marked"
	"LogStore.hiq|s/                writeString(\&!out, \"\&lt;\");/                writeByte(\&!out, byte);/|pg: a less-than sign of a line reaches the page as it is"
	"LogStore.hiq|s/case execute(\&~db, dropLine, withInt64(noValues(), id)) of/case execute(\&~db, dropLine, withInt64(noValues(), 0)) of/|pg: a pruned line stays"
	"LogStore.hiq|s/                    return changed(set > 0);/                    return changed(true);/|pg: a level of a line that is not there is said to be set"
	"LogStore.hiq|s/words tsvector GENERATED ALWAYS AS (setweight(to_tsvector('wolly'::regconfig, host || ' ' || source || ' ' || level), 'A') || /words tsvector GENERATED ALWAYS AS (/|pg: the host, source and level of a line are not searched"
	"LogStore.hiq|s/        if (first + 16) < words then/        if false then/|pg: a long line is not cut after the words found"
	"LogStore.hiq|s/        if first > 0 then/        if false then/|pg: a cut before the words found is not shown"
	"LogStore.hiq|s/RETURNING id\";/RETURNING 0\";/|pg: every line is kept under the number 0"
	"Query.hiq|s/WHERE line_words @@ phraseto_tsquery/WHERE line_words @@ plainto_tsquery/|pg: the words of a phrase in any order"
	"Query.hiq|s/substr(convert_to(lower(host), 'UTF8'), 1, CAST(? AS INTEGER)) = convert_to(lower(?), 'UTF8')/substr(convert_to(host, 'UTF8'), 1, CAST(? AS INTEGER)) = convert_to(lower(?), 'UTF8')/|pg: a prefix of a host in capitals is not found"
	"Query.hiq|s/WHERE at >= ? AND at <= ? AND lower(host) = lower(?)\";/WHERE at >= ? AND at <= ? AND host = ?\";/|pg: a host in capitals is not found"
	"Query.hiq|s/WHERE node = ? INTERSECT SELECT id FROM pg_temp/WHERE node = ? UNION SELECT id FROM pg_temp/|pg: and is or"
	"Query.hiq|s/WHERE node = ? UNION SELECT id FROM pg_temp/WHERE node = ? INTERSECT SELECT id FROM pg_temp/|pg: or is and"
	"Query.hiq|s/AND at <= ? EXCEPT SELECT id FROM pg_temp/AND at <= ? INTERSECT SELECT id FROM pg_temp/|pg: not keeps what it should take out"
	"Query.hiq|s/WHERE q.node = ? ORDER BY l.at DESC, l.id DESC LIMIT ? OFFSET ?\";/WHERE q.node = ? ORDER BY l.at ASC, l.id DESC LIMIT ? OFFSET ?\";/|pg: the oldest lines first"
	"Query.hiq|s/\"DELETE FROM pg_temp.wolly_query_sets\";/\"DELETE FROM pg_temp.wolly_query_sets WHERE false\";/|pg: the sets of a query are left for the next"
)
