#!/usr/bin/env python3
"""The modules a Hilde programme needs, in the order of their imports, as
the pairs hilde compile takes: interface,body.

    python3 scripts/modules.py <dir>... -- <file.hih,file.hiq>...

Every .hih and .hiq file below the directories is read for the module it
declares (module X is / module body X is); the programme's own pairs after
-- are read for their imports, and so on through the imports of each module
found.  A module is printed after every module it imports.  An import of
a module that no file declares is an error, except the modules built into
the compiler (Hilde.*), which no file declares.  Exit 0 and the list, or
exit 1 and the names that were not found.
"""
import os
import re
import sys

DECL = re.compile(r"^module\s+(body\s+)?([A-Za-z][A-Za-z0-9_.]*)\s+is\b", re.M)
IMPORT = re.compile(r"^import\s+([A-Za-z][A-Za-z0-9_.]*)", re.M)


def scan(dirs):
    found = {}
    for d in dirs:
        for root, subdirs, files in os.walk(d):
            subdirs[:] = [s for s in subdirs if not s.startswith((".", "_"))]
            for f in files:
                if not f.endswith(".hih") or f.endswith(".test.hih"):
                    continue
                path = os.path.join(root, f)
                with open(path, encoding="utf-8") as h:
                    m = DECL.search(h.read())
                if m is None:
                    continue
                body = path[:-4] + ".hiq"
                if os.path.exists(body):
                    found.setdefault(m.group(2), (path, body))
    return found


def imports(pair):
    names = []
    for path in pair:
        with open(path, encoding="utf-8") as h:
            names += IMPORT.findall(h.read())
    return names


def main(argv):
    if "--" not in argv:
        print(__doc__.strip().splitlines()[2].strip(), file=sys.stderr)
        return 9
    cut = argv.index("--")
    dirs, roots = argv[:cut], argv[cut + 1:]
    known = scan(dirs)
    order, seen, missing = [], set(), []

    def visit(name, pair, stack):
        if name in seen:
            return
        if name in stack:
            missing.append("cycle at " + name)
            return
        for dep in imports(pair):
            if dep.startswith("Hilde."):
                continue
            if dep not in known:
                missing.append(dep)
                continue
            visit(dep, known[dep], stack | {name})
        seen.add(name)
        order.append(pair)

    for i, root in enumerate(roots):
        pair = tuple(root.split(","))
        if len(pair) != 2 or not all(os.path.exists(p) for p in pair):
            print("not a readable pair: " + root, file=sys.stderr)
            return 1
        visit("root %d" % i, pair, set())
    if missing:
        print("not found: " + " ".join(sorted(set(missing))), file=sys.stderr)
        return 1
    print(" ".join(a + "," + b for a, b in order))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
