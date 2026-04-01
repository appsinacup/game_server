# Translations (gitignored)

This folder holds CSV files exported by `mix gettext.export_csv`.
These files are **not committed** — they are working files for translators.

## Usage

```bash
# Export English translations to CSV (includes JSON config strings)
mix gettext.export_csv en --output translations/en.csv

# Export Spanish translations
mix gettext.export_csv es --output translations/es.csv

# Import updated CSV back into PO files + JSON config
mix gettext.import_csv es translations/es.csv

# Dry-run import (preview changes without writing)
mix gettext.import_csv es translations/es.csv --dry-run
```
