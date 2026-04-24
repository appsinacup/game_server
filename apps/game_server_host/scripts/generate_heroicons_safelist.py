#!/usr/bin/env python3
"""Generate heroicons safelist for Tailwind CSS bundling (outline + solid)."""
import os

icons_dir = os.path.join("deps", "heroicons", "optimized")
classes = []

for suffix, subdir in [("", "24/outline"), ("-solid", "24/solid")]:
    full_dir = os.path.join(icons_dir, subdir)
    for filename in sorted(os.listdir(full_dir)):
        if filename.endswith(".svg"):
            name = filename[:-4] + suffix
            classes.append(f"hero-{name}")

output = os.path.join(
    "apps", "game_server_host", "assets", "css", "heroicons-safelist.html"
)

with open(output, "w", encoding="utf-8") as file_handle:
    file_handle.write(
        "<!-- Auto-generated: all outline + solid heroicons for Tailwind bundling -->\n"
    )
    for icon_class in classes:
        file_handle.write(f'<span class="{icon_class}"></span>\n')

print(f"Generated {len(classes)} icon references in {output}")