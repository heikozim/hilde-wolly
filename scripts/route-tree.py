#!/usr/bin/env python3
"""The routes of a tree of route modules, written as a Hilde module when
the programme is built, so that nothing is scanned when it runs.

    python3 -I scripts/route-tree.py --hilde=<hilde> --root=<dir> --module=<Name> --out=<dir>
    python3 -I scripts/route-tree.py --root=<dir> --dirs

Below root every pair name.hih, name.hiq is a route module; its path in the
tree gives its route:

- a plain name (a-z, 0-9 and -) is one segment, index stands for the path
  of its directory, a directory name/ holds the modules below /name;
- _name adds a layout and no segment: _name.hih exports layout, and the
  pages in _name/ are wrapped in it, the innermost layout first;
- @name is a parameter segment :name: @name.hih exports a type Param and
  parse, and every page from @name.hih down takes a Param after the
  request, in the order of the parameters of its path;
- a page exports get, post, put, patch or delete.

The exports are read from hilde modules --json, every directory of the
tree named, because hilde skips a directory whose name begins with _.  The
module written, <Name> in <out>/Routes.hih and Routes.hiq, has the constant
treeRouteCount and addTreeRoutes, which appends the routes to a table of
Wolly.Router, static segments before parameters.  For each route it holds a
constant named after the method and the path, parameter names aside, so
two routes of one method and one path are refused by hilde with H2015 when
the module is compiled.

With --dirs only the directories of the tree are printed, joined by colons,
for the --modules of hilde.  Exit 0, 1 with the reasons on standard error
when the tree is not a route tree, 9 on wrong arguments.
"""
import json
import os
import re
import subprocess
import sys

PLAIN = re.compile(r"^[a-z0-9][a-z0-9-]*$")
PARAM = re.compile(r"^[a-z][a-z0-9]*$")
NAME = re.compile(r"^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)*$")
VERBS = {"get": "GET", "post": "POST", "put": "PUT", "patch": "PATCH", "delete": "DELETE"}


class TreeError(Exception):
    pass


def kind_of(stem):
    """The kind of a name in the tree and the name without its sign."""
    if stem.startswith("_"):
        kind, name = "layout", stem[1:]
    elif stem.startswith("@"):
        kind, name = "param", stem[1:]
    else:
        kind, name = "plain", stem
    rule = PARAM if kind == "param" else PLAIN
    if not rule.match(name):
        raise TreeError("not a name of a route tree: " + stem)
    return kind, name


def walk(root):
    """The directories of the tree and its route modules, each the parts of
    its path below root.  A symbolic link anywhere is refused, so that the
    tree is what lies below root."""
    dirs, pairs = [root], []
    for here, subdirs, files in os.walk(root):
        rel = os.path.relpath(here, root)
        parts = [] if rel == "." else rel.split(os.sep)
        for s in subdirs:
            if os.path.islink(os.path.join(here, s)):
                raise TreeError("a symbolic link in the tree: " + os.path.join(here, s))
            kind_of(s)
            dirs.append(os.path.join(here, s))
        for f in files:
            path = os.path.join(here, f)
            if not f.endswith((".hih", ".hiq")) or f.endswith(".test.hiq"):
                continue
            if os.path.islink(path):
                raise TreeError("a symbolic link in the tree: " + path)
            stem = f[:-4]
            kind_of(stem)
            other = path[:-4] + (".hiq" if f.endswith(".hih") else ".hih")
            if not os.path.isfile(other):
                raise TreeError("a route module needs both files: " + path)
            if f.endswith(".hih"):
                pairs.append(parts + [stem])
    return sorted(dirs), sorted(pairs)


def exports(hilde, root, dirs):
    """The name and the exports of each interface of the tree, by its real
    path, as hilde reads them."""
    out = subprocess.run([hilde, "modules", "--json", "--modules=" + ":".join(dirs)],
                         capture_output=True, text=True, check=False)
    if out.returncode != 0:
        raise TreeError("hilde modules failed: " + out.stderr.strip())
    found = {}
    real_root = os.path.realpath(root)
    for m in json.loads(out.stdout):
        if m.get("interface") is None:
            continue
        path = os.path.realpath(m["interface"])
        if os.path.commonpath([path, real_root]) != real_root:
            continue
        if not NAME.match(m["name"]):
            raise TreeError("not a module name: " + m["name"])
        names = {}
        for e in m["exports"]:
            if not NAME.match(e["name"]) or "." in e["name"]:
                raise TreeError("not an exported name: " + e["name"])
            names[e["name"]] = e["kind"]
        found[path] = (m["name"], names)
    return found


class Module:
    def __init__(self, parts, name, names):
        self.parts = parts
        self.name = name
        self.names = names
        self.kind, self.short = kind_of(parts[-1])


def read_tree(hilde, root):
    dirs, pairs = walk(root)
    known = exports(hilde, root, dirs)
    modules = {}
    for parts in pairs:
        path = os.path.realpath(os.path.join(root, *parts) + ".hih")
        if path not in known:
            raise TreeError("hilde found no module in " + path)
        name, names = known[path]
        m = Module(parts, name, names)
        verbs = [v for v in VERBS if names.get(v) == "function"]
        if m.kind == "layout":
            if names.get("layout") != "function":
                raise TreeError(name + ": a module with a leading underscore exports layout")
            if verbs:
                raise TreeError(name + ": a layout module answers no method")
        elif "layout" in names:
            raise TreeError(name + ": layout only in a module with a leading underscore")
        if m.kind == "param":
            if "Param" not in names or names.get("parse") != "function":
                raise TreeError(name + ": a parameter module exports a type Param and parse")
            if m.short == "index":
                raise TreeError(name + ": index is not a parameter name")
        elif "parse" in names:
            raise TreeError(name + ": parse only in a module with a leading at-sign")
        if m.kind == "plain" and not verbs:
            raise TreeError(name + ": a page answers at least one of " + ", ".join(VERBS))
        modules[tuple(parts)] = m
    # The directory of a layout or a parameter takes its meaning from the
    # module of the same name beside it.
    for d in dirs:
        rel = os.path.relpath(d, root)
        if rel == ".":
            continue
        parts = tuple(rel.split(os.sep))
        if kind_of(parts[-1])[0] != "plain" and parts not in modules:
            raise TreeError("a directory without its module: " + d)
    return modules


class Route:
    def __init__(self, verb, module, segments, layouts, params):
        self.verb = verb
        self.module = module
        self.segments = segments
        self.layouts = layouts
        self.params = params

    def pattern(self):
        return "/" + "/".join(":" + s if p else s for p, s in self.segments)

    def marker(self):
        # Letters and digits stand as they are, - is _d, a segment begins
        # with _s and a parameter is _p, so two paths give one name only
        # when they are one route.
        text = "route_" + self.verb
        for p, s in self.segments:
            text += "_p" if p else "_s" + s.replace("-", "_d")
        return text

    def order(self):
        return [(1, "") if p else (0, s) for p, s in self.segments] + [(2, self.verb)]


def routes_of(modules):
    found = []
    for parts, m in sorted(modules.items()):
        segments, layouts, params = [], [], []
        for i in range(1, len(parts) + 1):
            kind, short = kind_of(parts[i - 1])
            here = modules.get(tuple(parts[:i]))
            if kind == "layout":
                if i < len(parts):
                    layouts.append(here)
            elif kind == "param":
                segments.append((True, short))
                params.append(here)
            elif not (i == len(parts) and short == "index"):
                segments.append((False, short))
        for v in VERBS:
            if m.names.get(v) == "function":
                found.append(Route(VERBS[v], m, segments, layouts, params))
    return sorted(found, key=lambda r: r.order())


def write_module(modules, routes, module, out):
    alias = {}
    imports = []
    for n, (parts, m) in enumerate(sorted(modules.items())):
        alias[parts] = n
        wanted = sorted(x for x, kind in m.names.items()
                        if (x in VERBS and kind == "function") or x in ("layout", "Param", "parse"))
        imports.append("import %s (\n%s\n);\n" % (m.name, ",\n".join(
            "    %s as %s%d" % (x, x, n) for x in wanted)))
    head = ("--\n-- Written by scripts/route-tree.py from the route tree; regenerated at\n"
            "-- every build, not to be edited.\n--\n")
    hih = head + (
        'import Standard.Buffer (\n    Buffer,\n    length\n);\n'
        'import Wolly.Router (\n    Route\n);\n\n'
        'module %s is\n'
        '    """\n    How many routes addTreeRoutes appends.\n    """\n'
        '    constant treeRouteCount: Index;\n\n'
        '    """\n    routes with the routes of the tree appended, static segments\n'
        '    before parameters.\n    """\n'
        '    generic [R: Region]\n'
        '    function addTreeRoutes(routes: &![Buffer[Route], R]): Unit\n'
        '        ensures length(&routes) = (old(length(&routes)) + treeRouteCount);\n'
        'end module.\n') % module
    body = [head,
            'import Standard.String (\n    String,\n    destroyString,\n    asSpan\n);\n',
            'import Standard.Buffer (\n    Buffer,\n    insertBack\n);\n',
            'import Standard.FcgiServer (\n    Request\n);\n',
            'import Wolly.Router (\n    Route,\n    routeParam\n);\n',
            'import Wolly.Tree (\n    Page,\n    wrapPage,\n    finishPage,\n    paramNotFound\n);\n']
    body += imports
    body.append("\nmodule body %s is\n" % module)
    body.append("    constant treeRouteCount: Index := %d;\n" % len(routes))
    for i, r in enumerate(routes):
        source = "/".join(r.module.parts)
        body.append("\n    -- %s %s from %s.hih\n" % (r.verb, r.pattern(), source))
        body.append("    constant %s: Nat8 := 0;\n\n" % r.marker())
        body.append("    function serve%d(request: Request): String is\n" % i)
        body.append(serve_body(r, alias))
        body.append("    end;\n")
    body.append("\n    generic [R: Region]\n")
    body.append("    function addTreeRoutes(routes: &![Buffer[Route], R]): Unit is\n")
    for i, r in enumerate(routes):
        body.append('        insertBack(&~routes, Route(verb => "%s", pattern => "%s", handler => serve%d));\n'
                    % (r.verb, r.pattern(), i))
    body.append("        return nil;\n    end;\nend module body.\n")
    os.makedirs(out, exist_ok=True)
    for name, text in (("Routes.hih", hih), ("Routes.hiq", "".join(body))):
        path = os.path.join(out, name)
        with open(path + ".tmp", "w", encoding="utf-8") as h:
            h.write(text)
        os.replace(path + ".tmp", path)


def serve_body(r, alias):
    """The statements of the handler of r: each parameter read and parsed
    in its order, 404 when one does not parse, then the page wrapped in its
    layouts from the innermost out."""
    n = alias[tuple(r.module.parts)]
    call = "%s%d(request%s)" % (VERBS_BY_METHOD[r.verb], n,
                                "".join(", p%d" % k for k in range(len(r.params))))
    for layout in reversed(r.layouts):
        call = "wrapPage(%s, layout%d)" % (call, alias[tuple(layout.parts)])
    lines = []

    def emit(k, ind):
        if k == len(r.params):
            lines.append("%sreturn finishPage(%s);\n" % (ind, call))
            return
        p = r.params[k]
        a = alias[tuple(p.parts)]
        lines.append('%scase routeParam(&request, "%s", "%s") of\n' % (ind, r.pattern(), p.short))
        lines.append("%s    when Some(value as raw%d: String) do\n" % (ind, k))
        lines.append("%s        case parse%d(asSpan(&raw%d)) of\n" % (ind, a, k))
        lines.append("%s            when Some(value as p%d: Param%d) do\n" % (ind, k, a))
        lines.append("%s                destroyString(raw%d);\n" % (ind, k))
        emit(k + 1, ind + "                ")
        lines.append("%s            when None do\n" % ind)
        lines.append("%s                destroyString(raw%d);\n" % (ind, k))
        lines.append("%s                return paramNotFound(request);\n" % ind)
        lines.append("%s        end case;\n" % ind)
        lines.append("%s    when None do\n" % ind)
        lines.append("%s        return paramNotFound(request);\n" % ind)
        lines.append("%send case;\n" % ind)

    emit(0, "        ")
    return "".join(lines)


VERBS_BY_METHOD = {m: v for v, m in VERBS.items()}


def main(argv):
    opts = {}
    for a in argv:
        if a == "--dirs":
            opts["dirs"] = True
            continue
        m = re.match(r"^--(hilde|root|module|out)=(.+)$", a)
        if not m:
            print(__doc__.strip().splitlines()[3].strip(), file=sys.stderr)
            return 9
        opts[m.group(1)] = m.group(2)
    if "root" not in opts or not os.path.isdir(opts["root"]):
        print("route-tree: --root names no directory", file=sys.stderr)
        return 9
    root = os.path.abspath(opts["root"])
    try:
        if opts.get("dirs"):
            print(":".join(walk(root)[0]))
            return 0
        if not all(k in opts for k in ("hilde", "module", "out")) or not NAME.match(opts["module"]):
            print("route-tree: --hilde, --module=<Name> and --out are needed", file=sys.stderr)
            return 9
        modules = read_tree(opts["hilde"], root)
        routes = routes_of(modules)
        if not routes:
            raise TreeError("the tree has no page")
        write_module(modules, routes, opts["module"], opts["out"])
    except TreeError as e:
        print("route-tree: " + str(e), file=sys.stderr)
        return 1
    print("route-tree: %d routes from %d modules into %s" % (len(routes), len(modules), opts["out"]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
