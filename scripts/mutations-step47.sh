# The mutations of Wolly.Vault, sourced by scripts/mutate.sh and
# scripts/mutate-target.sh.
mutations+=(
	"Vault.hiq|s/constant secretMost: Index := 4096;/constant secretMost: Index := 4097;/|a secret of 4097 bytes"
	"Vault.hiq|s/constant purpose: Span\[Nat8, Static\] := \"wolly-vault\";/constant purpose: Span[Nat8, Static] := \"wolly-vaulx\";/|another purpose: the format changes"
	"Vault.hiq|s/let upper: Bool := (byte >= 65) and (byte <= 90);/let upper: Bool := (byte >= 65) and (byte <= 122);/|lower case in a name"
	"Vault.hiq|s/openValue(key, purpose, asSpan(\&sealed), name)/openValue(key, purpose, asSpan(\&sealed), \"\")/|a value is not bound to its name"
	"Vault.hiq|s/case sealValue(key, purpose, value, name) of/case sealValue(key, purpose, value, \"\") of/|a value is sealed without its name"
	"Vault.hiq|s/                    if equal(nameOf(old), name) then/                    if false then/|a secret set again gets a second line"
	"Vault.hiq|s/done := renameFile(asSpan(\&tempPath), vaultPath);/done := true;/|the new vault is never put in place"
	"Vault.hiq|s/case createNewFile(asSpan(\&tempPath), #o600) of/case createNewFile(asSpan(\&tempPath), #o644) of/|the vault is readable by others"
	"Vault.hiq|s/if not equal(asSpan(\&oldKey), asSpan(\&newKey)) then/if true then/|a rotation to the same key"
	"Vault.hiq|s/^                            good := false;/                            skip;/|a secret that does not open is dropped in a rotation"
	"Vault.hiq|s/                if there then/                if true then/|a delete of nothing writes and says yes"
	"Vault.hiq|s/if ((not isSecretName(name)) or (spanLength(value) = 0)) or/if (spanLength(value) = 0) or/|a secret under a name that is none"
)
