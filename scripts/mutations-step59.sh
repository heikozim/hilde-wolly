# The mutations of Wolly.Rambo (a client of RAMBO), sourced by
# scripts/mutate.sh and scripts/mutate-target.sh.
mutations+=(
	"Rambo.hiq|s/        if issuer\[size - 1\] = '\/' then/        if false then/|an issuer with a slash at its end is taken"
	"Rambo.hiq|s/        return local;/        return true;/|a redirect over http to any host"
	"Rambo.hiq|s/            if (letter or digit) or mark then/            if true then/|query values go out unencoded"
	"Rambo.hiq|s/        return (n - 10) + 'A';/        return (n - 10) + 'a';/|percent escapes in small letters"
	"Rambo.hiq|s/writeParam(\&!out, false, \"code_challenge_method\", \"S256\");/writeParam(\&!out, false, \"code_challenge_method\", \"plain\");/|PKCE plain instead of S256"
	"Rambo.hiq|s/                                if maxAge >= 0 then/                                if maxAge < 0 then/|max_age sent the wrong way round"
	"Rambo.hiq|s/        let bearer: Bool := (length(\&lowered) = 6) and startsWith(asSpan(\&lowered), \"bearer\");/        let bearer: Bool := startsWith(asSpan(\&lowered), \"bearer\");/|a token type that only begins with bearer"
	"Rambo.hiq|s/textOr(\&document, \"\/error\", \"http_error\")/textOr(\&document, \"\/error\", \"server_error\")/|an error without a name is called otherwise"
	# The DER of an AKP key is Standard.Jws's since Hilde took it over (its lengths and OIDs are Hilde's to mutate); Wolly
	# keeps the kind of key RAMBO publishes.
	"Rambo.hiq|s/                let akp: Bool := (length(\&kty) = 3) and startsWith(asSpan(\&kty), \"AKP\");/                let akp: Bool := true;/|a key of another kind than AKP is taken"
	"Rambo.hiq|s/                return publicKeyFromJwk(jwk);/                return None();/|an AKP key is not read"
	"Rambo.hiq|s/                if spanLength(nonce) = 0 then/                if false then/|an empty nonce passes"
	"Rambo.hiq|s/                            azpWrong := not equal(asSpan(\&azp), asSpan(\&(config->clientId)));/                            azpWrong := false;/|azp is not checked"
	"Rambo.hiq|s/                            if (at > (now + leewaySeconds())) or ((now - at) > (maxAge + leewaySeconds())) then/                            if (now - at) > (maxAge + leewaySeconds()) then/|an auth_time in the future passes"
	"Rambo.hiq|s/            if mine and fresh then/            if fresh then/|another session's sign-in is given back"
	"Rambo.hiq|s/            let fresh: Bool := (made <= now) and ((now - made) <= pendingSeconds());/            let fresh: Bool := (made <= now) and ((now - made) < pendingSeconds());/|the last second of a sign-in is lost"
	"Rambo.hiq|s/DELETE FROM wolly_rambo_pending WHERE state = ?\"/DELETE FROM wolly_rambo_pending WHERE state = ? AND 0\"/|a state is good for more than one try"
	"Rambo.hiq|s/INSERT OR REPLACE INTO wolly_rambo_id_tokens/INSERT OR IGNORE INTO wolly_rambo_id_tokens/|a newer ID token does not replace the old"
	"Rambo.hiq|s/DELETE FROM wolly_rambo_id_tokens WHERE session = ?\"/DELETE FROM wolly_rambo_id_tokens WHERE session = ? AND 0\"/|an ID token is taken more than once"
)
