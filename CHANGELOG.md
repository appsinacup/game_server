# April 2026

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
