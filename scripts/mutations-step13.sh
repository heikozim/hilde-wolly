# The mutations of Wolly.Page, sourced by scripts/mutate.sh.
mutations+=(
	'Page.hiq|s/if (pages \* each) < total then/if (pages * each) <= total then/|a full last page gets an empty page after it'
	'Page.hiq|s/if current > pages then/if current > (pages + 1) then/|a page past the last is taken'
	'Page.hiq|s/if each > largestSize() then/if false then/|any size is taken'
	'Page.hiq|s/return (page.current - 1) \* page.size;/return page.current * page.size;/|the offset is one page too far'
	'Page.hiq|s/                if number = 0 then/                if number = 7 then/|page 0 is taken as a number'
	'examples/hello/Hello.hiq|s/makePage(requested, numberCount, numbersAPage)/makePage(1, numberCount, numbersAPage)/|the page of the query is ignored'
)
