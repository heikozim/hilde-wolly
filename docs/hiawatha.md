# Wolly behind Hiawatha

Wolly runs as a FastCGI responder on a Unix socket; Hiawatha takes HTTP and
hands every request to the socket through `UrlToolkit`:

```
FastCGIserver {
    FastCGIid = WOLLY
    ConnectTo = /path/to/app.sock
    SessionTimeout = 10
}
UrlToolkit {
    ToolkitID = all
    Match .* UseFastCGI WOLLY
}
UseToolkit = all
```

`scripts/e2e.sh` writes the complete configuration of the tests.

## Static files

Hiawatha serves `/static/` itself from the disk, everything else goes to
Wolly.  To the configuration above add:

```
Directory {
    DirectoryID = static
    Path = /static/
    ExpirePeriod = 1 day, public
}
UrlToolkit {
    ToolkitID = all
    Match ^/static/ Exit
    Match .* UseFastCGI WOLLY
}
UseDirectory = static
```

Without `, public` Hiawatha sets `Cache-Control: private`.  Hiawatha
refuses `..`, dot files and control bytes after decoding (`valid_uri` in
its libstr.c), and `%00` with 403.

## Which methods arrive

Hiawatha hands GET, HEAD, POST and QUERY to the FastCGI server (BREW as
POST, WHEN as well).  It answers TRACE itself with 501 as long as
`EnableTrace` is off; PUT and DELETE pass only with `EnableAlter = yes` or
`WebDAVapp = yes`; OPTIONS, PATCH and the WebDAV methods only with
`WebDAVapp = yes`, else 501.  A route with DELETE in Wolly therefore needs
one of these settings behind Hiawatha.  Behind Hiawatha
`Wolly.Middleware.knownMethods` is there mainly for QUERY, and otherwise
the second line, for example behind another web server.

## Trap: without XSLT, Hiawatha checks the file on disk for a local FastCGI server

Hiawatha v13.0 built with `-DENABLE_XSLT=OFF`: `GET /` and `POST /` reached
the application, `GET /some/where?x=1` was answered by Hiawatha itself with
its 404 page, and of ten parallel `GET /many?i=N` none got 200.  The error
log stayed empty.

The cause is in Hiawatha's target.c:

```c
} else if ((session->cgi_type == fastcgi) && session->fcgi_server->localhost
#if defined(ENABLE_XSLT) || defined(ENABLE_MONITOR)
        && session->host->show_index
#endif
        ) {
        check_file_exists = true;
```

With XSLT or the monitor the file is checked only when `ShowIndex` is set.
Without both the condition falls away, and **every** request to a local
FastCGI server needs a file below `WebsiteRoot`, else 404.

Built with XSLT, Hiawatha's default, all of these requests reach the
application.  Build Hiawatha for Wolly with XSLT, the cache and the URL
toolkit on, and check that `CMakeCache.txt` lists all three as ON.
