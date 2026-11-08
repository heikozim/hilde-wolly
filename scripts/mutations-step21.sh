# The mutations of Wolly.Edges and of its commands in examples/login,
# sourced by scripts/mutate.sh.
mutations+=(
	"Edges.hiq|s/ UNION SELECT e.target FROM/ UNION ALL SELECT e.target FROM/|the recursion downwards walks a node again and again"
	"Edges.hiq|s/JOIN r ON e.target = r.node/JOIN r ON e.source = r.node/|the ancestors are searched downwards"
	"Edges.hiq|s/        if weighted then/        if false then/|the lightest route is the one of fewest edges"
	"Edges.hiq|s/DO UPDATE SET weight = excluded.weight/DO NOTHING/|a second add keeps the old weight"
	"Edges.hiq|s/(spanLength(name) > 128)/(spanLength(name) > 129)/|a node name of 129 bytes is taken"
	"Edges.hiq|s/or (byte = '_');/or (byte = '_')) or (byte = ' ');/;s/let mark: Bool := (((/let mark: Bool := ((((/|a space is part of a node name"
	"Edges.hiq|s/            if i = 0 then/            if false then/|a route lacks its first node"
	"examples/login/Login.hiq|s/return showRoute(nthArgument(2), nthArgument(3), nthArgument(4));/return showRoute(nthArgument(2), nthArgument(4), nthArgument(3));/|login route swaps its start and its goal"
)
