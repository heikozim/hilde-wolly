# The mutations of Wolly.Field and of /check in examples/hello, sourced by
# scripts/mutate.sh.
mutations+=(
	"Field.hiq|s/        if spanLength(value) > most then/        if false then/|a value longer than allowed passes"
	"Field.hiq|s/if (local\[0\] = '.') or (local\[size - 1\] = '.') then/if false then/|a local part may start or end with a dot"
	"Field.hiq|s/if ((byte = '.') and ((i + 1) < size)) and (local\[i + 1\] = '.') then/if false then/|two dots in a row pass"
	"Field.hiq|s/        if last and (size < 2) then/        if false then/|a last label of one letter passes"
	"Field.hiq|s/        return labels >= 2;/        return labels >= 1;/|a domain of one label passes"
	"Field.hiq|s/(divides(year, 4) and (not divides(year, 100))) or divides(year, 400)/divides(year, 4)/|1900 is a leap year"
	"Field.hiq|s/            return 30;/            return 31;/|April has 31 days"
	"Field.hiq|s/        if (year < 1) or/        if (year < 0) or/|year 0 passes"
	"examples/hello/Hello.hiq|s/                    fits := isDate(asSpan(\&given));/                    fits := true;/|/check takes every date"
)
