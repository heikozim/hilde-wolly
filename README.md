# Wolly

A web framework in Hilde: Web-ready, OpenBSD-first, Linear, Lean, Yours.

This repository carries the framework, its programmes, the examples, the
tests and the documentation for the user.  Issues, questions and patches go
to code@heiko-zimmermann.com.  Wolly is written in Hilde,
https://github.com/heikozim/hilde, and runs behind the web server Hiawatha.

## What it is

A Wolly application is a FastCGI responder on a Unix socket behind Hiawatha.
The loop is Hilde's Standard.FcgiServer;
Wolly adds what a handler needs:

| Module | What |
|---|---|
| Wolly.Server | the life of the process: socket with mode 0660, SIGTERM and SIGINT, the socket removed at the end |
| Wolly.Response | the CGI answer with headers between Content-Type and the body; a header with CR, LF or another control byte is refused and the answer becomes 500 |
| Wolly.Request | method, path without the query, decoded query parameters, the value of a cookie |
| Wolly.Router | routes of method and pattern (`/user/:id`, `/files/*`), the first that fits wins; 404, 405 with Allow, 400 |
| Wolly.Secret | a key of the server from a file of mode 0600 (never a literal, an argument or the environment) |
| Wolly.Guard | protection against request forgery: the form token of the session and the own origin (Sec-Fetch-Site, Origin) |
| Wolly.Middleware | steps before the router (`Fn[Request, Step]`: go on or answer) and after it (`Fn[String, String]`); `knownMethods`, `securityHeaders`; `dispatchLogged` writes one access-log line per request with a `request_id` that the answer carries as `X-Request-Id` |
| Wolly.Auth | users with Argon2id hashes, login with session rotation and throttling per client and per name, logout, the `__Host-wolly` cookie, an audit log |
| Wolly.Limit | at most n calls of one key in a window of seconds, counted in the database (SQLite or PostgreSQL) across connections and processes; 429 with Retry-After |
| Wolly.Dialect | the statement for the backend of a database: `pick(db, plain, pg)` gives the text for PostgreSQL where SQLite's does not run there, SQLite's everywhere else |
| Wolly.TestDb | the database of a test: SQLite in memory, or with `WOLLY_DB=postgres` the test server of Hilde's `scripts/db/server.sh`; one test file runs on both |
| Wolly.FormGuard | a public form against robots: honeypot, a signed stamp of 3 to 1800 seconds that is good once, a limit per client |
| Wolly.Page | the pages of a list: page, offset, size of at most 1000, the pages before and after; a page number from a query is never trusted |
| Wolly.Role | roles in the database: a user may an action when a role it holds was granted it, else not; 403 |
| Wolly.Ban | asks the Hiawatha in front to ban the client: X-Hiawatha-Ban, at most a day; Hiawatha acts on it only with BanByCGI = yes |
| Wolly.Asset | the version of a static file for its URL, ?v= and 16 hex digits of the SHA-256 of its content; only paths below a root, no dot segment, no symlink |
| Wolly.Qr | the QR code of a text as a data URI of a PNG, for an img src: 4 pixels a module, the quiet zone, level medium (Standard.Qr, Png, Base64) |
| Wolly.Bunti | Bunti, a colour code a camera reads whose format is a sequence of the bases A, C, G, T (two bits a cell): grid, header, Reed-Solomon blocks at L/M/Q/H, mode 1 or the DNA-suitable mode 2, drawn as pixels, SVG or PNG; buffers in and out, no file, network or clock (docs/bunti-format.md) |
| Wolly.BuntiScan | a Bunti code read from a picture of red, green and blue: finders by their runs, a perspective transformation, each cell against the reference colours; the payload or an error, never other bytes |
| Wolly.BuntiRs, Wolly.BuntiDna | Reed-Solomon over GF(256) with decoding (Berlekamp-Massey, Chien, Forney), and mode 2 of Bunti (at most three equal bases in a row, 45 to 55 percent G and C) |
| Wolly.Seal | short secrets sealed with ChaCha20-Poly1305 under a key of the server, one key per purpose, bound to a context such as a user name |
| Wolly.Passphrase | the rules for a password after NIST SP 800-63B-4: NFKC, 15 characters alone or 8 with a second factor, at most 256, a list of known passwords, not the user name |
| Wolly.Edges | relations as edges in the database (from, to, kind, weight): reachability and ancestors in one recursive query that a cycle cannot run away with, the lightest route, the route of fewest edges and a cycle through Standard.Graph |
| Wolly.Chart | the arithmetic of a bar chart in integers: a number as people read it (1.2 k, 1.5 M), the median, the height of a bar, the change against the median in tenths |
| Wolly.Markdown | Markdown to HTML, the plain part (headings, paragraphs, lists, quote, code, rule; code, strong, emphasis, links), everything escaped, links only to http, https, mailto, a path or an anchor |
| Wolly.Feed | a feed of news as Atom (RFC 4287): every text escaped for XML, links only when safe, times in RFC 3339 UTC |
| Wolly.Signature | signed requests of the fediverse (draft-cavage HTTP Signatures): (request-target), host, date and the digest of a body signed, the date within 300 seconds, rsa-sha256 or Ed25519 under the key of the keyId, never rsa-sha1 |
| Wolly.Entity | fields defined at run time as EAV in the database: text or integer, required, unique (a key enforces it), a length; names from an allowlist only, every change one transaction and one line of audit without the value; what is known when the application is built belongs into tables of its own |
| Wolly.Passkey | passkeys, the server's half: a challenge used once in 300 seconds, the check of a registration (format none, ES256 or EdDSA in COSE) and of a login (signature, counter), the user present and verified |
| Wolly.Phonetic | names by their sound: the Kölner Phonetik and American Soundex, letters of Latin-1 read as their base letter |
| Wolly.Highlight | syntax highlighting to HTML after tedu's synlight: nine lexers of regular expressions, every byte escaped, code above 64 KiB only escaped |
| Wolly.SoundSearch | things found by the sound of their names (Kölner Phonetik, Soundex or both), every word searched must sound; a table of key and code with constant SQL, no FTS5; examples/login finds its users by it at `GET /admin/find?name=...` |
| Wolly.LogStore | log lines of hosts kept with their full-text and sound index in one transaction, a level set later, a prune by time; the index is Standard.Search (FTS5) on SQLite and two tsvector columns of the table on PostgreSQL |
| Wolly.Query | a query of the lines of Wolly.LogStore: host, source, level, time, id and phrases with and, or, not, newest first and in pages, each node a set in a temporary table |
| Wolly.Field | checks of form fields by allowlist: the bytes a value may hold, an e-mail address of the plain kind, a date as YYYY-MM-DD with leap years |
| Wolly.Bearer | tokens for machines: Authorization: Bearer, 32 random bytes given out once, kept as their SHA-256; Hiawatha passes the header only with HTTPAuthToCGI = yes |
| Wolly.Gif | GIF87a and GIF89a read in Hilde: the first picture as red, green and blue on its screen, LZW of 2 to 12 bits, interlaced rows in order, the transparent index; every length checked, the screen against a limit before anything is allocated |
| Wolly.Pseudonym | pseudonyms of personal data such as a client address: HMAC-SHA256 under a key of the server, never a plain hash; examples/login keeps and audits clients only by them |
| Wolly.Rambo | a client of RAMBO, the sign-in service: OpenID Connect with PKCE, the code exchanged, refresh, logout with the ID token as hint, ID tokens checked against RAMBO's ML-DSA keys (JWK kty AKP), pending sign-ins kept for ten minutes and taken once; Wolly.Auth.externalLogin opens the session |
| Wolly.Jpeg | JPEG read in Hilde: baseline, extended sequential and progressive, grey or YCbCr, sampling 1 and 2, chroma upsampled as libjpeg does, restart markers, the EXIF orientation applied; arithmetic, lossless and 12-bit answer Unsupported; every length checked, the size against a limit before anything is allocated |
| Wolly.Webp, Wolly.Vp8 | WebP read in Hilde: lossless (VP8L: the four transforms, colour cache, backward references, groups of prefix codes) and lossy (VP8 key frames, loop filter, colours as libwebp converts them) with alpha (ALPH); RGB and the alpha apart; animations answer Unsupported; every length checked, the size and the prefix codes against limits |
| Wolly.Totp | a second factor: TOTP codes with HMAC-SHA256, seeds sealed, a step taken once; Wolly.Auth asks for the code after the password |
| Wolly.Version | the release (0.2.0, the first line of CHANGELOG) and what a programme says about itself: the version line on version, -V or --version, the full version with its C libraries on the same word and --full, info |
| Wolly.Confine | the sandbox of a server whose files lie in its working directory (pledge and unveil, Landlock and seccomp) and its output on sandbox or -s |
| Wolly.View, Wolly.ViewData, Wolly.ViewFunctions | templates of tenants read at run time in the syntax of Hilde's Jinja dialect: the same refusals and the same escaping by the place of a value as @template, decided when a template is loaded; directories searched in order (the tenant's first), no absolute name, no dot segment, no symbolic link below a directory; at most 1 MiB a file, 64 files, 16 deep, 200000 steps, 1000000 turns of loops and 16 MiB of output, with budgets for the text a render makes, the nodes its functions are given and the bytes it searches, each an error and never a crash; a page that fails is not written; a template read again when its file changes; the data a document with HTML only through a sanitizer or Markdown; the functions of a set of Go templates, which cli/view converts |
| Wolly.Account | accounts that sign in with an e-mail address, a password and a code of an authenticator app, in the table accounts in the same form as an earlier implementation in Go, so that both read the same rows |
| Wolly.Backoff | a delay per key after failed attempts, kept in the database, doubling with each further failure |
| Wolly.Strikes | failures per key within a window, kept in the database: true at the one failure that reaches the limit, to ban |
| Wolly.Pow | a proof of work in front of an expensive step such as an Argon2id login; each puzzle counts once |
| Wolly.Fernet | short values sealed in the token form 0xCC of Fernet as Go implementations write it, a key of 48 bytes |
| Wolly.DevServer | a FastCGI handler served over HTTP/1.1 on a loopback address, for development without a web server |
| Wolly.Op | an OpenID provider for a fixed set of first-party clients: discovery, the key set, authorization with S256, logout, the hand-over of a sign-in |
| Wolly.OpBase | what the endpoints of the provider share: settings, the form of a request, the cookies, the answers, the audit line, the browser's session |
| Wolly.OpClient | the fixed list of clients in op_clients: who may sign in, where the browser goes back to, how a client proves itself |
| Wolly.OpGrant | the token endpoint (RFC 6749, section 3.2) |
| Wolly.OpKey | the signing keys: a ring of ML-DSA-44 and the composite ML-DSA-44-Ed25519, the tokens they sign, the key set, their place in a vault |
| Wolly.OpRandom | the random values of the provider and how they are kept |
| Wolly.OpStore | sessions, login requests, authorization codes, refresh tokens in families and roles, in tables that match an earlier provider written in Go column for column |
| Wolly.OpToken | the JSON of the provider, member for member as that Go provider writes it, and the small checks of an authorization request |
| Wolly.OpUrl | URLs taken apart and put together, the query encoded as Go's net/url writes it |

## Building and testing

Wolly is compiled with the Hilde compiler and tested behind Hiawatha.  The
scripts find both through `scripts/env.sh`: `WOLLY_TOOLS` names a directory
that holds

- `hilde/`, a Hilde tree built with `make`: the compiler `hilde`, its
  standard library and bindings;
- `hiawatha/`, a Hiawatha tree with `build/hiawatha`, built with XSLT and
  the cache (without XSLT Hiawatha checks a file on disk for every request
  to a local FastCGI server, `docs/hiawatha.md`), and `config/mimetype.conf`;
- `wolly-tools`, a few lines that say what the two were built from; the
  runs print it.

The scripts also want `cc`, `curl` and `python3` on the path, and the
development files of SQLite, SQLCipher and OpenSSL that the standard library
links against.  From the root of the tree:

```
WOLLY_TOOLS=/path/to/tools bash scripts/build.sh
WOLLY_TOOLS=/path/to/tools bash scripts/test.sh
WOLLY_TOOLS=/path/to/tools bash scripts/mutate.sh
```

`scripts/test.sh` runs the unit tests (`hilde test`) on SQLite and, where
PostgreSQL's server programs are installed, on PostgreSQL in servers of
their own (`scripts/db/server.sh`, as the user postgres); it builds every
example and runs each behind a Hiawatha of its own on 127.0.0.1, twice,
over HTTP and over TLS with a certificate made for the run (`scripts/e2e.sh`,
the cases in `scripts/e2e-<example>.sh`), and holds that every public
function states its contract and that the contracts hold
(`scripts/check-contracts.test.sh`, `scripts/contracts.sh`).
`scripts/mutate.sh` breaks each check once and wants the tests to notice.
`scripts/finalize-linux.sh` runs the same under ASan, UBSan, TSan and
valgrind, each instrument after controls it must report.  Wolly is built
and tested on Linux (Debian 13, arm64 and amd64), OpenBSD and FreeBSD.

`examples/login` is a login behind Hiawatha:
`login adduser NAME` reads the password from standard input and checks it against
`known-passwords.txt` beside the programme, `login passwd NAME` changes it, `login grant ROLE ACTION`
and `login assign NAME ROLE` keep the roles, `login totp-off NAME` turns a second factor
off, `login passkey-off NAME` removes the passkeys of a user, `login deluser NAME` removes a user and all the programme keeps of it (roles, second factor, tokens, passkeys, the sound of the name, notes) in one transaction and gives the user's lines of the audit log a random pseudonym, `login audit-prune` removes audit lines older than 12 months (for a daily timer; the server runs it at its start), `login link SOURCE TARGET KIND WEIGHT` and `login route KIND FROM TO` keep and search edges, `login token NAME` and `login revoke NAME` give and take tokens for `GET /api/whoami`, `login` serves `GET /`, `GET /login`,
`POST /login`, `POST /logout`, `GET /admin` and `GET /admin/find?name=...`, which only a holder of a role granted
`admin` sees, `GET` and `POST /totp`, which turn on the second factor with a
QR code, `GET` and `POST /login/code`, the code after the password, and `GET` and
`POST /notes`, the notes of the user in a table of its own that the programme makes, at most 100 a user, as many as the page shows, the
statements run through `Standard.Database` and checked by the end-to-end run.  Its
pages are templates
(`examples/login/templates/`, a layout with `{% extends %}`), compiled into
the programme and escaped for the place each value lands; its handler runs
through `Wolly.Middleware.dispatchWith`.

`examples/contact` is a public contact form without sessions, guarded by
`Wolly.FormGuard`; it keeps the messages and shows only their count, and asks
Hiawatha to ban a robot that filled the honeypot.

`examples/hello` answers `GET /`, `GET /hello/:name`, `GET /files/*`, `GET /numbers?page=n`,
`GET /asset?path=/static/app.css`, the version of an asset, `GET /qr?text=...`, a QR code, `GET /bunti?text=...`, a page with the Bunti code of the text (the picture of `demo/`), `GET /check?email=...&date=...`, the checks of Wolly.Field, `GET /stats?values=...`, a chart as text, `GET /markdown?text=...`, Markdown as a page, `GET /sound?name=...`, the sound of a name, `GET /code?file=...&text=...`, code highlighted, `GET /feed.atom`, a feed, `POST /inbox`, an inbox that takes requests signed by one actor, and `GET /visits`, which counts the visits of a browser in a cookie (Secure,
HttpOnly, SameSite=Strict; a count that is no number or above 1000000 starts
again).

## Documents

- `CHANGELOG` -- the releases, the newest first
- `docs/hiawatha.md` -- the Hiawatha configuration and a trap of a build without XSLT
- static files: Hiawatha serves `/static/`, Wolly has no code for them
- `docs/bunti-format.md` -- the format of the colour code Bunti
- `LICENSE` -- the Apache License 2.0 with LLVM Exceptions

## License

Copyright (c) 2026 Heiko Zimmermann <code@heiko-zimmermann.com>

Wolly is licensed under the Apache License 2.0 with LLVM exception; see LICENSE.

## Checking a release

A release is an archive `wolly-X.Y.Z.tar.gz` of the tree at the tag vX.Y.Z,
its signature made with signify and a file SHA256 with the checksums of
both, on the release page of this repository.  The public key is
`wolly-0.pub` in the root of the repository; `VERIFY.md` of a release says
how to check it:

```
signify -V -p wolly-0.pub -x wolly-X.Y.Z.tar.gz.sig -m wolly-X.Y.Z.tar.gz
```
