# Wolly examples

Each example is built by `scripts/build.sh` and runs behind a Hiawatha of
its own in `scripts/test.sh`, over HTTP and over TLS.

## examples/login

A login behind Hiawatha with roles, a second factor, passkeys, tokens and
notes.  Its pages are templates (`examples/login/templates/`, a layout with
`{% extends %}`), compiled into the programme and escaped for the place each
value lands; its handler runs through `Wolly.Middleware.dispatchWith`.

| Command | Purpose |
|---|---|
| `login adduser NAME` | add a user; the password comes from standard input and is checked against `known-passwords.txt` beside the programme |
| `login passwd NAME` | change the password |
| `login grant ROLE ACTION` | grant a role an action |
| `login assign NAME ROLE` | give a user a role |
| `login totp-off NAME` | turn the second factor off |
| `login passkey-off NAME` | remove the passkeys of a user |
| `login deluser NAME` | remove a user and all the programme keeps of it (roles, second factor, tokens, passkeys, the sound of the name, notes) in one transaction; the user's audit lines get a random pseudonym |
| `login audit-prune` | remove audit lines older than 12 months (for a daily timer; the server also runs it at its start) |
| `login link SOURCE TARGET KIND WEIGHT` | keep an edge |
| `login route KIND FROM TO` | search a route over the edges |
| `login token NAME` | give a token for `GET /api/whoami` |
| `login revoke NAME` | take the token back |
| `login` | serve the pages below |

| Route | Purpose |
|---|---|
| `GET /` | the start page |
| `GET /login`, `POST /login` | sign in |
| `POST /logout` | sign out |
| `GET /admin` | the admin page, only for a holder of a role granted `admin` |
| `GET /admin/find?name=...` | find users by the sound of their name |
| `GET /totp`, `POST /totp` | turn on the second factor with a QR code |
| `GET /login/code`, `POST /login/code` | the code after the password |
| `GET /notes`, `POST /notes` | the notes of the user, at most 100, in a table of their own; the statements run through `Standard.Database` |
| `POST /passkey/challenge` | a challenge for a passkey, used once |
| `POST /passkey/register` | register a passkey |
| `POST /passkey/login` | sign in with a passkey |
| `GET /api/whoami` | who a bearer token belongs to |

## examples/contact

A public contact form without sessions, guarded by `Wolly.FormGuard`.  It
keeps the messages, shows only their count, and asks Hiawatha to ban a robot
that filled the honeypot.

| Route | Purpose |
|---|---|
| `GET /contact` | the form |
| `POST /contact` | send a message |

## examples/hello

One route for each of many modules.

| Route | Purpose |
|---|---|
| `GET /` | hello |
| `GET /hello/:name` | a route parameter |
| `GET /files/*` | a wildcard route |
| `GET /numbers?page=n` | pages of a list |
| `GET /asset?path=/static/app.css` | the version of an asset |
| `GET /qr?text=...` | a QR code |
| `GET /bunti?text=...` | a page with the Bunti code of the text (the picture of `demo/`) |
| `GET /check?email=...&date=...` | the checks of Wolly.Field |
| `GET /stats?values=...` | a chart as text |
| `GET /markdown?text=...` | Markdown as a page |
| `GET /sound?name=...` | the sound of a name |
| `GET /code?file=...&text=...` | code highlighted |
| `GET /feed.atom` | an Atom feed |
| `POST /inbox` | an inbox that takes requests signed by one actor |
| `GET /visits` | counts the visits of a browser in a cookie (Secure, HttpOnly, SameSite=Strict; a count that is no number or above 1000000 starts again) |
