#!/usr/bin/env python3
"""Fixes proto3-optional presence checks in godobuf-generated GDScript.

godobuf generates scalar `has_x()` as `value != null`, but scalar fields are
initialized to their type default (never null), so absent optional fields
read as present-with-default and delta semantics break. The decoder does
track real presence via `data[tag].state == FILLED` (godobuf itself uses
that pattern for oneof fields), so this script rewrites every null-check
`has_x()` body to the state check.

Usage: fix_godobuf_presence.py <generated_pb.gd>
"""
import re
import sys

path = sys.argv[1]
lines = open(path).read().split("\n")

field_decl = re.compile(r'^\t+__(\w+) = PBField\.new\("\1", PB_DATA_TYPE\.\w+, PB_RULE\.\w+, (\d+),')
has_func = re.compile(r"^(\t+)func has_(\w+)\(\) -> bool:$")

# Tag of the most recent PBField declaration per field name; has_ functions
# always follow their own class's _init, so "most recent" is the right scope.
tags = {}
out = []
i = 0
rewritten = 0
while i < len(lines):
    line = lines[i]
    decl = field_decl.match(line)
    if decl:
        tags[decl.group(1)] = decl.group(2)
        out.append(line)
        i += 1
        continue

    fn = has_func.match(line)
    if (
        fn
        and fn.group(2) in tags
        and i + 3 < len(lines)
        and lines[i + 1].strip() == f"if __{fn.group(2)}.value != null:"
        and lines[i + 2].strip() == "return true"
        and lines[i + 3].strip() == "return false"
    ):
        indent = fn.group(1)
        out.append(line)
        out.append(f"{indent}\treturn data[{tags[fn.group(2)]}].state == PB_SERVICE_STATE.FILLED")
        i += 4
        rewritten += 1
        continue

    out.append(line)
    i += 1

open(path, "w").write("\n".join(out))
print(f"rewrote {rewritten} has_() presence checks in {path}")
