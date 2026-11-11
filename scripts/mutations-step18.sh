# The mutations of Wolly.Qr and its route in examples/hello, sourced by
# scripts/mutate.sh.
mutations+=(
	"Qr.hiq|s/        return 4;/        return 3;/|3 pixels a module"
	"Qr.hiq|s/constant quietModules: Index := 4;/constant quietModules: Index := 0;/|no quiet zone around the code"
	"Qr.hiq|s/QrMedium/QrLow/g|the code is made at level low"
	"Qr.hiq|s#\"data:image/png;base64,\"#\"data:image/png,\"#|the URI does not say base64"
	"examples/hello/Hello.hiq|s/case qrDataUri(asSpan(\&text)) of/case qrDataUri(\"hello\") of/|the route ignores its text"
)
