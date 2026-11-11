#!/bin/sh
# A database server of its own for one test programme: PostgreSQL or
# MariaDB with TLS from a CA made for this run, inside the test container.
#
#     sh scripts/db/server.sh start postgres|mariadb <name>
#     sh scripts/db/server.sh stop postgres|mariadb <name>
#
# start makes /var/tmp/hilde-db-<name>, a CA, a server certificate for the
# name localhost signed by it, and a second CA that signed nothing; then a
# cluster owned by the user postgres, with a random password for the role
# hilde, that takes connections over TLS only and with that password only.
# It tries ports from a number taken from <name> upwards until a server
# comes up, so that tests running side by side do not meet.  On success it
# prints NAME=VALUE lines for the programme's environment:
#
#     HILDE_PG_HOST HILDE_PG_PORT HILDE_PG_DATABASE HILDE_PG_USER
#     HILDE_PG_PASSWORD HILDE_PG_CA HILDE_PG_OTHER_CA
#
# For mariadb the server is mariadbd as the user mysql, with TLS required
# and the role hilde required to use it, and the lines are HILDE_MARIA_HOST,
# HILDE_MARIA_PORT, HILDE_MARIA_DATABASE, HILDE_MARIA_USER,
# HILDE_MARIA_PASSWORD, HILDE_MARIA_CA and HILDE_MARIA_OTHER_CA.
#
# stop stops the server and removes the directory, and says that it is gone.
# Hilde's test-programs/runner.py calls both around a test that carries server.txt.
#
# The directory lies in the container, not in the tree, which is a bind
# mount: files owned by postgres there would belong to a user of the host
# that the caller cannot remove.  PostgreSQL refuses to run as root, so the
# script, which runs as root in the container, starts it with runuser as
# the user postgres, and MariaDB as the user mysql.  Run by another user,
# as the OpenBSD test run does as its build user, the servers run as that user, no
# file changes its owner, and the MariaDB account that the socket admits
# without a password is that user's.  The PostgreSQL programmes are those
# of /usr/lib/postgresql/<version>/bin, or else those beside initdb on
# PATH.
#
# Exit 0 done, 9 did not run (root without runuser, no PostgreSQL, a bad
# name).
# POSIX sh, no bashisms.
set -u

action=${1:-}
kind=${2:-}
name=${3:-}
case "$kind" in postgres|mariadb) ;; *) echo "server: NOT RUN -- unknown kind [$kind]" >&2; exit 9;; esac
case "$name" in ''|*[!A-Za-z0-9_-]*) echo "server: NOT RUN -- bad name [$name]" >&2; exit 9;; esac
D=/var/tmp/hilde-db-$name

# Not named stop: OpenBSD's ksh has an alias of that name, and a function
# of the name is a syntax error there.
stop_server() {
	bin=$1
	if [ "$kind" = mariadb ]; then
		if [ -S "$D/sock" ]; then
			mariadb-admin --socket="$D/sock" -u"$admin" shutdown > /dev/null 2>&1
			n=0
			while [ -e "$D/pid" ] && [ "$n" -lt 100 ]; do sleep 0.1; n=$((n + 1)); done
		fi
	elif [ -d "$D/data" ]; then
		as postgres "$bin/pg_ctl" -D "$D/data" -m fast -w stop > /dev/null 2>&1
	fi
	rm -rf "$D"
	test -e "$D"
	echo "server: stopped, $D test-e-after-rm=$?" >&2
}

# as <user> <command>...: the command as that user when this runs as root,
# else as the caller.  own: chown, or nothing when this does not run as root.
if [ "$(id -u)" = 0 ]; then
	command -v runuser > /dev/null 2>&1 || { echo "server: NOT RUN -- root, and no runuser" >&2; exit 9; }
	as() { u=$1; shift; runuser -u "$u" -- "$@"; }
	own() { chown "$@"; }
	admin=root
	install_user=--user=mysql
else
	as() { shift; "$@"; }
	own() { :; }
	admin=$(id -un)
	# Without --user mariadb-install-db makes no account for the caller,
	# and the socket then lets it in without the right to create users.
	install_user=--user=$admin
fi
command -v openssl > /dev/null 2>&1 || { echo "server: NOT RUN -- no openssl" >&2; exit 9; }
bin=
if [ "$kind" = postgres ]; then
	for b in /usr/lib/postgresql/*/bin; do
		[ -x "$b/initdb" ] && bin=$b
	done
	if [ -z "$bin" ] && command -v initdb > /dev/null 2>&1; then
		bin=$(dirname "$(command -v initdb)")
	fi
	[ -n "$bin" ] || { echo "server: NOT RUN -- no PostgreSQL server" >&2; exit 9; }
else
	# On PATH in the build image; OpenBSD's package puts the server
	# into /usr/local/libexec.
	mariadbd=$(command -v mariadbd 2> /dev/null)
	[ -n "$mariadbd" ] || [ ! -x /usr/local/libexec/mariadbd ] || mariadbd=/usr/local/libexec/mariadbd
	[ -n "$mariadbd" ] || { echo "server: NOT RUN -- no MariaDB server" >&2; exit 9; }
	bin=mariadb
fi

case "$action" in
stop)
	stop_server "$bin"
	exit 0
	;;
start)
	;;
*)
	echo "server: NOT RUN -- usage: server.sh start|stop postgres <name>" >&2
	exit 9
	;;
esac

[ ! -e "$D" ] || { echo "server: NOT RUN -- $D exists" >&2; exit 9; }
mkdir -p "$D/ca" "$D/other" || exit 9
# fail <message> [<log>]: the message and the last lines of the log, which
# the stop removes with the directory, then the stop.
fail() {
	echo "server: $1" >&2
	if [ -n "${2:-}" ] && [ -r "$2" ]; then
		tail -n 20 "$2" | sed -e 's/^/server:   /' >&2
	fi
	stop_server "$bin"
	exit 9
}

key() {
	openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$1" > /dev/null 2>&1
}
key "$D/ca/ca.key" || fail "CA key"
openssl req -x509 -new -key "$D/ca/ca.key" -out "$D/ca/ca.crt" -days 2 -subj /CN=hilde-test-ca > /dev/null 2>&1 || fail "CA certificate"
key "$D/server.key" || fail "server key"
openssl req -new -key "$D/server.key" -out "$D/ca/server.csr" -subj /CN=localhost > /dev/null 2>&1 || fail "server request"
printf 'subjectAltName=DNS:localhost,IP:127.0.0.1\n' > "$D/ca/ext.txt"
openssl x509 -req -in "$D/ca/server.csr" -CA "$D/ca/ca.crt" -CAkey "$D/ca/ca.key" -CAcreateserial \
	-out "$D/server.crt" -days 2 -extfile "$D/ca/ext.txt" > /dev/null 2>&1 || fail "server certificate"
key "$D/other/ca.key" || fail "second CA key"
openssl req -x509 -new -key "$D/other/ca.key" -out "$D/other/ca.crt" -days 2 -subj /CN=hilde-other-ca > /dev/null 2>&1 || fail "second CA certificate"
chmod 600 "$D/server.key"
own postgres "$D" "$D/server.key" "$D/server.crt" || fail "chown"
chmod 755 "$D" "$D/ca" "$D/other"
chmod 644 "$D/ca/ca.crt" "$D/other/ca.crt"

password=$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')
[ "${#password}" = 32 ] || fail "no random password"
# A port from the name, 41000 to 48999, and the next ones when it is taken.
sum=$(printf '%s' "$name" | cksum | cut -d' ' -f1)
port=$((41000 + sum % 8000))

if [ "$kind" = mariadb ]; then
	# A tmpdir of its own, so that no two servers keep their temporary
	# tables in one directory: with /tmp shared by the servers of tests
	# running side by side, a bootstrap now and then failed to delete its
	# own temporary table (Error on delete, No such file or directory).
	mkdir -p "$D/tmp" || fail "tmpdir"
	own -R mysql "$D" || fail "chown"
	mariadb-install-db $install_user --datadir="$D/data" --tmpdir="$D/tmp" --auth-root-authentication-method=socket \
		> "$D/install.log" 2>&1 || fail "mariadb-install-db, see $D/install.log" "$D/install.log"
	tries=0
	up=no
	while [ "$tries" -lt 20 ]; do
		# The background shell sends its own output to /dev/null with exec
		# before it calls the function.  A redirection on the call or on the
		# subshell is not enough: OpenBSD's ksh keeps a copy of the
		# caller's output to restore it afterwards, and that copy holds the
		# pipe of whoever reads this script's output open as long as the
		# server runs.
		(
			exec < /dev/null > /dev/null 2>&1
			as mysql "$mariadbd" --datadir="$D/data" --tmpdir="$D/tmp" --socket="$D/sock" --port="$port" --bind-address=127.0.0.1 \
				--ssl-ca="$D/ca/ca.crt" --ssl-cert="$D/server.crt" --ssl-key="$D/server.key" \
				--require-secure-transport=ON --pid-file="$D/pid" --log-error="$D/server.log"
		) &
		n=0
		while [ "$n" -lt 100 ]; do
			if mariadb-admin --socket="$D/sock" -u"$admin" ping > /dev/null 2>&1; then
				up=yes
				break
			fi
			sleep 0.1
			n=$((n + 1))
		done
		[ "$up" = yes ] && break
		tries=$((tries + 1))
		port=$((port + 1))
	done
	[ "$up" = yes ] || fail "the server did not start, see $D/server.log" "$D/server.log"
	printf "CREATE USER 'hilde'@'127.0.0.1' IDENTIFIED BY '%s' REQUIRE SSL;\nGRANT ALL ON *.* TO 'hilde'@'127.0.0.1';\nCREATE DATABASE hilde;\n" "$password" > "$D/setup.sql"
	mariadb --socket="$D/sock" -u"$admin" < "$D/setup.sql" > "$D/setup.log" 2>&1 || fail "the role hilde, see $D/setup.log" "$D/setup.log"
	rm -f "$D/setup.sql"
	echo "HILDE_MARIA_HOST=127.0.0.1"
	echo "HILDE_MARIA_PORT=$port"
	echo "HILDE_MARIA_DATABASE=hilde"
	echo "HILDE_MARIA_USER=hilde"
	echo "HILDE_MARIA_PASSWORD=$password"
	echo "HILDE_MARIA_CA=$D/ca/ca.crt"
	echo "HILDE_MARIA_OTHER_CA=$D/other/ca.crt"
	exit 0
fi
umask 077
printf '%s\n' "$password" > "$D/pw"
umask 022
own postgres "$D/pw" || fail "chown"
as postgres "$bin/initdb" -D "$D/data" -A scram-sha-256 --pwfile="$D/pw" -U hilde \
	> "$D/initdb.log" 2>&1 || fail "initdb, see $D/initdb.log" "$D/initdb.log"
rm -f "$D/pw"
printf "hostssl all all 127.0.0.1/32 scram-sha-256\nhostssl all all ::1/128 scram-sha-256\n" > "$D/data/pg_hba.conf"

tries=0
up=no
while [ "$tries" -lt 20 ]; do
	{
		printf "ssl = on\n"
		printf "ssl_cert_file = '%s'\n" "$D/server.crt"
		printf "ssl_key_file = '%s'\n" "$D/server.key"
		printf "listen_addresses = 'localhost'\n"
		printf "unix_socket_directories = '%s'\n" "$D"
		printf "port = %s\n" "$port"
	} > "$D/data/postgresql.auto.conf"
	own postgres "$D/data/postgresql.auto.conf"
	if as postgres "$bin/pg_ctl" -D "$D/data" -l "$D/server.log" -w -t 30 start > /dev/null 2>&1; then
		up=yes
		break
	fi
	tries=$((tries + 1))
	port=$((port + 1))
done
[ "$up" = yes ] || fail "the server did not start, see $D/server.log" "$D/server.log"

echo "HILDE_PG_HOST=localhost"
echo "HILDE_PG_PORT=$port"
echo "HILDE_PG_DATABASE=postgres"
echo "HILDE_PG_USER=hilde"
echo "HILDE_PG_PASSWORD=$password"
echo "HILDE_PG_CA=$D/ca/ca.crt"
echo "HILDE_PG_OTHER_CA=$D/other/ca.crt"
exit 0
