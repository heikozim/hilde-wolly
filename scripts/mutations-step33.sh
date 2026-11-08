# The mutations of Wolly.Phonetic and of /sound in examples/hello, sourced
# by scripts/mutate.sh.
mutations+=(
	"Phonetic.hiq|s/                writeByte(\&!out, byte + 32);/                writeByte(\&!out, byte);/|capitals are not read as letters"
	"Phonetic.hiq|s/        if low <= 5 then/        if low <= 4 then/|Å is no a"
	"Phonetic.hiq|s/            return 's';/            return 0;/|ß is no s"
	"Phonetic.hiq|s/            if after = 'h' then/            if false then/|ph is coded as p"
	"Phonetic.hiq|s/            if isIn(after, \"csz\") then/            if isIn(after, \"cs\") then/|t before z is coded as t"
	"Phonetic.hiq|s/            if isIn(after, \"ahkloqrux\") then/            if isIn(after, \"akloqrux\") then/|c at the start before h is 8"
	"Phonetic.hiq|s/        if (before = 's') or (before = 'z') then/        if false then/|c after s is coded by what follows"
	"Phonetic.hiq|s/            if (i = 0) or (digit \/= previous) then/            if true then/|a digit repeated is kept"
	"Phonetic.hiq|s/                if (digit \/= '0') or (i = 0) then/                if digit \/= '0' then/|a leading 0 is dropped"
	"Phonetic.hiq|s/                if (byte \/= 'h') and (byte \/= 'w') then/                if true then/|h parts two letters of one code"
	"Phonetic.hiq|s/        var last: Nat8 := soundexDigit(letters\[0\]);/        var last: Nat8 := 0;/|the first letter does not count for the second"
	"examples/hello/Hello.hiq|s/                if spanLength(asSpan(\&name)) > 100 then/                if spanLength(asSpan(\&name)) > 101 then/|a name of 101 bytes is taken"
)
