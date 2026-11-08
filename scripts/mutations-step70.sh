# The mutations of Wolly.Vault.convertVault, sourced by scripts/mutate.sh and scripts/mutate-target.sh.
# Not mutated: the comparison of a value read back, which a correct Standard.Vault never fails (no test can see it).
mutations+=(
	"Vault.hiq|s/        return (spanLength(name) > 0) and ((name\[0\] < '0') or (name\[0\] > '9'));/        return spanLength(name) > 0;/|a name that starts with a digit is carried, not refused"
	"Vault.hiq|s/        if not allOpen(vaultPath, keyPath, names) then/        if false then/|a wrong old key is found only after the new files are written"
	"Vault.hiq|s/                                count := count + 1;/                                skip;/|the secrets carried over are not counted"
	"Vault.hiq|s/                writeString(\&~refused, name);/                skip;/|a refused name is not named"
	"Vault.hiq|s/                let there: Either\[VaultError, Unit\] := Right(right => nil);/                let there: Either[VaultError, Unit] := createPepper(pepperPath);/|a pepper that is there is written anew"
	"Vault.hiq|s/                        return openVault(envPath, pepperPath, keyName);/                        return Left(left => missing);/|a missing key line is not made"
)
