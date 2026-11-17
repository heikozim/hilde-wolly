# Building and testing Wolly

Wolly is compiled with the Hilde compiler and tested behind Hiawatha.  The
scripts find both through `scripts/env.sh`: `WOLLY_TOOLS` names a directory
that holds

- `hilde/`, a Hilde tree built with `make`: the compiler `hilde`, its
  standard library and bindings;
- `hiawatha/`, a Hiawatha tree with `build/hiawatha`, built with XSLT and
  the cache (without XSLT Hiawatha checks a file on disk for every request
  to a local FastCGI server, see `docs/hiawatha.md`), and
  `config/mimetype.conf`;
- `wolly-tools`, a few lines that say what the two were built from; the
  runs print it.

The scripts also want `cc`, `curl` and `python3` on the path, and the
development files of SQLite, SQLCipher and OpenSSL that the standard library
links against.

## What the scripts do

| Script | Purpose |
|---|---|
| `scripts/build.sh` | build the framework and every example |
| `scripts/test.sh` | unit tests (`hilde test`) on SQLite and, where PostgreSQL's server programs are installed, on PostgreSQL in servers of their own (`scripts/db/server.sh`, as the user postgres); every example behind a Hiawatha of its own on 127.0.0.1, twice, over HTTP and over TLS with a certificate made for the run (`scripts/e2e.sh`, the cases in `scripts/e2e-<example>.sh`); every public function states its contract and the contracts hold (`scripts/check-contracts.test.sh`, `scripts/contracts.sh`) |
| `scripts/mutate.sh` | break each check once and want the tests to notice |
| `scripts/finalize-linux.sh` | the same under ASan, UBSan, TSan and valgrind, each instrument after controls it must report |

Wolly is built and tested on Linux (Debian 13, arm64 and amd64), OpenBSD
and FreeBSD.
