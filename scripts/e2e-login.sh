# The cases of scripts/e2e.sh against examples/login, sourced there.
PASSWORD="correct horse battery"
ORIGIN=$BASE

# The user ann, through the programme itself; the password on stdin.
app_prepare() {
	cp "$WOLLY/examples/login/known-passwords.txt" . || return 1
	printf '%s\n' "$PASSWORD" | ./login adduser ann > adduser.out 2>&1 || { cat adduser.out; return 1; }
	printf 'short\n' | ./login adduser bob > adduser-short.out 2>&1 && { echo "a short password was taken"; return 1; }
	printf '%s\n' "$PASSWORD" | ./login adduser ann > adduser-again.out 2>&1 && { echo "a taken name was taken again"; return 1; }
	# Roles: operator may admin, ann holds it, cid holds nothing.
	printf '%s\n' "$PASSWORD" | ./login adduser cid > adduser-cid.out 2>&1 || { cat adduser-cid.out; return 1; }
	# The rules of Wolly.Passphrase, before the server starts.
	printf 'fourteen chars\n' | ./login adduser eve > adduser-eve-short.out 2>&1 && { echo "14 characters were taken"; return 1; }
	printf 'PasswordPassword\n' | ./login adduser eve > adduser-eve-listed.out 2>&1 && { echo "a listed password was taken"; return 1; }
	printf 'eve has a long password\n' | ./login adduser eve > adduser-eve-name.out 2>&1 && { echo "a password with the name was taken"; return 1; }
	# U+FB01, the ligature fi, twice: five fingers on a hand in NFKC.
	printf '\357\254\201ve \357\254\201ngers on a hand\n' | ./login adduser fay > adduser-fay.out 2>&1 || { cat adduser-fay.out; return 1; }
	printf '  spaces around me  \n' | ./login adduser gil > adduser-gil.out 2>&1 || { cat adduser-gil.out; return 1; }
	# Edges of Wolly.Edges through the programme: a light way round a heavy
	# edge, and a cycle the route must not run into.
	./login link a b next 1 > link.out 2>&1 && ./login link b c next 1 >> link.out 2>&1 &&
		./login link a c next 5 >> link.out 2>&1 && ./login link c a next 1 >> link.out 2>&1 || { cat link.out; return 1; }
	./login link 'a b' c next 1 > link-bad.out 2>&1 && { echo "a node name with a space was taken"; return 1; }
	./login route next a c > route.out 2>&1 || { cat route.out; return 1; }
	./login route next c zz > route-none.out 2>&1 && { echo "a route to an unknown node was found"; return 1; }
	# A token for the machine backup, printed once.
	./login token backup > token.out 2>&1 || { cat token.out; return 1; }
	./login token 'Bad Name' > token-bad.out 2>&1 && { echo "a token for a name that is no name"; return 1; }
	# dee turns on the second factor during the run.
	printf '%s\n' "$PASSWORD" | ./login adduser dee > adduser-dee.out 2>&1 || { cat adduser-dee.out; return 1; }
	./login grant operator admin > grant.out 2>&1 || { cat grant.out; return 1; }
	./login assign ann operator > assign.out 2>&1 || { cat assign.out; return 1; }
	./login grant Operator admin > grant-bad.out 2>&1 && { echo "a role that is no name was granted"; return 1; }
	return 0
}

# The TOTP code of the base32 secret $1 at the step of now plus $2 steps:
# RFC 6238 with HMAC-SHA256, 6 digits, 30 seconds, as Wolly.Totp makes it.
totp_code() {
	python3 -I -c 'import base64, hashlib, hmac, struct, sys, time
key = base64.b32decode(sys.argv[1] + "=" * (-len(sys.argv[1]) % 8))
mac = hmac.new(key, struct.pack(">Q", int(time.time()) // 30 + int(sys.argv[2])), hashlib.sha256).digest()
at = mac[-1] & 15
print("%06d" % ((struct.unpack(">I", mac[at:at + 4])[0] & 0x7fffffff) % 1000000))' "$1" "$2"
}

# The session token in the Set-Cookie of the last answer, and the CSRF
# token in its page.
cookie_of() { tr -d '\r' < "$last.head" | sed -n 's/^Set-Cookie: __Host-wolly=\([0-9a-f]\{64\}\);.*/\1/p' | head -1; }
csrf_of() { sed -n 's/.*name="csrf" value="\([0-9a-f]\{64\}\)".*/\1/p' "$last.body" | head -1; }

# post <name> <status> <path> <pattern> <session> <form> [headers as curl args]
post() {
	local name=$1 status=$2 path=$3 pattern=$4 session=$5 form=$6
	shift 6
	local args=(--data-raw "$form")
	[ -n "$session" ] && args+=(-b "__Host-wolly=$session")
	expect "$name" "$status" "$path" "$pattern" "${args[@]}" "$@"
}
SAME=(-H "Sec-Fetch-Site: same-origin" -H "Origin: $ORIGIN")

app_cases() {
	echo "== prepared"
	check "adduser ann" grep -qx "login: user added" "$D/adduser.out"
	check "a password of 5 bytes is refused" grep -q "refused" "$D/adduser-short.out"
	check "csrf.key is made with mode 600" [ "$(mode_of "$D/csrf.key")" = 600 ]
	check "14 characters are too short" grep -q "too short" "$D/adduser-eve-short.out"
	check "a listed password is refused, in other capitals" grep -q "on the list of known passwords" "$D/adduser-eve-listed.out"
	check "a password that holds the name is refused" grep -q "holds the user name" "$D/adduser-eve-name.out"
	check "the control: fay is added" grep -qx "login: user added" "$D/adduser-fay.out"
	check "four edges are stored" [ "$(grep -c -x 'login: edge stored' "$D/link.out")" = 4 ]
	check "a node name with a space is refused" grep -q "is no node name" "$D/link-bad.out"
	check "the lightest route goes round the heavy edge" bash -c "printf 'a\\nb\\nc\\nweight 2\\n' | cmp -s - '$D/route.out'"
	check "no route to an unknown node" grep -qx "login: no route" "$D/route-none.out"
	check "grant operator admin" grep -qx "login: roles changed" "$D/grant.out"
	check "assign ann operator" grep -qx "login: roles changed" "$D/assign.out"
	check "a role that is no name is refused" grep -q "refused: a name is no name" "$D/grant-bad.out"

	echo "== a visitor"
	expect "GET / without a session goes to the login" 303 "/" "^Location: /login$"
	expect "the login page" 200 "/login" 'name="csrf" value="[0-9a-f]{64}"'
	local s1 c1
	s1=$(cookie_of)
	c1=$(csrf_of)
	check "a session cookie: __Host-, Secure, HttpOnly, SameSite=Strict" grep -qE '^Set-Cookie: __Host-wolly=[0-9a-f]{64}; Path=/; Secure; HttpOnly; SameSite=Strict' <(tr -d '\r' < "$last.head")
	check "the page cannot be framed" grep -q '^X-Frame-Options: DENY' <(tr -d '\r' < "$last.head")
	check "the page has a CSP without scripts" grep -q "^Content-Security-Policy: default-src 'none'; form-action 'self'; frame-ancestors 'none'" <(tr -d '\r' < "$last.head")
	check "the page is not cached" grep -q '^Cache-Control: no-store' <(tr -d '\r' < "$last.head")
	check "the step after adds the referrer policy" grep -q '^Referrer-Policy: same-origin' <(tr -d '\r' < "$last.head")
	check "the step after adds nosniff" grep -q '^X-Content-Type-Options: nosniff' <(tr -d '\r' < "$last.head")
	check "the page comes from the layout" grep -q '<title>Login</title>' "$last.body"
	# Hiawatha hands GET, HEAD, POST and QUERY to the application; QUERY is
	# none of the seven the step knownMethods takes (docs/hiawatha.md).
	expect "QUERY ends at the step before the router" 405 "/login" "^Allow: GET, HEAD, POST, PUT, PATCH, DELETE, OPTIONS$" -X QUERY
	expect "an answer of a step before gets the steps after" 405 "/login" "^X-Frame-Options: DENY$" -X QUERY
	expect "TRACE does not reach the application: Hiawatha answers 501" 501 "/login" "." -X TRACE
	expect "a query reaches the page" 200 "/login?next=s3cr3t" 'name="csrf"'
	expect "the page again keeps the session" 200 "/login" "^Set-Cookie: __Host-wolly=$s1;" -b "__Host-wolly=$s1"

	echo "== what the guard refuses"
	post "no csrf field" 403 "/login" "^forbidden$" "$s1" "name=ann&password=$PASSWORD" "${SAME[@]}"
	local wrong
	# The token with its first digit changed, so it is never the token.
	if [ "${c1:0:1}" = a ]; then wrong="b${c1:1}"; else wrong="a${c1:1}"; fi
	check "the changed token differs" test -n "$c1" -a "$wrong" != "$c1"
	post "a wrong csrf token" 403 "/login" "^forbidden$" "$s1" "csrf=$wrong&name=ann&password=$PASSWORD" "${SAME[@]}"
	post "from another site, with the token" 403 "/login" "^forbidden$" "$s1" "csrf=$c1&name=ann&password=$PASSWORD" -H "Sec-Fetch-Site: cross-site" -H "Origin: https://evil.example"
	post "a foreign Origin, with the token" 403 "/login" "^forbidden$" "$s1" "csrf=$c1&name=ann&password=$PASSWORD" -H "Origin: https://evil.example"
	post "no session cookie" 403 "/login" "^forbidden$" "" "csrf=$c1&name=ann&password=$PASSWORD" "${SAME[@]}"

	echo "== login"
	post "a wrong password" 401 "/login" '<p class="message">login refused: ann</p>' "$s1" "csrf=$c1&name=ann&password=wrong+password+one" "${SAME[@]}"
	check "the refused form has a token of the same session" grep -q "value=\"$c1\"" "$last.body"
	post "a name that does not exist" 401 "/login" 'login refused: nobody' "$s1" "csrf=$c1&name=nobody&password=$PASSWORD" "${SAME[@]}"
	post "a name with a script comes back escaped" 401 "/login" 'login refused: &lt;script&gt;alert\(1\)&lt;/script&gt;' "$s1" "csrf=$c1&name=%3Cscript%3Ealert(1)%3C%2Fscript%3E&password=$PASSWORD" "${SAME[@]}"
	check "and never as a script" bash -c "! grep -q '<script>alert' '$last.body'"
	check "the control: the escaped name is in the page" grep -q '&lt;script&gt;alert' "$last.body"
	post "a name that leaves the attribute comes back escaped" 401 "/login" 'value="&#34;&gt;&lt;img src=x onerror=alert\(1\)&gt;"' "$s1" "csrf=$c1&name=%22%3E%3Cimg+src%3Dx+onerror%3Dalert(1)%3E&password=$PASSWORD" "${SAME[@]}"
	check "and never as a tag" bash -c "! grep -q '<img' '$last.body'"
	post "the right password" 303 "/login" "^Location: /$" "$s1" "csrf=$c1&name=ann&password=$PASSWORD" "${SAME[@]}"
	local s2
	s2=$(cookie_of)
	check "the login gives a new token" test -n "$s2" -a "$s2" != "$s1"
	expect "GET / names the user" 200 "/" "<p>hello, ann</p>" -b "__Host-wolly=$s2"
	local c2
	c2=$(csrf_of)
	check "the user page has a csrf token" test -n "$c2"
	expect "the token from before the login opens nothing" 303 "/" "^Location: /login$" -b "__Host-wolly=$s1"

	echo "== a password typed into the name field"
	# After the login of ann, which cleared the failures of the client: a
	# fifth failure before it would have throttled the right password.  The
	# audit must not keep what is no name, since it may be a password;
	# "the audit holds no password" below looks for this one.
	expect "a login page" 200 "/login" 'name="csrf"'
	local sq cq
	sq=$(cookie_of)
	cq=$(csrf_of)
	post "the password as the name is refused" 401 "/login" "login refused" "$sq" "csrf=$cq&name=correct+horse+battery&password=$PASSWORD" "${SAME[@]}"
	check "the audit has the refusal without a name" grep -q '"msg":"login","user":"-",.*"outcome":"refused"' "$D/audit.log"

	echo "== roles"
	expect "GET /admin without a session goes to the login" 303 "/admin" "^Location: /login$"
	expect "ann holds operator, which may admin" 200 "/admin" "^admin area$" -b "__Host-wolly=$s2"
	expect "a login page for cid" 200 "/login" 'name="csrf"'
	local s5 c5 s6
	s5=$(cookie_of)
	c5=$(csrf_of)
	post "cid logs in" 303 "/login" "^Location: /$" "$s5" "csrf=$c5&name=cid&password=$PASSWORD" "${SAME[@]}"
	s6=$(cookie_of)
	expect "the control: cid is logged in" 200 "/" "<p>hello, cid</p>" -b "__Host-wolly=$s6"
	expect "cid, who holds no role, gets 403 at /admin" 403 "/admin" "^forbidden$" -b "__Host-wolly=$s6"

	echo "== users by the sound of their names (Wolly.SoundSearch)"
	expect "GET /admin/find without a session goes to the login" 303 "/admin/find?name=Anne" "^Location: /login$"
	expect "ann, who may admin, finds ann by Anne" 200 "/admin/find?name=Anne" "^ann$" -b "__Host-wolly=$s2"
	check "and nobody else" test "$(wc -l < "$last.body")" -eq 1
	expect "Sid sounds like cid" 200 "/admin/find?name=Sid" "^cid$" -b "__Host-wolly=$s2"
	expect "a name without a sound finds nobody" 200 "/admin/find?name=42" "^Content-Type: text/plain" -b "__Host-wolly=$s2"
	check "the answer is empty" test ! -s "$last.body"
	expect "cid, who may not admin, gets 403" 403 "/admin/find?name=Anne" "^forbidden$" -b "__Host-wolly=$s6"

	echo "== bearer tokens"
	local token
	token=$(cat "$D/token.out")
	check "the token is 64 hex digits" grep -qxE '[0-9a-f]{64}' "$D/token.out"
	check "a name that is no name gets none" grep -q "refused: the name is no name" "$D/token-bad.out"
	expect "the token names its machine" 200 "/api/whoami" "^token of backup$" -H "Authorization: Bearer $token"
	expect "the scheme in another case, two spaces" 200 "/api/whoami" "^token of backup$" -H "Authorization: bEaReR  $token"
	expect "without a token: 401 and the scheme" 401 "/api/whoami" "^WWW-Authenticate: Bearer$"
	local wrong
	# The token with its last digit changed, so it is never the token.
	if [ "${token: -1}" = 0 ]; then wrong="${token%?}1"; else wrong="${token%?}0"; fi
	check "the changed token differs" test -n "$token" -a "$wrong" != "$token"
	expect "a token one digit off" 401 "/api/whoami" "^WWW-Authenticate: Bearer$" -H "Authorization: Bearer $wrong"
	expect "no space after Bearer" 401 "/api/whoami" "^WWW-Authenticate: Bearer$" -H "Authorization: Bearer$token"
	expect "Basic is no bearer" 401 "/api/whoami" "^WWW-Authenticate: Bearer$" -H "Authorization: Basic $token"
	# Only a scheme of six letters reaches the check of the space after it, so only
	# these tell the check of the scheme from the check of the space.
	expect "Digest, a scheme of six letters, is no bearer" 401 "/api/whoami" "^WWW-Authenticate: Bearer$" -H "Authorization: Digest $token"
	expect "Bearex, one letter off, is no bearer" 401 "/api/whoami" "^WWW-Authenticate: Bearer$" -H "Authorization: Bearex $token"
	# The digest is made here and its length checked: an empty one would match any file.
	local tokenDigest
	tokenDigest=$(printf %s "$token" | openssl dgst -sha256 -binary | od -An -tx1 | tr -d ' \n')
	check "the digest of the token has 64 hex digits" [ ${#tokenDigest} -eq 64 ]
	check "the database holds the digest, not the token" bash -c "! grep -qsa '$token' '$D/wolly.db' '$D/wolly.db-wal' && grep -qsa '$tokenDigest' '$D/wolly.db' '$D/wolly.db-wal'"
	(cd "$D" && ./login revoke backup) > "$D/revoke.out" 2>&1
	check "login revoke backup" grep -qx "login: tokens revoked" "$D/revoke.out"
	expect "a revoked token opens nothing" 401 "/api/whoami" "^WWW-Authenticate: Bearer$" -H "Authorization: Bearer $token"

	echo "== passwords"
	local s13 c13
	expect "a login page" 200 "/login" 'name="csrf"'
	s13=$(cookie_of)
	c13=$(csrf_of)
	post "fay logs in with the password in NFKC, no ligatures" 303 "/login" "^Location: /$" "$s13" "csrf=$c13&name=fay&password=five+fingers+on+a+hand" "${SAME[@]}"
	expect "a login page" 200 "/login" 'name="csrf"'
	s13=$(cookie_of)
	c13=$(csrf_of)
	post "gil without the spaces around is refused" 401 "/login" "login refused" "$s13" "csrf=$c13&name=gil&password=spaces+around+me" "${SAME[@]}"
	post "gil with them logs in" 303 "/login" "^Location: /$" "$s13" "csrf=$c13&name=gil&password=++spaces+around+me++" "${SAME[@]}"

	echo "== second factor"
	local s7 c7 s8 c8 s9 c9 s10 c10 s11 secret code code2
	expect "GET /totp without a session goes to the login" 303 "/totp" "^Location: /login$"
	expect "a login page for dee" 200 "/login" 'name="csrf"'
	s7=$(cookie_of)
	c7=$(csrf_of)
	post "dee logs in with the password alone" 303 "/login" "^Location: /$" "$s7" "csrf=$c7&name=dee&password=$PASSWORD" "${SAME[@]}"
	s8=$(cookie_of)
	expect "dee asks for the second factor: a QR code" 200 "/totp" 'src="data:image/png;base64,iVBORw0KGgo' -b "__Host-wolly=$s8"
	check "the page may show an image of a data URI, nothing else" grep -q "^Content-Security-Policy: default-src 'none'; img-src data:; form-action 'self'; frame-ancestors 'none'" <(tr -d '\r' < "$last.head")
	check "the page with the secret is not cached" grep -q '^Cache-Control: no-store' <(tr -d '\r' < "$last.head")
	secret=$(sed -n 's/.*<code class="secret">\([A-Z2-7]\{32\}\)<\/code>.*/\1/p' "$last.body" | head -1)
	check "the secret is 32 digits of base32" [ ${#secret} -eq 32 ]
	c8=$(csrf_of)
	post "the first code without the token" 403 "/totp" "^forbidden$" "$s8" "code=123456" "${SAME[@]}"
	post "a wrong first code" 400 "/totp" "^code refused$" "$s8" "csrf=$c8&code=000000" "${SAME[@]}"
	code=$(totp_code "$secret" 0)
	post "the code of the app turns it on" 200 "/totp" "^two-factor is on$" "$s8" "csrf=$c8&code=$code" "${SAME[@]}"
	expect "a second start is refused" 409 "/totp" "^two-factor is on already$" -b "__Host-wolly=$s8"
	check "the seed is not in the database in the clear" python3 -I -c 'import base64, os, sys
seed = base64.b32decode(sys.argv[1] + "=" * (-len(sys.argv[1]) % 8))
data = b"".join(open(p, "rb").read() for p in sys.argv[2:] if os.path.exists(p))
sys.exit(1 if (len(seed) != 20 or seed in data or sys.argv[1].encode() in data) else 0)' "$secret" "$D/wolly.db" "$D/wolly.db-wal"
	check "the control: the database has the table of seeds" grep -qa "wolly_totp" "$D/wolly.db"
	check "totp.key is made with mode 600" [ "$(mode_of "$D/totp.key")" = 600 ]
	expect "a login page" 200 "/login" 'name="csrf"'
	s9=$(cookie_of)
	c9=$(csrf_of)
	post "now the password stops at the code" 303 "/login" "^Location: /login/code$" "$s9" "csrf=$c9&name=dee&password=$PASSWORD" "${SAME[@]}"
	s10=$(cookie_of)
	check "under a new token" test -n "$s10" -a "$s10" != "$s9"
	expect "the waiting session is no login" 303 "/" "^Location: /login$" -b "__Host-wolly=$s10"
	expect "nor may it start a factor" 303 "/totp" "^Location: /login$" -b "__Host-wolly=$s10"
	expect "the form for the code" 200 "/login/code" 'name="code"' -b "__Host-wolly=$s10"
	c10=$(csrf_of)
	post "a code without the token" 403 "/login/code" "^forbidden$" "$s10" "code=123456" "${SAME[@]}"
	post "the code that turned it on is taken" 401 "/login/code" "code refused" "$s10" "csrf=$c10&code=$code" "${SAME[@]}"
	code2=$(totp_code "$secret" 1)
	post "the next code logs in" 303 "/login/code" "^Location: /$" "$s10" "csrf=$c10&code=$code2" "${SAME[@]}"
	s11=$(cookie_of)
	check "under yet another token" test -n "$s11" -a "$s11" != "$s10"
	expect "GET / names dee" 200 "/" "<p>hello, dee</p>" -b "__Host-wolly=$s11"
	(cd "$D" && printf '%s\n%s\n' "$PASSWORD" "short pw" | ./login passwd dee) > "$D/passwd-dee.out" 2>&1
	check "with the factor on, dee may take 8 characters" grep -qx "login: password changed" "$D/passwd-dee.out"
	(cd "$D" && printf '%s\n%s\n' "$PASSWORD" "short pw" | ./login passwd ann) > "$D/passwd-ann.out" 2>&1
	check "ann, without it, may not" grep -q "too short" "$D/passwd-ann.out"
	(cd "$D" && printf '%s\n%s\n' "wrong password here" "another fine password" | ./login passwd ann) > "$D/passwd-wrong.out" 2>&1
	check "a wrong current password changes nothing" grep -q "refused: the current password is wrong" "$D/passwd-wrong.out"
	expect "the waiting token opens nothing now" 303 "/" "^Location: /login$" -b "__Host-wolly=$s10"
	check "the audit has the stop at the code" grep -q '"msg":"login".*"user":"dee".*"outcome":"code-needed"' "$D/audit.log"
	check "the audit has the refused code" grep -q '"msg":"login-code".*"user":"dee".*"outcome":"refused"' "$D/audit.log"
	check "the audit has the login by code" grep -q '"msg":"login-code".*"user":"dee".*"outcome":"ok"' "$D/audit.log"
	(cd "$D" && ./login totp-off dee) > "$D/totp-off.out" 2>&1
	check "login totp-off dee" grep -qx "login: two-factor off" "$D/totp-off.out"
	(cd "$D" && ./login totp-off dee) > "$D/totp-off-again.out" 2>&1
	check "a second totp-off finds nothing" grep -q "refused: the user has no second factor" "$D/totp-off-again.out"
	expect "a login page" 200 "/login" 'name="csrf"'
	local s12 c12
	s12=$(cookie_of)
	c12=$(csrf_of)
	post "after totp-off the new password logs in, without a code" 303 "/login" "^Location: /$" "$s12" "csrf=$c12&name=dee&password=short+pw" "${SAME[@]}"

	echo "== notes, a table of its own"
	expect "GET /notes without a session goes to the login" 303 "/notes" "^Location: /login$"
	expect "ann's notes page" 200 "/notes" '<pre class="notes"></pre>' -b "__Host-wolly=$s2"
	local cn
	cn=$(csrf_of)
	check "the notes page has a csrf token" test -n "$cn"
	post "a note without the token" 403 "/notes" "^forbidden$" "$s2" "content=buy+bread" "${SAME[@]}"
	post "a note without a session" 403 "/notes" "^forbidden$" "" "csrf=$cn&content=buy+bread" "${SAME[@]}"
	post "ann adds a note" 303 "/notes" "^Location: /notes$" "$s2" "csrf=$cn&content=buy+bread" "${SAME[@]}"
	post "and one with a script" 303 "/notes" "^Location: /notes$" "$s2" "csrf=$cn&content=%3Cscript%3Ealert(1)%3C%2Fscript%3E" "${SAME[@]}"
	expect "the notes, newest first, escaped" 200 "/notes" '<pre class="notes">&lt;script&gt;alert\(1\)&lt;/script&gt;$' -b "__Host-wolly=$s2"
	check "the older note follows" grep -qx "buy bread" "$last.body"
	check "and the script is never a tag" bash -c "! grep -q '<script>' '$last.body'"
	local long
	long=$(printf '%0500d' 0 | tr 0 a)
	post "a note of 500 bytes" 303 "/notes" "^Location: /notes$" "$s2" "csrf=$cn&content=$long" "${SAME[@]}"
	post "a note of 501 bytes is refused" 400 "/notes" "^note refused$" "$s2" "csrf=$cn&content=${long}b" "${SAME[@]}"
	post "an empty note is refused" 400 "/notes" "^note refused$" "$s2" "csrf=$cn&content=" "${SAME[@]}"
	post "a note with a line feed is refused" 400 "/notes" "^note refused$" "$s2" "csrf=$cn&content=one%0Atwo" "${SAME[@]}"
	post "a note that is no UTF-8 is refused" 400 "/notes" "^note refused$" "$s2" "csrf=$cn&content=caf%E9" "${SAME[@]}"
	post "a note in UTF-8 is taken" 303 "/notes" "^Location: /notes$" "$s2" "csrf=$cn&content=caf%C3%A9" "${SAME[@]}"
	expect "cid's notes page is empty" 200 "/notes" '<pre class="notes"></pre>' -b "__Host-wolly=$s6"
	check "and shows none of ann's" bash -c "! grep -q 'buy bread' '$last.body'"
	expect "the control: ann's page still has them" 200 "/notes" "^buy bread$" -b "__Host-wolly=$s2"

	echo "== at most 100 notes a user, as many as /notes shows"
	# 99 notes of cid straight into the database, since 99 POSTs would run
	# into the limit on POST; the 100th through the server is taken, the
	# 101st refused.
	python3 -I -c 'import sqlite3, sys
db = sqlite3.connect(sys.argv[1], timeout=30)
with db:
    db.executemany("INSERT INTO notes (owner, content, created_at) VALUES (?, ?, 0)", [("cid", "old %d" % i) for i in range(99)])
print(db.execute("SELECT count(*) FROM notes WHERE owner = ?", ("cid",)).fetchone()[0])' "$D/wolly.db" > "$D/notes-cid.out" 2>&1
	check "cid keeps 99 notes" grep -qx 99 "$D/notes-cid.out"
	expect "cid's notes page" 200 "/notes" '<pre class="notes">old 98$' -b "__Host-wolly=$s6"
	local c6
	c6=$(csrf_of)
	post "the 100th note of cid is taken" 303 "/notes" "^Location: /notes$" "$s6" "csrf=$c6&content=the+hundredth" "${SAME[@]}"
	post "the 101st is refused" 400 "/notes" "^too many notes$" "$s6" "csrf=$c6&content=one+too+many" "${SAME[@]}"
	expect "the page shows all 100, the newest first" 200 "/notes" '<pre class="notes">the hundredth$' -b "__Host-wolly=$s6"
	check "and not the refused one" bash -c "! grep -q 'one too many' '$last.body'"
	post "the control: ann, with fewer, still adds one" 303 "/notes" "^Location: /notes$" "$s2" "csrf=$cn&content=after+cid" "${SAME[@]}"

	echo "== login deluser"
	(cd "$D" && ./login assign cid operator && ./login token cid) > "$D/cid-kept.out" 2>&1
	local tcid
	tcid=$(tail -1 "$D/cid-kept.out")
	check "cid holds operator now and has a token" grep -qxE '[0-9a-f]{64}' <(printf '%s\n' "$tcid")
	expect "the control: cid may admin" 200 "/admin" "^admin area$" -b "__Host-wolly=$s6"
	expect "the control: the token of cid opens the API" 200 "/api/whoami" "^token of cid$" -H "Authorization: Bearer $tcid"
	local ncid npre
	ncid=$(grep -c '"user":"cid"' "$D/audit.log")
	npre=$(grep -c '"msg":"audit-pseudonymize"' "$D/audit.log")
	check "the audit names cid before ($ncid lines)" [ "$ncid" -gt 0 ]
	(cd "$D" && ./login deluser cid) > "$D/deluser.out" 2>&1
	check "login deluser cid, with as many lines pseudonymized" grep -qx "login: user removed, lines of the audit log pseudonymized: $ncid" "$D/deluser.out"
	check "the audit names cid in no line now" bash -c "! grep -q '\"user\":\"cid\"' '$D/audit.log'"
	check "one line notes the pseudonymization" [ "$(grep -c '"msg":"audit-pseudonymize"' "$D/audit.log")" = $((npre + 1)) ]
	local alias
	alias=$(grep -o '"msg":"audit-pseudonymize","user":"deleted-[0-9a-f]\{16\}","client":"-","outcome":"ok","lines":'"$ncid"'}' "$D/audit.log" | tail -1 | sed 's/.*"user":"\(deleted-[0-9a-f]*\)".*/\1/')
	check "under a pseudonym of 16 hex digits, with the number of lines" grep -qxE 'deleted-[0-9a-f]{16}' <(printf '%s\n' "$alias")
	check "the lines of cid have it as user" [ "$(grep -c "\"user\":\"$alias\"" "$D/audit.log")" = $((ncid + 1)) ]
	check "and as client" [ "$(grep -c "\"client\":\"$alias\"" "$D/audit.log")" = "$ncid" ]
	check "their events, times and outcomes stay ($ncid lines with time, level, msg, outcome)" [ "$(python3 -I -c 'import json, sys
n = 0
for raw in open(sys.argv[1]):
    try:
        e = json.loads(raw)
    except ValueError:
        continue
    if isinstance(e, dict) and e.get("user") == sys.argv[2] and e.get("client") == sys.argv[2] and e.get("msg") and e.get("outcome") and e.get("level") == "INFO" and e.get("time", "").endswith("Z"):
        n += 1
print(n)' "$D/audit.log" "$alias")" = "$ncid" ]
	check "the control: ann is still named" grep -q '"user":"ann"' "$D/audit.log"
	echo "-- the lines of $alias:"; grep -F "$alias" "$D/audit.log" | head -4
	expect "the session of cid opens nothing" 303 "/" "^Location: /login$" -b "__Host-wolly=$s6"
	expect "nor its token" 401 "/api/whoami" "^WWW-Authenticate: Bearer$" -H "Authorization: Bearer $tcid"
	expect "Sid finds nobody now" 200 "/admin/find?name=Sid" "^Content-Type: text/plain" -b "__Host-wolly=$s2"
	check "the answer is empty" test ! -s "$last.body"
	(cd "$D" && ./login deluser cid) > "$D/deluser-again.out" 2>&1
	check "a second deluser finds nobody" grep -qx "login: refused: there is no such user" "$D/deluser-again.out"
	(cd "$D" && ./login deluser ann-not-there) > "$D/deluser-none.out" 2>&1
	check "nor one of a name never added" grep -qx "login: refused: there is no such user" "$D/deluser-none.out"
	# cid again under the same name: nothing of the old cid may come back.
	(cd "$D" && printf '%s\n' "$PASSWORD" | ./login adduser cid) > "$D/adduser-cid2.out" 2>&1
	check "cid is added again" grep -qx "login: user added" "$D/adduser-cid2.out"
	expect "a login page for the new cid" 200 "/login" 'name="csrf"'
	local sn cn2 sn2
	sn=$(cookie_of)
	cn2=$(csrf_of)
	post "the new cid logs in" 303 "/login" "^Location: /$" "$sn" "csrf=$cn2&name=cid&password=$PASSWORD" "${SAME[@]}"
	sn2=$(cookie_of)
	expect "the new cid has no notes" 200 "/notes" '<pre class="notes"></pre>' -b "__Host-wolly=$sn2"
	expect "nor the role of the old one" 403 "/admin" "^forbidden$" -b "__Host-wolly=$sn2"
	expect "the control: ann keeps the notes" 200 "/notes" '<pre class="notes">after cid$' -b "__Host-wolly=$s2"
	expect "and the role" 200 "/admin" "^admin area$" -b "__Host-wolly=$s2"

	echo "== audit log kept 12 months"
	check "the server ran the retention at its start" grep -q '"msg":"audit-prune","user":"-","client":"-","outcome":"ok","lines":0}' "$D/audit.log"
	# A line of 2020 and one of a day ago, written as Wolly.Auth writes.
	local today
	today=$(python3 -I -c 'import time; print(time.strftime("%Y-%m-%dT%H:%M:%S.000Z", time.gmtime(time.time() - 86400)))')
	printf '%s\n' '{"time":"2020-01-01T00:00:00.000Z","level":"info","msg":"login","user":"zed","client":"-","outcome":"ok"}' \
		"{\"time\":\"$today\",\"level\":\"info\",\"msg\":\"login\",\"user\":\"yan\",\"client\":\"-\",\"outcome\":\"ok\"}" >> "$D/audit.log"
	check "the old line is there before" grep -q '"user":"zed"' "$D/audit.log"
	(cd "$D" && ./login audit-prune) > "$D/prune.out" 2>&1
	check "login audit-prune removes one line" grep -qx "login: lines of the audit log older than 12 months removed: 1" "$D/prune.out"
	check "the line of 2020 is gone" bash -c "! grep -q '\"user\":\"zed\"' '$D/audit.log'"
	check "the line of a day ago stays" grep -q '"user":"yan"' "$D/audit.log"
	check "the run is noted with its count" grep -q '"msg":"audit-prune","user":"-","client":"-","outcome":"ok","lines":1}' "$D/audit.log"
	check "the control: the pseudonymized lines stay" grep -q "\"user\":\"$alias\"" "$D/audit.log"
	check "the log keeps its mode 640" [ "$(mode_of "$D/audit.log")" = 640 ]
	expect "a login after the rewrite is written to the new log" 200 "/login" 'name="csrf"'
	local sz cz
	sz=$(cookie_of)
	cz=$(csrf_of)
	post "a refused login after the rewrite" 401 "/login" "login refused" "$sz" "csrf=$cz&name=yan&password=$PASSWORD" "${SAME[@]}"
	check "its line is in the log" bash -c "tail -1 '$D/audit.log' | grep -q '\"user\":\"yan\",.*\"outcome\":\"refused\"'"
	# A login clears the failure of the client again, which the throttling
	# below counts from zero.
	post "ann logs in after it" 303 "/login" "^Location: /$" "$sz" "csrf=$cz&name=ann&password=$PASSWORD" "${SAME[@]}"

	echo "== a POST while a rewrite of the audit log holds the database"
	# A second process holds a writing transaction for 7 seconds, longer
	# than the busy time of 5, and rewrites the log under it as deluser
	# does.  A POST meanwhile does not reach Wolly.Auth: Wolly.Limit must
	# count it first, cannot write, and refuses it with 503, so it writes no
	# audit line and the limit does not count it.  That the audit line
	# itself waits for the lock is the unit test testAuditWaitsForTheLock.
	expect "a login page for the lock" 200 "/login" 'name="csrf"'
	local sk ck holder asker t0 t1
	sk=$(cookie_of)
	ck=$(csrf_of)
	rm -f "$D/lock-held"
	python3 -I -c 'import os, sqlite3, sys, time
db = sqlite3.connect(sys.argv[1], timeout=30, isolation_level=None)
db.execute("BEGIN IMMEDIATE")
open(sys.argv[2], "w").close()
time.sleep(7)
log = sys.argv[3]
with open(log, "rb") as f:
    data = f.read()
with open(log + ".held", "wb") as f:
    f.write(data)
os.chmod(log + ".held", 0o640)
os.rename(log + ".held", log)
db.execute("COMMIT")
print("held", os.stat(log).st_ino)' "$D/wolly.db" "$D/lock-held" "$D/audit.log" > "$D/lock-holder.out" 2>&1 &
	holder=$!
	local n=0
	while [ ! -e "$D/lock-held" ] && [ $n -lt 100 ]; do sleep 0.1; n=$((n + 1)); done
	check "the second process holds the transaction" test -e "$D/lock-held"
	local inode
	inode=$(python3 -I -c 'import os, sys; print(os.stat(sys.argv[1]).st_ino)' "$D/audit.log")
	local codes
	codes=$(grep -c '"msg":"login-code"' "$D/audit.log")
	t0=$(date +%s)
	curl -s "${CURL_TLS[@]}" -o "$D/lock-answer.body" --max-time 60 -b "__Host-wolly=$sk" -H "Sec-Fetch-Site: same-origin" -H "Origin: $ORIGIN" \
		-w "%{http_code}" --data-raw "csrf=$ck&code=123456" "$BASE/login/code" > "$D/lock-answer.code" &
	asker=$!
	wait "$holder"
	check "the second process held 7 seconds and renamed the log" grep -q '^held ' "$D/lock-holder.out"
	wait "$asker"
	t1=$(date +%s)
	LOCK_T0=$t0
	LOCK_RID=$(grep '"method":"POST","path":"/login/code"' "$D/access.log" | tail -1 | sed -n 's/.*"request_id":"\([0-9a-f]\{32\}\)".*/\1/p')
	check "the request that waited is in the access log" test -n "$LOCK_RID"
	check "the POST is refused 503 by the limit" grep -qx 503 "$D/lock-answer.code"
	check "after the busy time ($((t1 - t0)) s)" [ $((t1 - t0)) -ge 5 ]
	check "the log was replaced (inode $inode before)" bash -c "[ \"\$(python3 -I -c 'import os, sys; print(os.stat(sys.argv[1]).st_ino)' '$D/audit.log')\" != '$inode' ]"
	check "no line of the refused POST is in the log ($codes login-code lines before)" [ "$(grep -c '"msg":"login-code"' "$D/audit.log")" = "$codes" ]
	check "the control: a line written without waiting has no lock_retries" grep -qE '"msg":"login","user":"ann","client":"[0-9a-f]{64}","outcome":"ok"\}$' "$D/audit.log"

	echo "== passkeys, with an authenticator of Python and openssl"
	local pk="$D/passkey.pem" pkrp="${BASE#*://}" auth="$WOLLY/scripts/passkey-authenticator.py" ch form
	pkrp=${pkrp%%:*}
	openssl ecparam -name prime256v1 -genkey -noout -out "$pk" 2> /dev/null
	check "the authenticator has a key of P-256" test -s "$pk"
	post "a challenge without the token" 403 "/passkey/challenge" "^forbidden$" "$s2" "purpose=create" "${SAME[@]}"
	post "ann asks for a challenge to create a passkey" 200 "/passkey/challenge" "^[A-Za-z0-9_-]{43}$" "$s2" "csrf=$c2&purpose=create" "${SAME[@]}"
	ch=$(tr -d '\r\n' < "$last.body")
	form=$(python3 -I "$auth" create "$pk" "$ch" "$ORIGIN" "$pkrp")
	post "a passkey without the password is refused" 401 "/passkey/register" "^password refused$" "$s2" "csrf=$c2&$form" "${SAME[@]}"
	post "a new challenge for ann" 200 "/passkey/challenge" "^[A-Za-z0-9_-]{43}$" "$s2" "csrf=$c2&purpose=create" "${SAME[@]}"
	ch=$(tr -d '\r\n' < "$last.body")
	form=$(python3 -I "$auth" create "$pk" "$ch" "$ORIGIN" "$pkrp")
	post "ann registers the passkey with her password" 201 "/passkey/register" "^passkey kept$" "$s2" "csrf=$c2&password=$PASSWORD&$form" "${SAME[@]}"
	post "the same registration again: the challenge is spent" 400 "/passkey/register" "^passkey refused$" "$s2" "csrf=$c2&password=$PASSWORD&$form" "${SAME[@]}"
	expect "a login page for the passkey" 200 "/login" 'name="csrf"'
	local sp cp sp2
	sp=$(cookie_of)
	cp=$(csrf_of)
	post "a visitor may not create a passkey" 400 "/passkey/challenge" "^no challenge$" "$sp" "csrf=$cp&purpose=create" "${SAME[@]}"
	post "a challenge to log in as ann" 200 "/passkey/challenge" "^[A-Za-z0-9_-]{43}$" "$sp" "csrf=$cp&purpose=get&name=ann" "${SAME[@]}"
	ch=$(tr -d '\r\n' < "$last.body")
	form=$(python3 -I "$auth" get "$pk" "$ch" "$ORIGIN" "$pkrp" 1)
	post "the passkey logs ann in" 303 "/passkey/login" "^Location: /$" "$sp" "csrf=$cp&$form" "${SAME[@]}"
	sp2=$(cookie_of)
	check "the passkey login gives a new token" test -n "$sp2" -a "$sp2" != "$sp"
	expect "GET / names ann" 200 "/" "<p>hello, ann</p>" -b "__Host-wolly=$sp2"
	expect "a login page again" 200 "/login" 'name="csrf"'
	sp=$(cookie_of)
	cp=$(csrf_of)
	post "the same login again: the challenge is spent" 401 "/passkey/login" "^passkey refused$" "$sp" "csrf=$cp&$form" "${SAME[@]}"
	post "a new challenge" 200 "/passkey/challenge" "^[A-Za-z0-9_-]{43}$" "$sp" "csrf=$cp&purpose=get&name=ann" "${SAME[@]}"
	ch=$(tr -d '\r\n' < "$last.body")
	form=$(python3 -I "$auth" get "$pk" "$ch" "$ORIGIN" "$pkrp" 1)
	post "the counter 1 again is refused" 401 "/passkey/login" "^passkey refused$" "$sp" "csrf=$cp&$form" "${SAME[@]}"
	post "a new challenge" 200 "/passkey/challenge" "^[A-Za-z0-9_-]{43}$" "$sp" "csrf=$cp&purpose=get&name=ann" "${SAME[@]}"
	ch=$(tr -d '\r\n' < "$last.body")
	form=$(python3 -I "$auth" get "$pk" "$ch" "https://evil.example" "$pkrp" 2)
	post "client data of another origin is refused" 401 "/passkey/login" "^passkey refused$" "$sp" "csrf=$cp&$form" "${SAME[@]}"
	post "a new challenge" 200 "/passkey/challenge" "^[A-Za-z0-9_-]{43}$" "$sp" "csrf=$cp&purpose=get&name=ann" "${SAME[@]}"
	ch=$(tr -d '\r\n' < "$last.body")
	form=$(python3 -I "$auth" get "$pk" "$ch" "$ORIGIN" "$pkrp" 2 1)
	post "a user present but not verified is refused" 401 "/passkey/login" "^passkey refused$" "$sp" "csrf=$cp&$form" "${SAME[@]}"
	post "a new challenge" 200 "/passkey/challenge" "^[A-Za-z0-9_-]{43}$" "$sp" "csrf=$cp&purpose=get&name=ann" "${SAME[@]}"
	ch=$(tr -d '\r\n' < "$last.body")
	form=$(python3 -I "$auth" get "$pk" "$ch" "$ORIGIN" "$pkrp" 2)
	post "the control: counter 2 from the right origin passes" 303 "/passkey/login" "^Location: /$" "$sp" "csrf=$cp&$form" "${SAME[@]}"
	(cd "$D" && ./login passkey-off ann) > "$D/passkey-off.out" 2>&1
	check "login passkey-off ann" grep -qx "login: passkeys removed" "$D/passkey-off.out"
	(cd "$D" && ./login passkey-off ann) > "$D/passkey-off-again.out" 2>&1
	check "a second passkey-off finds none" grep -q "refused: the user has no passkey" "$D/passkey-off-again.out"
	expect "a login page after passkey-off" 200 "/login" 'name="csrf"'
	sp=$(cookie_of)
	cp=$(csrf_of)
	post "a challenge after passkey-off" 200 "/passkey/challenge" "^[A-Za-z0-9_-]{43}$" "$sp" "csrf=$cp&purpose=get&name=ann" "${SAME[@]}"
	ch=$(tr -d '\r\n' < "$last.body")
	form=$(python3 -I "$auth" get "$pk" "$ch" "$ORIGIN" "$pkrp" 3)
	post "the removed passkey logs nobody in" 401 "/passkey/login" "^passkey refused$" "$sp" "csrf=$cp&$form" "${SAME[@]}"
	# The refusal counts as a failure of the client; a login clears it, so
	# that the throttling below starts from none.
	post "ann logs in with her password, which clears the failures" 303 "/login" "^Location: /$" "$sp" "csrf=$cp&name=ann&password=$PASSWORD" "${SAME[@]}"
	check "the audit has the passkey login of ann" grep -q '"msg":"login-passkey".*"user":"ann".*"outcome":"ok"' "$D/audit.log"
	check "and its refusals, without a name" grep -q '"msg":"login-passkey".*"outcome":"refused"' "$D/audit.log"

	echo "== deluser takes the second factor and the passkeys along"
	# gus holds both, which cid above did not.
	local sf cf sf2 cf2 sfs fsecret fcode pkf="$D/passkey-gus.pem"
	rows_of() {
		python3 -I -c 'import sqlite3, sys
db = sqlite3.connect(sys.argv[1], timeout=30)
print(db.execute("SELECT count(*) FROM " + {"totp": "wolly_totp", "passkeys": "wolly_passkeys"}[sys.argv[2]] + " WHERE name = ?", (sys.argv[3],)).fetchone()[0])' "$D/wolly.db" "$1" "$2"
	}
	(cd "$D" && printf '%s\n' "$PASSWORD" | ./login adduser gus) > "$D/adduser-gus.out" 2>&1
	check "gus is added" grep -qx "login: user added" "$D/adduser-gus.out"
	expect "a login page for gus" 200 "/login" 'name="csrf"'
	sf=$(cookie_of)
	cf=$(csrf_of)
	post "gus logs in" 303 "/login" "^Location: /$" "$sf" "csrf=$cf&name=gus&password=$PASSWORD" "${SAME[@]}"
	sfs=$(cookie_of)
	expect "gus asks for the second factor" 200 "/totp" 'class="secret"' -b "__Host-wolly=$sfs"
	fsecret=$(sed -n 's/.*<code class="secret">\([A-Z2-7]\{32\}\)<\/code>.*/\1/p' "$last.body" | head -1)
	cf2=$(csrf_of)
	fcode=$(totp_code "$fsecret" 0)
	post "gus turns it on" 200 "/totp" "^two-factor is on$" "$sfs" "csrf=$cf2&code=$fcode" "${SAME[@]}"
	openssl ecparam -name prime256v1 -genkey -noout -out "$pkf" 2> /dev/null
	post "a challenge for a passkey of gus" 200 "/passkey/challenge" "^[A-Za-z0-9_-]{43}$" "$sfs" "csrf=$cf2&purpose=create" "${SAME[@]}"
	ch=$(tr -d '\r\n' < "$last.body")
	form=$(python3 -I "$auth" create "$pkf" "$ch" "$ORIGIN" "$pkrp")
	post "gus registers a passkey" 201 "/passkey/register" "^passkey kept$" "$sfs" "csrf=$cf2&password=$PASSWORD&$form" "${SAME[@]}"
	check "the database holds the seed of gus" [ "$(rows_of totp gus)" = 1 ]
	check "and the passkey of gus" [ "$(rows_of passkeys gus)" = 1 ]
	(cd "$D" && ./login deluser gus) > "$D/deluser-gus.out" 2>&1
	check "login deluser gus" grep -q "^login: user removed" "$D/deluser-gus.out"
	check "no seed of gus is left" [ "$(rows_of totp gus)" = 0 ]
	check "nor a passkey of gus" [ "$(rows_of passkeys gus)" = 0 ]
	(cd "$D" && printf '%s\n' "$PASSWORD" | ./login adduser gus) > "$D/adduser-fay2.out" 2>&1
	check "gus is added again" grep -qx "login: user added" "$D/adduser-fay2.out"
	expect "a login page for the new gus" 200 "/login" 'name="csrf"'
	sf2=$(cookie_of)
	cf=$(csrf_of)
	post "a challenge to log in as the new gus" 200 "/passkey/challenge" "^[A-Za-z0-9_-]{43}$" "$sf2" "csrf=$cf&purpose=get&name=gus" "${SAME[@]}"
	ch=$(tr -d '\r\n' < "$last.body")
	form=$(python3 -I "$auth" get "$pkf" "$ch" "$ORIGIN" "$pkrp" 2)
	post "the passkey of the old gus is refused" 401 "/passkey/login" "^passkey refused$" "$sf2" "csrf=$cf&$form" "${SAME[@]}"
	post "the new gus logs in with the password alone, no code asked" 303 "/login" "^Location: /$" "$sf2" "csrf=$cf&name=gus&password=$PASSWORD" "${SAME[@]}"

	echo "== logout"
	post "logout without the token" 403 "/logout" "^forbidden$" "$s2" "x=1" "${SAME[@]}"
	post "logout" 303 "/logout" "^Set-Cookie: __Host-wolly=; Path=/; Max-Age=0" "$s2" "csrf=$c2" "${SAME[@]}"
	expect "after the logout the token opens nothing" 303 "/" "^Location: /login$" -b "__Host-wolly=$s2"

	if [ "$SCHEME" = https ]; then
		echo "== over TLS"
		# curl keeps a __Host- cookie only from a secure answer, as a browser
		# does; the jar is the client that a plain -b would hide.
		expect "the login page, into a cookie jar" 200 "/login" 'name="csrf"' -c "$D/jar"
		check "the jar keeps the __Host- cookie of the https answer" grep -q "__Host-wolly" "$D/jar"
		local s4 c4
		s4=$(cookie_of)
		c4=$(csrf_of)
		expect "the jar sends it back" 200 "/login" "^Set-Cookie: __Host-wolly=$s4;" -b "$D/jar"
		post "an http Origin on a request over TLS, with the token" 403 "/login" "^forbidden$" "$s4" "csrf=$c4&name=ann&password=$PASSWORD" -H "Origin: http://127.0.0.1:$PORT"
		post "the control: the https Origin, with the token" 303 "/login" "^Location: /$" "$s4" "csrf=$c4&name=ann&password=$PASSWORD" -H "Origin: $ORIGIN"
	fi

	echo "== throttling"
	expect "a new login page" 200 "/login" 'name="csrf"'
	local s3 c3 i
	s3=$(cookie_of)
	c3=$(csrf_of)
	for i in 1 2 3 4 5; do
		post "failure $i" 401 "/login" "login refused: ann" "$s3" "csrf=$c3&name=ann&password=wrong+password+$i" "${SAME[@]}"
	done
	post "the sixth try, with the right password, is throttled" 429 "/login" "^Retry-After: 900$" "$s3" "csrf=$c3&name=ann&password=$PASSWORD" "${SAME[@]}"

	echo "== what is kept"
	check "the audit has a login" grep -q '"msg":"login".*"outcome":"ok"' "$D/audit.log"
	check "the audit has refusals" grep -q '"outcome":"refused"' "$D/audit.log"
	check "the audit has the throttling" grep -q '"outcome":"throttled"' "$D/audit.log"
	check "the audit has the logout" grep -q '"msg":"logout".*"user":"ann"' "$D/audit.log"
	check "the control: the audit names the user" grep -q '"user":"ann"' "$D/audit.log"
	check "the audit holds no password" bash -c "! grep -q -e 'correct horse' -e 'wrong password' '$D/audit.log'"
	check "the audit holds no session token" bash -c "! grep -q -e '$s1' -e '$s2' '$D/audit.log'"
	check "the access log has the login" grep -qE '"msg":"request","method":"POST","path":"/login","client":"[^"]+","status":303' "$D/access.log"
	check "the access log has the answer of a step before" grep -qE '"method":"QUERY","path":"/login","client":"[^"]+","status":405' "$D/access.log"
	check "the access log has the throttling" grep -qE '"method":"POST","path":"/login","client":"[^"]+","status":429' "$D/access.log"
	check "the control: a GET of the page is in the access log" grep -qE '"method":"GET","path":"/login","client":"[^"]+","status":200' "$D/access.log"
	check "TRACE, which Hiawatha answers, is not in the access log" bash -c "! grep -q '\"method\":\"TRACE\"' '$D/access.log'"
	check "the access log holds no query" bash -c "! grep -q -e 's3cr3t' -e 'next=' '$D/access.log'"
	check "the access log holds no session token" bash -c "! grep -q -e '$s1' -e '$s2' '$D/access.log'"
	check "the control: the database holds the user" grep -qa "ann" "$D/wolly.db"
	check "the database holds no session token" bash -c "! grep -qsa -e '$s1' -e '$s3' '$D/wolly.db' '$D/wolly.db-wal'"

	echo "== the request id, and the access log renamed by a rotation"
	local rid rid2
	expect "an answer carries a request id" 200 "/login" "^X-Request-Id: [0-9a-f]{32}$"
	rid=$(tr -d '\r' < "$last.head" | sed -n 's/^X-Request-Id: \([0-9a-f]\{32\}\)$/\1/p')
	check "the access log has the line of that answer" grep -q "\"request_id\":\"$rid\"" "$D/access.log"
	mv "$D/access.log" "$D/access.log.1"
	expect "a request after the rename" 200 "/login" "^X-Request-Id: [0-9a-f]{32}$"
	rid2=$(tr -d '\r' < "$last.head" | sed -n 's/^X-Request-Id: \([0-9a-f]\{32\}\)$/\1/p')
	check "two requests, two ids" bash -c "[ -n '$rid2' ] && [ '$rid' != '$rid2' ]"
	check "its line goes into a new access.log" grep -q "\"request_id\":\"$rid2\"" "$D/access.log"
	check "and not into the renamed one" bash -c "! grep -q '$rid2' '$D/access.log.1'"

	echo "== the limit on POST, 100 in 60 seconds per client"
	# POST /logout without a session is cheap (the guard refuses it), and
	# it counts like every POST.  The access log has every POST of the run,
	# the two answered 429 by the limit below included: they are its last
	# two.  Only the POSTs in the window count: Wolly.Limit keeps a call
	# while its second is above the second of now less 60, and a call it
	# refuses is none it keeps; a 429 of the throttling of the login is a
	# call the limit let through.  So exactly 100 POSTs before the first
	# 429 of the limit lie in the 60 seconds before it, however long the run
	# took to get here (under valgrind and load more than 60 seconds; then
	# the log has more than 102 POSTs).
	# The log takes its time a little after the limit does: a POST in the
	# very second at the edge of the window could be counted one second late.
	local n=0 got=000 posts
	while [ $n -lt 150 ]; do
		n=$((n + 1))
		got=$(curl -s "${CURL_TLS[@]}" -D "$D/out/limit.head" -o /dev/null -w '%{http_code}' --max-time "$MAXTIME" --data-binary x "$BASE/logout")
		[ "$got" = 429 ] && break
	done
	check "a POST past the limit gets 429 (after $n in this loop)" [ "$got" = 429 ]
	posts=$(cat "$D/access.log.1" "$D/access.log" | grep -c '"method":"POST"')
	local inside
	# What the limit holds is read from its table, not counted from the
	# seconds of the access log: the log is written a little after the limit
	# counts, so under valgrind a POST at the edge of the window is in the
	# one and out of the other.  The table keeps the calls still in the window
	# (a refused call is not kept), so after the first 429 it holds exactly the limit, 100, for the
	# client of this run, and it changes only with a call: so it is read before
	# the next one, which would drop what left the window meanwhile.
	inside=$(python3 -I -c 'import sqlite3, sys
db = sqlite3.connect("file:" + sys.argv[1] + "?mode=ro", uri=True, timeout=30)
rows = db.execute("SELECT key, count(*) FROM wolly_hits WHERE scope = ? GROUP BY key", ("post",)).fetchall()
print(rows[0][1] if len(rows) == 1 else "keys:%d" % len(rows))' "$D/wolly.db")
	check "the limit holds exactly 100 calls in its window after the first 429 ($inside in wolly_hits, $posts POSTs in the log)" [ "$inside" = 100 ]
	# The wait is read from the first 429 itself, not from a call after it:
	# when the 100 calls take close to 60 seconds (OpenBSD in a virtual
	# machine), the oldest leaves the window before
	# a next call, which is then let through to the form guard.
	check "the refused one says when to come back" bash -c "tr -d '\r' < '$D/out/limit.head' | grep -qE '^Retry-After: [1-9][0-9]?\$'"
	expect "the control: a GET is not limited" 200 "/login" 'name="csrf"'

	echo "== pseudonyms of the client"
	check "pseudonym.key is made with mode 600" [ "$(mode_of "$D/pseudonym.key")" = 600 ]
	check "the audit names the client by a pseudonym of 64 hex digits" grep -qE '"client":"[0-9a-f]{64}"' "$D/audit.log"
	check "the audit holds no address" bash -c "! grep -q '127.0.0.1' '$D/audit.log'"
	check "the database, its failures and its counts, holds no address" bash -c "! grep -qsa '127.0.0.1' '$D/wolly.db' '$D/wolly.db-wal'"
	check "the control: the database holds the pseudonym of the audit" bash -c "p=\$(grep -oE '\"client\":\"[0-9a-f]{64}\"' '$D/audit.log' | head -1 | cut -c11-74); [ \${#p} -eq 64 ] && grep -qsa \"\$p\" '$D/wolly.db' '$D/wolly.db-wal'"
	check "the control: the access log of Wolly.Middleware names the address" grep -q '"client":"127.0.0.1"' "$D/access.log"
}
