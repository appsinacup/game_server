# Translations (gitignored)

Local working directory for translation CSV files.
These files are **not committed** — they are working files for translators.

| Strings | Domains | Languages |
|---------|---------|-----------|
| 148 | default (89), errors (29), notifications (30) | 30 |

## CSV export / import

```bash
# Export English strings to CSV
mix gettext.export_csv en --output translations/en.csv

# Export any language
mix gettext.export_csv es --output translations/es.csv

# Import translated CSV back into PO files
mix gettext.import_csv es translations/es.csv

# Dry-run import (preview only)
mix gettext.import_csv es translations/es.csv --dry-run
```
