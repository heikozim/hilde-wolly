#!/usr/bin/env bash
# Runs in the build environment with a network, beside a Pebble container:
# the certificate tool (cli/acme) against Pebble, the test server of
# Let's Encrypt, in a container beside it.  Pebble asks the name
# of the order of the mock DNS of pebble-challtestsrv, which answers with
# this container; Pebble then fetches the answer of http-01 from the
# python server here on port 5002, from the webroot the tool writes into.
#
#     PEBBLE=https://pebble:14000/dir MGMT=https://pebble:15000 bash scripts/e2e-acme-live.sh
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || { echo "ABORT: bash ${BASH_VERSION} too old" >&2; exit 9; }
set -u
. scripts/env.sh
PEBBLE=${PEBBLE:?PEBBLE}
MGMT=${MGMT:?MGMT}
CA=$WOLLY/scripts/pebble/pebble.minica.pem
D=$RUN/acme-live
good=0
bad=0
ok() { good=$((good + 1)); echo "ok    $1"; }
fail() { bad=$((bad + 1)); echo "FAIL  $1"; }
# expect <what> <exit wanted> <output pattern> <command...>
expect() {
	local what=$1 want=$2 pattern=$3 out rc
	shift 3
	out=$("$@" 2>&1)
	rc=$?
	if [ $rc -eq "$want" ] && printf '%s\n' "$out" | grep -q -E -- "$pattern"; then
		ok "$what (exit $rc)"
	else
		fail "$what: exit $rc, wanted $want and /$pattern/"
		printf '%s\n' "$out" | head -8
	fi
}
for t in openssl curl python3; do
	command -v $t > /dev/null 2>&1 || { echo "ABORT: $t missing -- nothing ran" >&2; exit 9; }
done
[ -r "$CA" ] || { echo "ABORT: $CA missing" >&2; exit 9; }
CLI=1 ONLY=acme bash scripts/build.sh || { echo "ABORT: the tool did not build" >&2; exit 9; }
ACME=$RUN/bin/acme
[ -x "$ACME" ] || { echo "ABORT: $ACME missing" >&2; exit 9; }
rm -rf "$D" && mkdir -p "$D/www" || exit 9
cd "$D" || exit 9

# The server of the answers: the webroot on port 5002.
python3 -m http.server 5002 --bind 0.0.0.0 --directory "$D/www" > "$D/http.log" 2>&1 &
http_pid=$!
trap 'kill $http_pid 2> /dev/null' EXIT
for _ in $(seq 1 50); do
	curl -s -o /dev/null "http://127.0.0.1:5002/" && break
	sleep 0.1
done
[ "$(curl -s -o /dev/null -w '%{http_code}\n' "http://127.0.0.1:5002/")" != 000 ] || { echo "ABORT: the answer server did not start" >&2; exit 9; }

expect "a new key" 0 "key written" "$ACME" newkey acct.key
expect "a second key" 0 "key written" "$ACME" newkey dom.key
expect "no key over a file" 1 "could not be written" "$ACME" newkey acct.key
[ "$(stat -c %a acct.key)" = 600 ] && ok "the key is mode 0600" || fail "the key is not mode 0600"
head -1 acct.key | grep -q "BEGIN PRIVATE KEY" && ok "the key is PKCS 8 PEM" || fail "the key is no PEM"

expect "wrong arguments" 1 "usage" "$ACME" obtain a b
expect "a wildcard is refused before the server is asked" 1 "unusable" \
	"$ACME" obtain "$PEBBLE" "$CA" acct.key dom.key "$D/www" '*.test.example.org' w.pem private
expect "a server on a private address is refused without the word" 1 "account" \
	"$ACME" obtain "$PEBBLE" "$CA" acct.key dom.key "$D/www" test.example.org w.pem
[ ! -e w.pem ] && ok "no certificate written for a refusal" || fail "a certificate file for a refusal"

expect "the certificate is obtained" 0 "certificate written" \
	"$ACME" obtain "$PEBBLE" "$CA" acct.key dom.key "$D/www" test.example.org chain.pem private
[ -r chain.pem ] || { echo "== answer server log"; cat http.log; echo "ABORT: no chain.pem" >&2; echo "good=$good bad=$bad"; exit 1; }
[ "$(grep -c 'BEGIN CERTIFICATE' chain.pem)" -ge 2 ] && ok "the chain holds the certificate and an issuer" || fail "the chain is short"
openssl x509 -in chain.pem -noout -ext subjectAltName 2> /dev/null | grep -q "DNS:test.example.org" && ok "the name is in the certificate" || fail "the name is not in the certificate"
[ "$(stat -c %a chain.pem)" = 644 ] && ok "the chain is mode 0644" || fail "the chain is not mode 0644"
# The key of the certificate is the domain key: the public halves agree.
a=$(openssl x509 -in chain.pem -noout -pubkey 2> /dev/null | openssl sha256)
b=$(openssl pkey -in dom.key -pubout 2> /dev/null | openssl sha256)
[ -n "$a" ] && [ "$a" = "$b" ] && ok "the certificate is for the domain key" || fail "the certificate is for another key"
# Pebble's roots: the chain verifies against the root the server shows.
curl -s --cacert "$CA" "$MGMT/roots/0" > root.pem
curl -s --cacert "$CA" "$MGMT/intermediates/0" > inter.pem
[ "$(grep -c 'BEGIN CERTIFICATE' root.pem)" = 1 ] && ok "Pebble shows its root" || fail "no root from Pebble"
awk '/BEGIN CERTIFICATE/{n++} n==1' chain.pem > leaf.pem
openssl verify -CAfile root.pem -untrusted inter.pem leaf.pem > verify.out 2>&1
grep -q "leaf.pem: OK" verify.out && ok "the leaf verifies against the root of Pebble" || { fail "the leaf does not verify"; head -3 verify.out; }
[ -z "$(ls -A "$D/www/.well-known/acme-challenge" 2> /dev/null)" ] && ok "the answer file is gone after the verdict" || fail "an answer file stayed"
grep -q "GET /.well-known/acme-challenge/" http.log && ok "Pebble fetched the answer over http" || fail "no fetch of the answer in the log"

# Pebble picks a profile for each order, a validity of 90 days or of 6, so
# the answer for its certificate follows the certificate; two certificates
# made here, 90 days and 5, are the controls that must give both answers.
echo "== the certificate ends $(openssl x509 -in chain.pem -noout -enddate 2> /dev/null | sed 's/^notAfter=//'), now $(date -u)"
if openssl x509 -in chain.pem -noout -checkend 2592000 > /dev/null 2>&1; then want="^not due"; else want="^due"; fi
expect "the answer for the certificate of Pebble follows its end" 0 "$want" "$ACME" due chain.pem
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout /dev/null -out long.pem -days 90 -subj /CN=long.example.org 2> /dev/null
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout /dev/null -out short.pem -days 5 -subj /CN=short.example.org 2> /dev/null
expect "a certificate of 90 days is not due" 0 "^not due" "$ACME" due long.pem
expect "a certificate of 5 days is due" 0 "^due" "$ACME" due short.pem
expect "a file that is no certificate is due" 0 "^due" "$ACME" due acct.key
expect "no certificate file" 1 "could not be read" "$ACME" due nothing.pem
expect "the account is found again, a second certificate is obtained" 0 "certificate written" \
	"$ACME" obtain "$PEBBLE" "$CA" acct.key dom.key "$D/www" second.example.org second.pem private
expect "no chain over a file" 1 "could not be written" \
	"$ACME" obtain "$PEBBLE" "$CA" acct.key dom.key "$D/www" second.example.org second.pem private
expect "a name Pebble blocks is refused by the server" 1 "new order: .*rejectedIdentifier" \
	"$ACME" obtain "$PEBBLE" "$CA" acct.key dom.key "$D/www" blocked-domain.example blocked.pem private

# A name whose answer cannot be fetched: the answer server is down.
kill $http_pid 2> /dev/null
wait $http_pid 2> /dev/null
expect "an answer nobody can fetch is found invalid" 1 "authorization: .*invalid" \
	"$ACME" obtain "$PEBBLE" "$CA" acct.key dom.key "$D/www" third.example.org third.pem private
[ -z "$(ls -A "$D/www/.well-known/acme-challenge" 2> /dev/null)" ] && ok "the answer file is gone after a failure too" || fail "an answer file stayed after a failure"

echo "e2e acme live: $good of $((good + bad)) cases good"
[ $bad -eq 0 ]
