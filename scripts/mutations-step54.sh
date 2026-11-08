# The mutations of Wolly.BuntiRs (Reed-Solomon over GF(256) for Bunti), sourced by
# scripts/mutate.sh and scripts/mutate-target.sh.
mutations+=(
	"BuntiRs.hiq|s/                x := bitwiseXor(x, fieldPolynomial);/                x := x - 256;/|the field without its polynomial"
	"BuntiRs.hiq|s/            let lowest: Index := mul(tables, nth(\&g, 0), root);/            let lowest: Index := nth(\&g, 0);/|the generator without its lowest term"
	"BuntiRs.hiq|s/            let inverse: Index := power(tables, (255 : Index) - exponent);/            let inverse: Index := power(tables, exponent);/|the Chien search looks at the wrong places"
	"BuntiRs.hiq|s/mul(tables, power(tables, exponent), divide(/mul(tables, 1, divide(/|Forney without the factor X"
	"BuntiRs.hiq|s/            undo(\&~block, \&positions, \&olds);/            skip;/|a refused block is left changed"
	"BuntiRs.hiq|s/                    errors := (n + 1) - errors;/                    errors := n - errors;/|Berlekamp-Massey counts one error less"
	"BuntiRs.hiq|s/                    shifted := nth(powers, nth(logs, value) + i);/                    shifted := nth(powers, (nth(logs, value) + i) + 1);/|the syndromes at the wrong roots"
	"BuntiRs.hiq|s/                    if nth(g, at) \/= 0 then/                    if false then/|the encoder drops the middle terms of the generator"
	"BuntiRs.hiq|s/            if factor = 0 then/            if false then/|the encoder takes a zero factor for a one"
	"BuntiRs.hiq|s/        if (n > blockMost) or (n <= parity) then/        if n > blockMost then/|a block no longer than its parity is read"
)
