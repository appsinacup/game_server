### .well-known files for mobile app links

These files belong under `priv/static/.well-known` and are served at the web root via
Plug.Static (we included `.well-known` in the app's `GameServerWeb.static_paths`).

Two important files used by mobile OSes are:

- `apple-app-site-association` (iOS Universal Links, required for iOS app link verification)
- `assetlinks.json` (Android App Links / Digital Asset Links, required for Android verification)

Rules & requirements
- Both must be served over HTTPS (production) at the following paths on the host:
  - `https://your-domain/.well-known/apple-app-site-association`
  - `https://your-domain/.well-known/assetlinks.json`
- `apple-app-site-association` must be served with Content-Type `application/json` and must *not* be compressed (no Content-Encoding: gzip).
- `assetlinks.json` is a JSON array and should be served normally as `application/json`.
