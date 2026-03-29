#!/usr/bin/env python3
"""Generate heroicons safelist for Tailwind CSS bundling (outline + solid)."""
import os

icons_dir = os.path.join("deps", "heroicons", "optimized")
classes = []

for suffix, subdir in [("", "24/outline"), ("-solid", "24/solid")]:
    full_dir = os.path.join(icons_dir, subdir)
    for f in sorted(os.listdir(full_dir)):
        if f.endswith(".svg"):
            name = f[:-4] + suffix
            classes.append(f"hero-{name}")

output = os.path.join("assets", "css", "heroicons-safelist.html")
with open(output, "w") as fh:
    fh.write("<!-- Auto-generated: all outline + solid heroicons for Tailwind bundling -->\n")
    for c in classes:
        fh.write(f'<span class="{c}"></span>\n')

print(f"Generated {len(classes)} icon references in {output}")
