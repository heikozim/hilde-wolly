<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/logo/wolly-wordmark-dark.svg">
  <img src="docs/logo/wolly-wordmark-light.svg" alt="Wolly" width="310" height="100">
</picture>

A web framework in Hilde: Web-ready, OpenBSD-first, Linear, Lean, Yours

Website: https://hilde-lang.org/wolly/

# Wolly

Wolly turns a Hilde programme into a FastCGI responder on a Unix socket
behind the web server Hiawatha.  The loop is Hilde's Standard.FcgiServer;
Wolly adds what a handler needs.  It is written in
[Hilde](https://github.com/heikozim/hilde).

## Features

- **Requests and routing:** router with `/user/:id` and `/files/*`,
  middleware, typed links that do not compile when wrong, routes from a
  tree of files, fragments for partial page updates
- **Sign-in and security:** sessions with Argon2id, roles, TOTP, passkeys,
  Device Bound Session Credentials, bearer tokens, CSRF guard, rate limits,
  proof of work, bans through Hiawatha, an OpenID provider and a client for
  [RAMBO](https://github.com/heikozim/hilde-rambo)
- **Data:** SQLite and PostgreSQL with one test file for both, pages of
  lists, run-time fields (EAV), graphs of edges, full-text and sound search,
  a log store with a query language
- **Content:** CommonMark with GFM, a Markdown editor core, templates in
  Hilde's Jinja dialect, syntax highlighting, Atom feeds, HTTP signatures
- **Images and codes:** QR codes, the colour code Bunti, GIF, JPEG and
  WebP read in Hilde
- **Operations:** pledge and unveil on OpenBSD, Landlock and seccomp on
  Linux, assets compiled into the programme, a development server on
  loopback

Every module is listed in [docs/modules.md](docs/modules.md).

## Quick start

```
WOLLY_TOOLS=/path/to/tools bash scripts/build.sh
WOLLY_TOOLS=/path/to/tools bash scripts/test.sh
```

`WOLLY_TOOLS` holds a built Hilde tree and a built Hiawatha; see
[docs/testing.md](docs/testing.md).

## Examples

| Example | What it shows |
|---|---|
| `examples/login` | a login with roles, a second factor, passkeys, tokens and notes |
| `examples/contact` | a public contact form without sessions, guarded against robots |
| `examples/hello` | one route for each of many modules: QR, Bunti, Markdown, feeds and more |

Commands and routes of each example: [docs/examples.md](docs/examples.md).

## Testing

- `scripts/test.sh`: unit tests on SQLite and PostgreSQL, every example
  end to end behind Hiawatha over HTTP and TLS, contracts of every public
  function
- `scripts/mutate.sh`: each check broken once, the tests must notice
- `scripts/finalize-linux.sh`: the same under ASan, UBSan, TSan and valgrind
- Built and tested on Linux (Debian 13, arm64 and amd64), OpenBSD and FreeBSD

Details: [docs/testing.md](docs/testing.md).

## Documents

- [CHANGELOG](CHANGELOG): the releases, the newest first
- [docs/modules.md](docs/modules.md): every module
- [docs/examples.md](docs/examples.md): the examples, their commands and routes
- [docs/testing.md](docs/testing.md): building and testing
- [docs/hiawatha.md](docs/hiawatha.md): the Hiawatha configuration
- [docs/bunti-format.md](docs/bunti-format.md): the format of the colour code Bunti

Static files are served by Hiawatha under `/static/`; Wolly has no code for
them.

## License

Copyright (c) 2026 Heiko Zimmermann <code@heiko-zimmermann.com>

Wolly is licensed under the Apache License 2.0 with LLVM Exceptions; see
[LICENSE](LICENSE).  Issues, questions and patches go to
code@heiko-zimmermann.com.

## Checking a release

A release is an archive `wolly-X.Y.Z.tar.gz` of the tree at the tag vX.Y.Z,
its signature made with signify and a file SHA256 with the checksums of
both.  The public key is `wolly-0.pub` in the root of the repository:

```
signify -V -p wolly-0.pub -x wolly-X.Y.Z.tar.gz.sig -m wolly-X.Y.Z.tar.gz
```
