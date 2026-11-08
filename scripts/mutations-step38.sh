# The mutations of Wolly.Pki, sourced by scripts/mutate.sh and
# scripts/mutate-target.sh.
mutations+=(
	"Pki.hiq|s/constant authorityMaxDays: Nat32 := 3650;/constant authorityMaxDays: Nat32 := 36500;/|an authority may be valid for 100 years"
	"Pki.hiq|s/constant machineMaxDays: Nat32 := 825;/constant machineMaxDays: Nat32 := 3650;/|a machine may be valid for ten years"
	"Pki.hiq|s/case selfSigned(\&key, commonName, \"\", days, true) of/case selfSigned(\&key, commonName, \"\", days, false) of/|the authority is no CA"
	"Pki.hiq|s/case issue(ca, caKey, machineKey, commonName, names, days, false) of/case issue(ca, caKey, machineKey, commonName, names, days, true) of/|the machine is a CA"
	"Pki.hiq|s/case verifyChain(certPem, caPem, host, at) of/case verifyChain(certPem, caPem, \"\", at) of/|the name is not checked"
	"Pki.hiq|s/case verifyChain(certPem, caPem, host, at) of/case verifyChain(certPem, certPem, host, at) of/|a certificate is its own authority"
	"Pki.hiq|s/case verifyChain(certPem, caPem, host, at) of/case verifyChain(certPem, caPem, host, 0) of/|the time is not checked"
)
