# April 2026

- [changed] Host-owned static files and the endpoint implementation now live directly in the host app. The host router now owns the route table directly and references reusable web modules explicitly. Hex-incompatible `heroicons` ownership also moved to the host.
- [changed] **Notification titles now include full context**: system notification titles contain all relevant info (user names, group/lobby/party names) instead of generic labels. The separate content/subtitle field is no longer used for system notifications. The notifications LiveView table no longer displays the Content column.
- [added] **CI/CD Hex publish**: the existing `publish-hex` job in `build-and-check.yml` now also publishes `game_server_core` and `game_server_web` to Hex.pm on main branch pushes.
- [changed] Include `priv/` in Hex package files for both core (migrations) and web (static assets, translations).

- [added] **Browser theme color**: new `theme_color` field in theme JSON config tints the browser chrome (address bar / tab bar) in Safari and Chrome. Supports a single color string or separate light/dark variants.
- [added] **Dynamic sitemap.xml**: auto-generated sitemap listing all public pages and blog posts for search engine discovery.
- [added] **Comprehensive robots.txt**: blocks AI crawlers (GPTBot, ClaudeBot, CCBot, etc.), aggressive SEO bots, and restricts search engines to public pages only.
- [fixed] `ContentAssetController` crash when bots request `/content/:type` with no path segments (`Path.join([])` error).
- [added] **CSP blob: support**: `frame-src 'self' blob:` added to Content Security Policy to allow PDF viewers in iframes.
- [added] **Native HTTPS support**: serve TLS directly from Phoenix/Bandit without a reverse proxy. Set `SSL_CERTFILE` and `SSL_KEYFILE` env vars to enable.
- [added] **Account Activation (Beta Mode)**: set `REQUIRE_ACCOUNT_ACTIVATION=true` to require admin approval for new accounts before they can log in. Admins can activate/deactivate users from the admin panel and API.
- [added] **Translations** for Spanish, French, Romanian.
- [changed] Moved some menu items under dropdowns.
- [changed] Add translation support for Achievements under metadata through admin portal (same as for Leaderboards).
- [fixed] Dark mode flash (FOUC) on full page navigations — theme is now set server-side via cookie.
- [fixed] Plugin bundles now include `priv/` assets for direct and transitive runtime dependencies, so NIF-based plugins work correctly in Docker/self-hosted deployments.
- [added] **Roadmap** page.
- [changed] Make min password configurable and default to 8 characters.
- [added] **Security hardening**: RealIp plug extracts true client IP from proxy headers (CF-Connecting-IP, Fly-Client-IP, X-Forwarded-For) with CIDR-based trusted proxy validation.
- [added] **IP ban enforcement**: ETS-based IP ban plug with permanent and time-limited bans via `GameServerWeb.Plugs.IpBan.ban/2`.
- [added] **OAuth CSRF protection**: browser OAuth flows (Discord, Google, Facebook, Apple) now include a `state` nonce validated against the session to prevent login CSRF attacks.
- [added] **LiveView rate limiting**: magic link login and registration form submissions are rate limited per client IP.
- [added] **WebRTC hardening**: DataChannel count limit (1), message size limit (64KB), separate ICE candidate rate limit (50/30s).
- [changed] WebSocket connections now require authentication — anonymous socket connections are rejected.
- [changed] Socket ID set to `"user_socket:<user_id>"` for force-disconnect capability.
- [changed] Auth rate limiting expanded to cover browser login, registration, and OAuth routes.
- [added] **Feature gating**: set `OPENAPI_ENABLED=false` to disable Swagger UI and OpenAPI JSON endpoints; set `DOCS_ENABLED=false` to disable the public docs page.
- [added] **Security headers**: baseline headers (X-Content-Type-Options, X-Frame-Options, Referrer-Policy, Permissions-Policy, CORP, X-Permitted-Cross-Domain-Policies) on all responses via SecurityHeaders plug. Conditional HSTS over HTTPS.
- [added] **Admin Rate Limiting page** (`/admin/rate-limiting`): dedicated dashboard for managing IP bans and monitoring rate limit load in real-time with auto-refreshing stats.
- [changed] `x-request-time` response header no longer exposed in production (prevents server timing side-channel).
- [changed] `x-request-id` response header stripped in production (request ID still available in logs via `conn.assigns`).
- [changed] Rate limiter now returns proper HTML error page for browser requests and JSON `{"error":"Too Many Requests"}` for API requests instead of plain text.
- [added] **Prometheus metrics** via PromEx: auto-instruments Phoenix routes (request count, duration, status), Ecto queries, BEAM VM stats. Exposes `/metrics` endpoint for Prometheus/Grafana scraping.
- [added] **Geo traffic analytics**: reads Cloudflare `CF-IPCountry` header to track request origins by country. Admin dashboard shows top countries with flag emojis, auto-refreshing.
- [added] **Dependency vulnerability audit**: `mix_audit` added to precommit — `mix deps.audit` now runs automatically to check for known CVEs.

# March 2026

- [changed] Make Leaderboards accept label instead of user_id.
- [added] Initial version of **Achievements**.
- [added] Initial version of **Rate Limiting**.
- [changed] Self-hosted Inter font and eliminated all inline scripts.
- [added] Initial version of **WebSocket** updates.
- [added] Initial version of **WebRTC** updates.
- [changed] Admin interface with realtime connections view.

# Feb 2026

- [added] Initial version of **CHANGELOG** and **Blog**.
- [added] Initial version of **Groups**.
- [added] Initial version of **Parties**.
- [added] Initial version of **Notifications**.
- [added] Initial version of **Chat**.
