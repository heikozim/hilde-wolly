#!/usr/bin/env bash
# Runs inside the build image: one example behind a Hiawatha of its own, both
# started here in _run/e2e-<app>-<scheme> and stopped again.  Every case asks
# Hiawatha with curl on 127.0.0.1:$PORT.  With TLS=1 Hiawatha speaks only
# TLS there, with a certificate made here for the run, and every case asks
# over https; the cases see the scheme in $SCHEME.
#
#     bash scripts/e2e.sh <app>            # after scripts/build.sh
#     TLS=1 bash scripts/e2e.sh <app>
#     WRAP="valgrind --error-exitcode=66" bash scripts/e2e.sh <app>
#     INSTRUMENTED=1 bash scripts/e2e.sh <app>   # a build of ASan or TSan
#
# The cases are in scripts/e2e-<app>.sh: a function app_cases, and an
# optional app_prepare that runs in the working directory of the app
# before it starts.  The last case is the control: with the application
# stopped Hiawatha must answer 503, so that the answers before it are the
# application's and not the web server's.
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || { echo "ABORT: bash ${BASH_VERSION} too old" >&2; exit 9; }
set -u
. scripts/env.sh
APP=${1:?app}
PORT=${PORT:-18493}
SCHEME=http
CURL_TLS=()
if [ "${TLS:-0}" = 1 ]; then
	SCHEME=https
	# The certificate is made for this run; -k takes it without a CA.
	CURL_TLS=(-k)
	command -v openssl > /dev/null 2>&1 || { echo "ABORT: openssl not on PATH -- nothing ran" >&2; exit 9; }
fi
BASE="$SCHEME://127.0.0.1:$PORT"
# WRAP runs the application under a tool, valgrind for one.  The waits grow
# with it: for its socket (tenths of a second), for an answer of curl
# (seconds), and Hiawatha's TimeForCGI (seconds, 5 is its default), since
# under valgrind on a BSD guest a login with Argon2 outlived the 5 s.  So
# do they with INSTRUMENTED=1, an application built with a sanitizer: under
# ThreadSanitizer on a busy host the sentence of the Bunti demo can outlive
# the 5 s (CGI application timeout, status 500).  Under valgrind the
# sentence takes 14 to 16 s at a load of 3 and more than 60 s at a load of
# 14, so the waits leave five times that.
read -r -a APP_WRAP <<< "${WRAP:-}"
APP_WAIT=50 MAXTIME=10 CGI_TIME=5
if [ ${#APP_WRAP[@]} -gt 0 ] || [ "${INSTRUMENTED:-0}" = 1 ]; then
	APP_WAIT=600 MAXTIME=320 CGI_TIME=300
fi

[ -x "$RUN/bin/$APP" ] || { echo "ABORT: $RUN/bin/$APP missing -- scripts/build.sh builds it" >&2; exit 9; }
[ -r "scripts/e2e-$APP.sh" ] || { echo "ABORT: scripts/e2e-$APP.sh missing" >&2; exit 9; }
port_free "$PORT"
D=$RUN/e2e-$APP-$SCHEME
# On OpenBSD the work/upload that Hiawatha makes could not be removed by
# the next run (rm: Permission denied) until its owner had the rights back.
[ -d "$D" ] && chmod -R u+rwx "$D"
rm -rf "$D" && mkdir -p "$D/config" "$D/www" "$D/log" "$D/work" "$D/out" || exit 9
cp "$MIMETYPES" "$D/config/mimetype.conf" || exit 9
tls_binding=()
if [ "${TLS:-0}" = 1 ]; then
	# Key and certificate in one file, as Hiawatha's TLScertFile wants it.
	openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -days 1 \
		-subj /CN=127.0.0.1 -addext subjectAltName=IP:127.0.0.1 \
		-keyout "$D/config/key.pem" -out "$D/config/cert.pem" > "$D/openssl.out" 2>&1 || { cat "$D/openssl.out"; exit 9; }
	cat "$D/config/key.pem" "$D/config/cert.pem" > "$D/config/tls.pem" && chmod 600 "$D/config/tls.pem" || exit 9
	tls_binding=("    TLScertFile = $D/config/tls.pem")
fi
cp "$RUN/bin/$APP" "$D/$APP" || exit 9
# The static files Hiawatha serves under /static/, and beside them what it
# must never serve: a file outside the prefix, a dot file inside it and a
# symlink inside it to a file outside WebsiteRoot.
mkdir -p "$D/www/static/sub" || exit 9
printf 'body{color:red}\n' > "$D/www/static/app.css" || exit 9
printf 'deep\n' > "$D/www/static/sub/deep.css" || exit 9
printf 'PEPPER=zzz\n' > "$D/www/secret.conf" || exit 9
printf 'PEPPER=dot\n' > "$D/www/static/.hidden" || exit 9
printf 'PEPPER=outside\n' > "$D/outside.conf" || exit 9
ln -s "$D/outside.conf" "$D/www/static/out.css" || exit 9

# SetResourceLimits = no: Hiawatha would set RLIMIT_NPROC to
# ConnectionsTotal + 3 = 153, and NPROC counts the threads of a uid across
# the machine; under rootless Docker every container of every test run is the
# same host uid, so a busy host left the next Hiawatha no thread ("pthread
# create error: Resource temporarily unavailable").
printf '%s\n' \
	"ServerString = none" \
	"SetResourceLimits = no" \
	"PidFile = $D/hiawatha.pid" \
	"WorkDirectory = $D/work" \
	"SystemLogfile = $D/log/system.log" \
	"GarbageLogfile = $D/log/garbage.log" \
	"ExploitLogfile = $D/log/exploit.log" \
	"Binding {" "    Port = $PORT" "    Interface = 127.0.0.1" "    MaxRequestSize = 64" "${tls_binding[@]}" "}" \
	"FastCGIserver {" "    FastCGIid = WOLLY" "    ConnectTo = $D/$APP.sock" "    SessionTimeout = 10" "}" \
	"Directory {" "    DirectoryID = static" "    Path = /static/" "    ExpirePeriod = 1 day, public" "}" \
	"UrlToolkit {" "    ToolkitID = all" "    Match ^/static/ Exit" "    Match .* UseFastCGI WOLLY" "}" \
	"Hostname = 127.0.0.1" \
	"BanByCGI = yes, 2" \
	"HTTPAuthToCGI = yes" \
	"TimeForCGI = $CGI_TIME" \
	"WebsiteRoot = $D/www" \
	"AccessLogfile = $D/log/access.log" \
	"ErrorLogfile = $D/log/error.log" \
	"UseToolkit = all" \
	"UseDirectory = static" > "$D/config/hiawatha.conf"

cases=0
good=0
# expect <name> <status> <path> <pattern-in-headers-and-body> [curl args...]
# The headers of the answer stay in $D/out/<n>.head for a later case.
expect() {
	local name=$1 status=$2 path=$3 pattern=$4
	shift 4
	cases=$((cases + 1))
	last="$D/out/$cases"
	local got
	got=$(curl -s "${CURL_TLS[@]}" -D "$last.head" -o "$last.body" -w '%{http_code}' --max-time "$MAXTIME" "$@" "$BASE$path")
	if [ "$got" = "$status" ] && cat "$last.head" "$last.body" | tr -d '\r' | grep -qE -- "$pattern"; then
		good=$((good + 1))
		echo "ok    $name ($got)"
	else
		echo "FAIL  $name: status $got, want $status, pattern '$pattern'"
		tr -d '\r' < "$last.head" | sed 's/^/      /'
		dd if="$last.body" bs=400 count=1 2> /dev/null | sed 's/^/      /'
		echo
	fi
}
# refused <name> <path>: anything but 200, and no line of a secret file in
# the answer.  The path goes out as it is written (--path-as-is).
refused() {
	local name=$1 path=$2
	cases=$((cases + 1))
	last="$D/out/$cases"
	local got
	got=$(curl -s "${CURL_TLS[@]}" --path-as-is -D "$last.head" -o "$last.body" -w '%{http_code}' --max-time "$MAXTIME" "$BASE$path")
	if [ "$got" != 200 ] && [ "$got" != 000 ] && ! grep -q PEPPER "$last.head" "$last.body"; then
		good=$((good + 1))
		echo "ok    $name ($got)"
	else
		echo "FAIL  $name: status $got"
		dd if="$last.body" bs=400 count=1 2> /dev/null | sed 's/^/      /'
		echo
	fi
}
# A count of its own, for a case that is not one request.
check() {
	local name=$1
	shift
	cases=$((cases + 1))
	if "$@"; then
		good=$((good + 1))
		echo "ok    $name"
	else
		echo "FAIL  $name"
	fi
}

. "$WOLLY/scripts/e2e-$APP.sh"

if declare -F app_prepare > /dev/null; then
	(cd "$D" && app_prepare) || { echo "ABORT: app_prepare failed"; exit 9; }
fi

pids=()
stop_all() {
	local p
	for p in "${pids[@]}"; do kill -TERM "$p" 2> /dev/null; done
}
trap stop_all EXIT

(cd "$D" && exec "${DETACH[@]}" "${APP_WRAP[@]}" "./$APP" > "$D/$APP.out" 2>&1 < /dev/null) &
app=$!
pids+=("$app")
for ((i = 1; i <= APP_WAIT; i++)); do
	[ -S "$D/$APP.sock" ] && break
	kill -0 "$app" 2> /dev/null || break
	sleep 0.1
done
echo "app-socket=$([ -S "$D/$APP.sock" ] && echo yes || echo no) mode=$(mode_of "$D/$APP.sock")"
if [ ${#APP_WRAP[@]} -gt 0 ]; then
	# Under a wrapper the process is the tool's (valgrind runs the programme
	# in its own process), not the application's binary.  Linux names the
	# binary in /proc, FreeBSD's ps names the command.
	exe=$(readlink "/proc/$app/exe" 2> /dev/null || ps -o comm= -p "$app")
	echo "app-exe=$exe"
	wrapped() { [ -n "$exe" ] && [ "$exe" != "$(readlink -f "$D/$APP")" ] && [ "$exe" != "$APP" ]; }
	check "the application runs under ${APP_WRAP[0]}" wrapped
fi

"${DETACH[@]}" "$HIAWATHA" -d -c "$D/config" > "$D/hiawatha.out" 2>&1 < /dev/null &
web=$!
pids+=("$web")
# At most 60 s, and done as soon as Hiawatha answers.  A refused
# connection ends curl at once, so a count of tries alone would be a few
# seconds, too short for a Hiawatha starting on a busy host.
for ((i = 1; i <= 600; i++)); do
	curl -s "${CURL_TLS[@]}" -o /dev/null --max-time 1 "$BASE/" && break
	kill -0 "$web" 2> /dev/null || break
	sleep 0.1
done
echo "hiawatha-alive=$(kill -0 "$web" 2> /dev/null && echo yes || echo no)"
if ! kill -0 "$web" 2> /dev/null; then
	# Why it did not start is in its own output and its system log.
	sed "s/^/  hiawatha.out: /" "$D/hiawatha.out" 2> /dev/null | head -20
	sed "s/^/  system.log: /" "$D/log/system.log" 2> /dev/null | head -20
fi
if [ "${TLS:-0}" = 1 ]; then
	# Without -k: the handshake must show the certificate made above, so the
	# run is over TLS and not over plain HTTP that only says https.
	check "Hiawatha speaks TLS with the certificate of the run" \
		curl -s --cacert "$D/config/cert.pem" -o /dev/null --max-time 10 "https://127.0.0.1:$PORT/"
fi

app_cases

echo "== the application stopped"
kill -TERM "$app"
wait "$app"
app_exit=$?
echo "app-exit=$app_exit"
cat "$D/$APP.out"
# A sanitizer or valgrind that found something ends the programme with
# another status, at the latest when it exits.
check "the application ends with 0 on TERM" [ "$app_exit" -eq 0 ]
# The application says on its first line what confines it: its name, sandbox: and at
# least one mechanism that took effect.  Read once it has ended: its output is a file, written
# when the buffer is full or the programme ends.
confined() { perl -ne 'BEGIN { $n = shift } if (/^\Q$n\E: sandbox: +.*\b(pledge|unveil|landlock|seccomp|seatbelt|capsicum)\b/) { $ok = 1 } END { exit($ok ? 0 : 1) }' "$APP" "$D/$APP.out"; }
check "the application ran in its sandbox" confined
echo "socket-left=$([ -e "$D/$APP.sock" ] && echo yes || echo no)"
expect "the control: no application, Hiawatha answers 503" 503 "/" "."

kill -TERM "$web"
wait "$web"
echo "hiawatha-exit=$?"
pids=()
echo "access-log-lines=$(wc -l < "$D/log/access.log" 2> /dev/null || echo 0)"
echo "error-log-lines=$(cat "$D/log/error.log" 2> /dev/null | wc -l)"
head -5 "$D/log/error.log" 2> /dev/null
echo "e2e $APP over $SCHEME: $good of $cases cases good"
[ "$good" -eq "$cases" ]
