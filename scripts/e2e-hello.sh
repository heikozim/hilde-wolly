# The cases of scripts/e2e.sh against examples/hello, sourced there.
# An actor of the fediverse: an Ed25519 key of the run, its public half
# beside the programme as actor.pem.
app_prepare() {
	openssl genpkey -algorithm ed25519 -out actor-key.pem > genpkey.out 2>&1 || { cat genpkey.out; return 1; }
	openssl pkey -in actor-key.pem -pubout -out actor.pem > pubout.out 2>&1 || { cat pubout.out; return 1; }
	# The signatures come from scripts/ed25519-sign.py: LibreSSL's openssl
	# cannot sign with Ed25519.
	openssl pkey -in actor-key.pem -outform DER -out actor-key.der > der.out 2>&1 || { cat der.out; return 1; }
	return 0
}

# signed_post <name> <status> <pattern> <body> <headers> <date> [-- extra]:
# a POST to /inbox signed with the actor's key over the headers named.
signed_post() {
	local name=$1 status=$2 pattern=$3 body=$4 headers=$5 when=$6
	local digest signing sig h
	digest="SHA-256=$(printf %s "$body" | openssl dgst -sha256 -binary | openssl base64 -A)"
	signing=""
	for h in $headers; do
		[ -n "$signing" ] && signing+=$'\n'
		case "$h" in
		"(request-target)") signing+="(request-target): post /inbox" ;;
		host) signing+="host: 127.0.0.1:$PORT" ;;
		date) signing+="date: $when" ;;
		digest) signing+="digest: $digest" ;;
		esac
	done
	printf %s "$signing" > "$D/out/signing"
	sig=$(python3 -I "$WOLLY/scripts/ed25519-sign.py" "$D/actor-key.der" "$D/out/signing")
	expect "$name" "$status" "/inbox" "$pattern" --data-binary "$body" -H "Date: $when" -H "Digest: $digest" \
		-H "Signature: keyId=\"https://actor.example/#key\",algorithm=\"hs2019\",headers=\"$headers\",signature=\"$sig\""
}

app_cases() {
	echo "== hello"
	expect "GET / is the greeting" 200 "/" "^hello, world$"
	expect "the content type" 200 "/" "^Content-Type: text/plain; charset=utf-8$"
	expect "the header the handler added" 200 "/" "^X-Content-Type-Options: nosniff$"
	expect "HEAD / is answered by the GET route" 200 "/" "^Content-Type: text/plain; charset=utf-8$" -I

	echo "== routing"
	expect "a parameter" 200 "/hello/hilde" "^hello, hilde$"
	expect "a parameter is decoded" 200 "/hello/a%20b" "^hello, a b$"
	expect "the query does not reach the pattern" 200 "/hello/x?y=1" "^hello, x$"
	expect "an empty parameter fits no route" 404 "/hello/" "^not found$"
	expect "a wildcard" 200 "/files/a/b/c" "^rest=a/b/c$"
	expect "no route: the application's 404, not Hiawatha's" 404 "/nowhere" "^not found$"
	expect "another method: 405" 405 "/visits" "^Allow: GET$" --data-binary "x"

	echo "== cookies"
	expect "the first visit sets the cookie" 200 "/visits" "^Set-Cookie: visits=1; Path=/; Secure; HttpOnly; SameSite=Strict$"
	expect "the first visit counts 1" 200 "/visits" "^visits=1$"
	expect "the cookie comes back and counts on" 200 "/visits" "^visits=42$" -b "visits=41"
	expect "the next cookie value" 200 "/visits" "^Set-Cookie: visits=42; " -b "visits=41"
	expect "among other cookies" 200 "/visits" "^visits=8$" -b "theme=dark; visits=7; x=y"
	expect "a count above the limit starts again" 200 "/visits" "^visits=1$" -b "visits=1000001"
	expect "the limit itself still counts" 200 "/visits" "^visits=1000001$" -b "visits=1000000"
	expect "a cookie that is no number starts again" 200 "/visits" "^visits=1$" -b "visits=abc"

	echo "== static files, from Hiawatha"
	expect "a file under /static/" 200 "/static/app.css" "^body\{color:red\}$"
	expect "its type from mimetype.conf" 200 "/static/app.css" "^Content-Type: text/css"
	expect "it may be cached" 200 "/static/app.css" "^Cache-Control: public$"
	expect "for a day" 200 "/static/app.css" "^Expires: "
	expect "a file below it" 200 "/static/sub/deep.css" "^deep$"
	expect "HEAD of a static file" 200 "/static/app.css" "^Content-Type: text/css" -I
	expect "a missing static file is Hiawatha's 404, not the application's" 404 "/static/missing.css" "."
	check "and not the application's" bash -c "! grep -qx 'not found' '$last.body'"
	check "the control: secret.conf is there" grep -q PEPPER "$D/www/secret.conf"
	check "the control: .hidden is there" grep -q PEPPER "$D/www/static/.hidden"
	expect "a file outside /static/ goes to the application" 404 "/secret.conf" "^not found$"
	refused "/static/../secret.conf" "/static/../secret.conf"
	refused "/static/sub/../../secret.conf" "/static/sub/../../secret.conf"
	refused "/static/./../secret.conf" "/static/./../secret.conf"
	refused "dots encoded: /static/%2e%2e/secret.conf" "/static/%2e%2e/secret.conf"
	refused "slash encoded: /static/..%2fsecret.conf" "/static/..%2fsecret.conf"
	refused "dots and slash encoded" "/static/%2e%2e%2fsecret.conf"
	refused "a dot file under /static/" "/static/.hidden"
	refused "a dot file encoded" "/static/%2ehidden"
	refused "a NUL byte" "/static/app.css%00.txt"
	check "the control: the symlink leads to the file outside" grep -q PEPPER "$D/www/static/out.css"
	refused "a symlink out of WebsiteRoot" "/static/out.css"
	refused "a directory gives no listing" "/static/sub/"
	check "and no listing" bash -c "! grep -q deep.css '$last.body'"

	echo "== pages"
	expect "the first page of numbers" 200 "/numbers" "^page 1 of 3$"
	check "it holds 1 to 20" bash -c "grep -qx 1 '$last.body' && grep -qx 20 '$last.body' && ! grep -qx 21 '$last.body'"
	expect "the second page" 200 "/numbers?page=2" "^page 2 of 3$"
	check "it holds 21 to 40" bash -c "grep -qx 21 '$last.body' && grep -qx 40 '$last.body' && ! grep -qx 20 '$last.body' && ! grep -qx 41 '$last.body'"
	expect "a page past the last is the last" 200 "/numbers?page=99" "^page 3 of 3$"
	check "it holds 41 to 45, and no more" bash -c "[ \$(grep -c -x '[0-9]*' '$last.body') = 5 ] && grep -qx 45 '$last.body'"
	expect "no number is the first page" 200 "/numbers?page=x" "^page 1 of 3$"
	expect "page 0 is the first page" 200 "/numbers?page=0" "^page 1 of 3$"

	echo "== many at once"
	local i p many=() manygood=0
	for ((i = 1; i <= 10; i++)); do
		curl -s "${CURL_TLS[@]}" -o "$D/out/many-$i" -w '%{http_code}' --max-time "$MAXTIME" "$BASE/hello/n$i" > "$D/out/many-$i.code" &
		many+=($!)
	done
	for p in "${many[@]}"; do wait "$p"; done
	for ((i = 1; i <= 10; i++)); do
		[ "$(cat "$D/out/many-$i.code")" = 200 ] && grep -qx "hello, n$i" "$D/out/many-$i" && manygood=$((manygood + 1))
	done
	check "ten at once, each with its own answer ($manygood of 10)" [ "$manygood" -eq 10 ]

	echo "== asset versions"
	local want
	want=$(openssl dgst -sha256 -binary "$D/www/static/app.css" | od -An -tx1 | tr -d ' \n' | cut -c1-16)
	check "the digest of app.css is known" [ ${#want} -eq 16 ]
	expect "the version of app.css is the start of its SHA-256" 200 "/asset?path=/static/app.css" "^\\?v=$want$"
	expect "a file in a subdirectory" 200 "/asset?path=/static/sub/deep.css" "^\\?v=[0-9a-f]{16}$"
	check "two files, two versions" bash -c "! grep -q '$want' '$last.body'"
	expect "the control: Hiawatha serves the file that is versioned" 200 "/static/app.css" "^body\\{color:red\\}$"
	expect "a way up is refused" 404 "/asset?path=/static/../secret.conf" "^no such asset$"
	expect "a way up, percent-encoded, is refused" 404 "/asset?path=%2Fstatic%2F..%2Fsecret.conf" "^no such asset$"
	expect "a dot file is refused" 404 "/asset?path=/static/.hidden" "^no such asset$"
	expect "a symlink out of the root is refused" 404 "/asset?path=/static/out.css" "^no such asset$"
	expect "a missing file has no version" 404 "/asset?path=/static/none.css" "^no such asset$"
	expect "a directory has no version" 404 "/asset?path=/static/sub" "^no such asset$"
	expect "no path" 400 "/asset" "^the parameter path is missing$"
	check "no answer holds the secret" bash -c "! grep -rq -e PEPPER '$D/out'"

	echo "== QR codes"
	expect "the code of an otpauth URI" 200 "/qr?text=otpauth%3A%2F%2Ftotp%2FWolly%3Aann%3Fsecret%3DJBSWY3DPEHPK3PXP" "^data:image/png;base64,iVBORw0KGgo"
	sed 's/^data:image\/png;base64,//' "$last.body" | openssl base64 -d -A > "$D/out/qr.png" 2> /dev/null
	check "the URI holds a PNG" bash -c "od -An -tx1 -N 8 '$D/out/qr.png' | tr -d ' \n' | grep -qx 89504e470d0a1a0a"
	# The side from the IHDR chunk: bytes 16 to 23 are width and height.
	local side
	side=$(python3 -I -c "import struct,sys; d=open(sys.argv[1],'rb').read(); w,h=struct.unpack('>II', d[16:24]); print(w if w == h else 0)" "$D/out/qr.png")
	check "a square of 4 pixels a module, 8 modules of quiet zone and a version above 1 for 55 bytes ($side)" bash -c "[ \$(( $side % 4 )) -eq 0 ] && [ \$(( $side / 4 - 8 - 17 )) -gt 4 ] && [ \$(( ($side / 4 - 8 - 17) % 4 )) -eq 0 ]"
	expect "a short text, version 1: 116 pixels" 200 "/qr?text=hello" "^data:image/png;base64,"
	sed 's/^data:image\/png;base64,//' "$last.body" | openssl base64 -d -A > "$D/out/qr1.png" 2> /dev/null
	side=$(python3 -I -c "import struct,sys; d=open(sys.argv[1],'rb').read(); w,h=struct.unpack('>II', d[16:24]); print(w if w == h else 0)" "$D/out/qr1.png")
	check "hello is 116 pixels on a side ($side)" [ "$side" = 116 ]
	expect "no text" 400 "/qr" "^the parameter text is missing$"

	echo "== a Bunti code"
	# The picture of the page is the one of demo/, made by cli/buntipng from
	# the same text at the same scale: byte for byte, by the SHA-256 that
	# demo/README.md gives (the mutation runs copy no demo/).
	expect "the Bunti page of a text" 200 "/bunti?text=Wolly" '^<img alt="the Bunti code of the text" src="data:image/png;base64,iVBORw0KGgo'
	check "Wolly.BuntiScan reads Wolly back from the picture" grep -qx '<p class="read">read back from the picture: yes</p>' "$last.body"
	check "21 cells on a side" grep -qx '<p class="cells">cells on a side: 21</p>' "$last.body"
	python3 -I -c 'import base64, re, sys; m = re.search(r"base64,([A-Za-z0-9+/=]+)", open(sys.argv[1]).read()); open(sys.argv[2], "wb").write(base64.b64decode(m.group(1)) if m else b"")' "$last.body" "$D/out/bunti-wolly.png"
	check "the picture is demo/bunti-wolly.png byte for byte" [ "$(python3 -I -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$D/out/bunti-wolly.png")" = 76d8da969afd045dcf832b02aa77e6182ac6ea9dd101994490092ba29335a40c ]
	expect "a sentence of the demo" 200 "/bunti?text=Wolly%20ist%20ein%20Web-Framework%20in%20Hilde%3A%20Formulare%2C%20Sitzungen%2C%20Bilder%20und%20dieser%20Farbcode%2C%20Bunti%2C%20den%20eine%20Kamera%20liest." '^<p class="cells">cells on a side: 33</p>$'
	check "it is read back too" grep -qx '<p class="read">read back from the picture: yes</p>' "$last.body"
	python3 -I -c 'import base64, re, sys; m = re.search(r"base64,([A-Za-z0-9+/=]+)", open(sys.argv[1]).read()); open(sys.argv[2], "wb").write(base64.b64decode(m.group(1)) if m else b"")' "$last.body" "$D/out/bunti-satz.png"
	check "and its picture is demo/bunti-satz.png" [ "$(python3 -I -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$D/out/bunti-satz.png")" = 28cc19a642cf5f7329394bf4e0ceb5efb6ffd877351c23fdc3eaa96d4644367b ]
	expect "images from data URIs and nothing else" 200 "/bunti?text=Wolly" "^Content-Security-Policy: default-src 'none'; img-src data:$"
	expect "the text is escaped" 200 "/bunti?text=%3Cb%3Ex%3C%2Fb%3E" '^<p class="text">&lt;b&gt;x&lt;/b&gt;</p>$'
	check "and is nowhere a tag" bash -c "! grep -q '<b>' '$last.body'"
	expect "no text" 400 "/bunti" "^the parameter text is missing$"


	echo "== fields"
	expect "an address and a date" 200 "/check?email=ann%40example.com&date=2024-02-29" "^email: yes$"
	check "and the date of a leap year" grep -qx "date: yes" "$last.body"
	expect "no address, no date of a common year" 200 "/check?email=ann%40example&date=2023-02-29" "^email: no$"
	check "the 29th of February 2023 is none" grep -qx "date: no" "$last.body"
	expect "two @ and a month 13" 200 "/check?email=a%40b%40example.com&date=2024-13-01" "^email: no$"
	check "month 13 is none" grep -qx "date: no" "$last.body"
	expect "without the parameters" 200 "/check" "^email: none$"
	check "and no date either" grep -qx "date: none" "$last.body"

	echo "== names by their sound"
	expect "Müller-Lüdenscheidt in UTF-8" 200 "/sound?name=M%C3%BCller-L%C3%BCdenscheidt" "^cologne: 65752682$"
	check "and its Soundex" grep -qx "soundex: M464" "$last.body"
	expect "Meyer sounds like Meier" 200 "/sound?name=Meyer" "^cologne: 67$"
	expect "Ashcroft" 200 "/sound?name=Ashcroft" "^soundex: A261$"
	expect "a name without letters" 200 "/sound?name=42" "^cologne: $"
	expect "no name" 400 "/sound" "^the parameter name is missing$"
	expect "a name of 101 bytes" 413 "/sound?name=$(printf '%0101d' 0 | tr 0 a)" "^the name is too long$"
	expect "the control: 100 bytes" 200 "/sound?name=$(printf '%0100d' 0 | tr 0 a)" "^cologne: 0$"

	echo "== a chart"
	expect "three counts" 200 "/stats?values=1500000,1234,7" "^median 1234$"
	check "each as people read it, with its bar" bash -c "printf 'median 1234\\n1.5 M 100%%\\n1.2 k 0%%\\n7 0%%\\n' | cmp -s - '$last.body'"
	expect "an even number: the mean of the middle two" 200 "/stats?values=4,1,3,2" "^median 2$"
	check "4 is the largest, 2 half of it" grep -qx "2 50%" "$last.body"
	expect "what is no number is left out" 200 "/stats?values=10,x,-3,30" "^median 20$"
	check "two bars" bash -c "[ \$(grep -c '%$' '$last.body') = 2 ]"
	expect "no values" 200 "/stats" "^median 0$"

	echo "== markdown"
	# Without a line feed in the URL: Hiawatha answers that itself with 403
	# so a page of two blocks is left to the unit tests.
	expect "a heading" 200 "/markdown?text=%23+Title" "^<h1>Title</h1>$"
	check "the page may run no script" grep -q "^Content-Security-Policy: default-src 'none'" <(tr -d '\r' < "$last.head")
	expect "strong text" 200 "/markdown?text=a+**b**" "^<p>a <strong>b</strong></p>$"
	expect "a script tag is shown, not obeyed" 200 "/markdown?text=%3Cscript%3Ealert(1)%3C%2Fscript%3E" "^<p>&lt;script&gt;alert\\(1\\)&lt;/script&gt;</p>$"

	echo "== code, highlighted"
	expect "Go: a keyword in its span" 200 "/code?file=main.go&text=func+main()" '^<pre class="code"><span class=kw>func</span> main<span class=st>\(</span><span class=st>\)</span></pre>$'
	expect "a string of Go with a tag in it, escaped" 200 "/code?file=a.go&text=x+%3D+%22%3Cb%3E%22" '^<pre class="code">x <span class=op>=</span> <span class=st>&#34;&lt;b&gt;&#34;</span></pre>$'
	check "and never as a tag" bash -c "! grep -q '<b>' '$last.body'"
	expect "a file of no language is only escaped" 200 "/code?file=notes.txt&text=%3Cscript%3E" '^<pre class="code">&lt;script&gt;</pre>$'
	expect "no text" 400 "/code?file=a.go" "^the parameter text is missing$"
	check "and is nowhere a tag" bash -c "! grep -q '<script' '$last.body'"
	expect "a javascript: link is no link" 200 "/markdown?text=%5Bx%5D(javascript%3Aalert(1))" "^<p>\\[x\\]\\(javascript:alert\\(1\\)\\)</p>$"
	check "no anchor at all" bash -c "! grep -q '<a' '$last.body'"
	expect "the control: a safe link is one" 200 "/markdown?text=%5Bhome%5D(%2F)" '^<p><a href="/">home</a></p>$'
	expect "no text" 400 "/markdown" "^the parameter text is missing$"

	echo "== a feed"
	expect "the feed" 200 "/feed.atom" "^Content-Type: application/atom\\+xml; charset=utf-8$"
	check "an XML parser reads it: Atom, two entries, the titles as written" python3 -I -c 'import sys, xml.etree.ElementTree as ET
a = "{http://www.w3.org/2005/Atom}"
root = ET.parse(sys.argv[1]).getroot()
entries = root.findall(a + "entry")
titles = [e.find(a + "title").text for e in entries]
ok = root.tag == a + "feed" and root.find(a + "title").text == "Hello & news" and len(entries) == 2 and titles == ["Numbers <in pages>", "Visits"] and entries[0].find(a + "updated").text == "2025-10-14T12:00:00Z"
sys.exit(0 if ok else 1)' "$last.body"
	check "the control: the title is escaped in the bytes" grep -q "<title>Numbers &lt;in pages&gt;</title>" "$last.body"

	echo "== a signed inbox"
	local now_date old_date all
	# python, not date -d: the BSDs' date has no -d.
	now_date=$(python3 -I -c 'import email.utils; print(email.utils.formatdate(usegmt=True))')
	old_date=$(python3 -I -c 'import email.utils, time; print(email.utils.formatdate(time.time() - 600, usegmt=True))')
	all="(request-target) host date digest"
	check "the signer meets RFC 8032's first test vector" python3 -I "$WOLLY/scripts/ed25519-sign.py" --vector
	# Ed25519 is deterministic: where openssl can sign, its signature is the
	# signer's, byte for byte.
	printf %s "date: $now_date" > "$D/out/signing-x"
	if openssl pkeyutl -sign -inkey "$D/actor-key.pem" -rawin -in "$D/out/signing-x" -out "$D/out/signing-x.sig" 2> /dev/null; then
		check "the signer and openssl agree" [ "$(openssl base64 -A < "$D/out/signing-x.sig")" = "$(python3 -I "$WOLLY/scripts/ed25519-sign.py" "$D/actor-key.der" "$D/out/signing-x")" ]
	else
		echo "NOT RUN  the signer and openssl agree: this openssl cannot sign with Ed25519"
	fi
	signed_post "a signed request" 202 "^signed by https://actor.example/#key$" '{"type":"Follow"}' "$all" "$now_date"
	signed_post "date not signed" 401 "^malformed$" '{"type":"Follow"}' "(request-target) host digest" "$now_date"
	signed_post "a date ten minutes old" 401 "^stale$" '{"type":"Follow"}' "$all" "$old_date"
	expect "no signature" 401 "/inbox" "^not signed$" --data-binary x
	# The signature of one body over another: the digest of the header is
	# the first body's, so the second does not fit it.
	local sig_now digest_a
	digest_a="SHA-256=$(printf %s 'a' | openssl dgst -sha256 -binary | openssl base64 -A)"
	printf '%s\n%s\n%s\n%s' "(request-target): post /inbox" "host: 127.0.0.1:$PORT" "date: $now_date" "digest: $digest_a" > "$D/out/signing-a"
	sig_now=$(python3 -I "$WOLLY/scripts/ed25519-sign.py" "$D/actor-key.der" "$D/out/signing-a")
	expect "another body under the same signature" 401 "/inbox" "^digest mismatch$" --data-binary b -H "Date: $now_date" -H "Digest: $digest_a" \
		-H "Signature: keyId=\"k\",headers=\"$all\",signature=\"$sig_now\""
	expect "the control: the body it was made for" 202 "/inbox" "^signed by k$" --data-binary a -H "Date: $now_date" -H "Digest: $digest_a" \
		-H "Signature: keyId=\"k\",headers=\"$all\",signature=\"$sig_now\""
	expect "a signature of another request" 401 "/inbox" "^forged$" --data-binary a -H "Date: $now_date" -H "Digest: $digest_a" -H "Host: 127.0.0.1:1" \
		-H "Signature: keyId=\"k\",headers=\"$all\",signature=\"$sig_now\""
}
