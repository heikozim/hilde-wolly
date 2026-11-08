# The cases of scripts/e2e.sh against examples/contact, sourced there.  A
# stamp is good from 3 seconds after it was made, so the run waits that
# long twice; the limit is 3 checked messages of a client in 600 seconds.
ORIGIN=$BASE
SAME=(-H "Sec-Fetch-Site: same-origin" -H "Origin: $ORIGIN")

# The value of the hidden field $1 in the page of the last answer.
hidden_of() { sed -n "s/.*name=\"$1\" value=\"\([0-9a-f]*\)\".*/\1/p" "$last.body" | head -1; }
# The count of kept messages on the form page of the last answer.
count_of() { sed -n 's/.*<p class="count">messages: \([0-9]*\)<\/p>.*/\1/p' "$last.body" | head -1; }

# A fresh form: its stamp in the globals t, n and m.
fresh() {
	expect "$1" 200 "/contact" 'name="form_mac" value="[0-9a-f]{64}"'
	t=$(hidden_of form_time)
	n=$(hidden_of form_nonce)
	m=$(hidden_of form_mac)
}
# send <name> <status> <pattern> <form> [curl args]
send() {
	local name=$1 status=$2 pattern=$3 form=$4
	shift 4
	expect "$name" "$status" "/contact" "$pattern" --data-raw "$form" "$@"
}
kept() {
	expect "the page" 200 "/contact" "messages: "
	[ "$(count_of)" = "$1" ]
}

app_cases() {
	local t n m t1 n1 m1 ta na ma tb nb mb
	echo "== prepared"
	expect "the form" 200 "/contact" '<p class="count">messages: 0</p>'
	check "form.key is made with mode 600" [ "$(mode_of "$D/form.key")" = 600 ]
	check "the honeypot is in the page, hidden" grep -q '<div hidden><label>Website <input name="website"' "$last.body"
	check "the page allows no script" grep -q "^Content-Security-Policy: default-src 'none'" <(tr -d '\r' < "$last.head")

	echo "== a message"
	fresh "a form with a stamp"
	t1=$t n1=$n m1=$m
	send "sent at once: the answer of a success" 303 "^Location: /contact\?sent=1$" "name=ann&message=hello&form_time=$t1&form_nonce=$n1&form_mac=$m1" "${SAME[@]}"
	check "but nothing is kept" kept 0
	sleep 3
	send "after 3 seconds" 303 "^Location: /contact\?sent=1$" "name=ann&message=hello&form_time=$t1&form_nonce=$n1&form_mac=$m1" "${SAME[@]}"
	check "the message is kept" kept 1
	send "the same stamp again: the answer of a success" 303 "^Location: /contact\?sent=1$" "name=ann&message=again&form_time=$t1&form_nonce=$n1&form_mac=$m1" "${SAME[@]}"
	check "but it is not kept twice" kept 1

	echo "== what is refused"
	send "another site" 403 "^forbidden$" "name=ann&message=x&form_time=$t1&form_nonce=$n1&form_mac=$m1" -H "Sec-Fetch-Site: cross-site" -H "Origin: https://evil.example"
	local forged=${m1%?}0
	[ "$forged" = "$m1" ] && forged=${m1%?}1
	send "a forged signature" 400 "not valid" "name=ann&message=x&form_time=$t1&form_nonce=$n1&form_mac=$forged" "${SAME[@]}"
	send "another time under the signature" 400 "not valid" "name=ann&message=x&form_time=1&form_nonce=$n1&form_mac=$m1" "${SAME[@]}"
	send "no stamp" 400 "not valid" "name=ann&message=x" "${SAME[@]}"
	send "an empty message" 400 "1 to 2000 bytes" "name=ann&message=&form_time=$t1&form_nonce=$n1&form_mac=$m1" "${SAME[@]}"
	send "a name of 101 bytes" 400 "at most 100 bytes" "name=$(printf '%0101d' 0 | tr 0 a)&message=x&form_time=$t1&form_nonce=$n1&form_mac=$m1" "${SAME[@]}"
	fresh "a form for the honeypot"
	ta=$t na=$n ma=$m
	fresh "a form for the limit"
	tb=$t nb=$n mb=$m
	sleep 3
	send "a filled honeypot: the answer of a success" 303 "^Location: /contact\?sent=1$" "name=bot&message=buy&website=http://spam&form_time=$ta&form_nonce=$na&form_mac=$ma" "${SAME[@]}"
	check "the ban request never reaches the client" bash -c "! grep -qi '^X-Hiawatha-' '$last.head'"
	check "the control: the answer has its headers" grep -q '^Location: /contact?sent=1' <(tr -d '\r' < "$last.head")
	# The ban asks for 3600 seconds; BanByCGI = yes, 2 cuts it to 2.
	local banned
	banned=$(curl -s "${CURL_TLS[@]}" -o /dev/null -w '%{http_code}' --max-time "$MAXTIME" "$BASE/contact")
	check "while banned, Hiawatha drops the connection (got $banned)" [ "$banned" = 000 ]
	check "Hiawatha logs the ban, cut to 2 seconds" grep -q "Client banned for 2 seconds by CGI" "$D/log/system.log"
	sleep 3
	check "but nothing is kept, after the ban" kept 1

	echo "== the limit, 3 in 600 seconds"
	# Counted so far: the message and its replay.  The honeypot stamp is
	# still unused, the honeypot ended its check before the limit.
	send "the third checked message" 303 "^Location: /contact\?sent=1$" "name=ann&message=third&form_time=$ta&form_nonce=$na&form_mac=$ma" "${SAME[@]}"
	check "is kept" kept 2
	send "the fourth is one too many" 429 "^Retry-After: [1-9][0-9]*$" "name=ann&message=fourth&form_time=$tb&form_nonce=$nb&form_mac=$mb" "${SAME[@]}"
	check "and not kept" kept 2
	check "the control: no message holds the robot's words" bash -c "! grep -qsa 'buy' '$D/contact.db' '$D/contact.db-wal'"
	check "the control: the database holds a message" grep -qsa 'hello' "$D/contact.db" "$D/contact.db-wal"
}
