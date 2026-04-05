#!/usr/bin/env python3
"""Convert plural PO entries to non-plural in all errors.po/pot files."""
import re
import glob

files = glob.glob('apps/game_server_web/priv/gettext/**/errors.po', recursive=True)
files += glob.glob('apps/game_server_web/priv/gettext/errors.pot')
print(f'Processing {len(files)} files')

pattern = r'(msgid "[^"]*")\nmsgid_plural "[^"]*"\n(?:msgstr\[\d+\] "[^"]*"\n?)+'

def replace_plural(m):
    msgid = m.group(1)
    return f'{msgid}\nmsgstr ""\n'

for f in sorted(files):
    with open(f) as fh:
        content = fh.read()
    
    old_count = content.count('msgid_plural')
    new_content = re.sub(pattern, replace_plural, content)
    new_count = new_content.count('msgid_plural')
    
    if old_count != new_count:
        with open(f, 'w') as fh:
            fh.write(new_content)
        print(f'  {f}: removed {old_count - new_count} plural entries')
    else:
        print(f'  {f}: no changes (had {old_count} plurals)')
