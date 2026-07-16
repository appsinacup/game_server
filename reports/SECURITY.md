# Security Audit — gamend (game_server umbrella)

This audit reviewed authentication/authorization, the plugin hook RPC surface, payment webhooks and receipt validation, rate limiting, injection, secrets, and CORS/socket configuration by reading the actual source. The most serious issue is that Apple in-app-purchase receipts and App Store notifications are verified against a signing certificate taken from the attacker-controlled JWS header without validating the certificate chain back to Apple's root CA, letting any authenticated user forge purchases and grant themselves paid entitlements for free. A second class of high-impact issues is OAuth account takeover via unverified-email linking and an authorization-guard bypass on the WebRTC DataChannel hook-RPC path. Injection surfaces (SQL, path traversal) were checked and are consistently parameterized/escaped — no injection findings. Most IDOR-prone controllers correctly verify ownership/membership.

| Severity | Count |
|----------|-------|
| Critical | 1 |
| High | 3 |
| Medium | 3 |
| Low | 4 |
| Informational | 2 |

---

## Critical

### Apple IAP receipts & App Store notifications are forgeable (no cert-chain trust)

- **Location**: `apps/game_server_core/lib/game_server/payments/providers/apple.ex:300-345` (`Apple.JWS.verify_and_decode/1`, `jwk_from_x5c/1`); reached from `apple.ex:28-43` (`validate_purchase/2`, `verify_notification/1`) and `apps/game_server_core/lib/game_server/payments.ex:275-298` (`validate_store_purchase/3`), `payments.ex:496-508` (`handle_apple_webhook/1`).
- **Issue**: `verify_and_decode/1` extracts the leaf certificate from the JWS `x5c` header (`jwk_from_x5c/1`) and calls `JOSE.JWS.verify_strict(jwk, ["ES256"], compact_jws)` against that same embedded certificate. It never validates that the certificate chains to Apple's App Store root CA (no `x5c` chain verification, no pinned root). Any self-signed ES256 certificate placed in the `x5c` header will pass. The module docstring even acknowledges it only "verifies the JWS signature".
- **Exploit/Impact**: An authenticated user calls `POST /api/v1/payments/validate/apple` with a self-crafted JWS whose payload sets `bundleId` to the server's configured bundle id (checked at `apple.ex:139-151`), a `productId` matching any configured Apple `ProviderProduct`, and a unique `transactionId`. `validate_store_purchase/3` accepts it, `get_provider_product("apple", external_id)` resolves the product, the transaction id is unseen, and `create_validated_store_purchase/…` fulfills the purchase — granting the entitlement (and any download/`grant_config` it unlocks) at no cost. The same forgery works unauthenticated against `POST /api/v1/payments/webhooks/apple`, which processes `decoded_transaction_info` from the same untrusted JWS. Replay is limited only by `transaction_id` uniqueness, which the attacker controls.
- **Fix**: Verify the full `x5c` certificate chain against Apple's App Store root CA (`AppleRootCA-G3`) with validity/purpose checks before trusting the leaf key, e.g. via `:public_key.pkix_path_validation/3`, or use a vetted App Store Server library (`app_store_server_api` / StoreKit JWS verification) that performs chain validation. Reject payloads whose leaf does not chain to the pinned Apple root.
- **Confidence**: Confirmed (code). Exploitability requires the Apple provider to be configured with at least one `ProviderProduct`; the signature-trust flaw itself is unconditional.

---

## High

### OAuth login links providers to existing accounts by email without verifying `email_verified` (account takeover)

- **Location**: `apps/game_server_core/lib/game_server/accounts.ex:1029-1075` (`handle_provider_id_missing/3`, `handle_by_email/4`); attrs built in `apps/game_server_web/lib/game_server_web/controllers/auth_controller.ex:479-522`, `auth_controller.ex:1094-1117`. No `email_verified`/`verified_email` check exists anywhere (grep returns none).
- **Issue**: When an OAuth login presents a provider account whose id is not yet known but whose email matches an existing user, the provider id is attached to that existing account and the caller is logged in as that user. The provider's email-verification status is never checked.
- **Exploit/Impact**: A victim registers with email+password (or a different provider) using `alice@example.com`. An attacker creates an account on a provider that does not guarantee verified emails (or lets the user set an arbitrary email) as `alice@example.com`, then completes OAuth login. The server links that provider to the victim's account and issues tokens for the victim — full account takeover. `find_or_create_from_google` via `api_google_id_token` is included; the Google id_token path (`oauth/google_id_token.ex`) does not assert the `email_verified` claim either.
- **Fix**: Only auto-link by email when the provider asserts a verified email (check `email_verified`/`verified_email` per provider, e.g. Google id_token `email_verified == true`). Otherwise create a distinct account or require an explicit, authenticated link step. Consider disabling implicit email-based linking entirely and only linking when a user is already authenticated.
- **Confidence**: Likely (impact depends on which providers are enabled and their email-verification behavior; Facebook and custom flows are the weakest).

### WebRTC DataChannel hook-RPC bypasses the reserved-hook allowlist and arg limits

- **Location**: `apps/game_server_web/lib/game_server_web/channels/webrtc_peer.ex:321-343` (`maybe_handle_rpc/3`). Compare with the guarded paths: `apps/game_server_web/lib/game_server_web/controllers/api/v1/hook_controller.ex:124-183` (arg count/size + `reserved_hook_name?`) and `apps/game_server_web/lib/game_server_web/channels/user_channel.ex:99-125` (reserved check).
- **Issue**: The DataChannel `call_hook` handler calls `PluginManager.call_rpc(plugin, func, args, caller: user)` directly with no `GameServer.Hooks.internal_hooks()` reserved-name check and no `max_hook_args_count`/`max_hook_args_size` validation. `PluginManager.resolve_function_atom/3` resolves any exported function on the plugin's `hooks_module`, including internal lifecycle callbacks (`before_kv_get`, `after_purchase_fulfilled`, `after_user_deleted`, `after_score_submitted`, `on_custom_hook`, …).
- **Exploit/Impact**: An authenticated user who negotiates a WebRTC peer (offer via `user_channel` `webrtc:offer`) can send `{"type":"call_hook","plugin":…,"fn":"before_kv_get","args":[…]}` to invoke lifecycle hooks that are explicitly blocklisted on the HTTP and user_channel paths, and can pass arbitrarily large `args` (no size cap) for resource exhaustion. Depending on plugin implementation, directly invoking `after_*`/`before_*` callbacks with attacker-supplied arguments can cause unintended side effects. This is an authorization-guard inconsistency: the same operation is blocked on two of three entry points.
- **Fix**: Extract the HookController's validation (reserved-name rejection + arg count/size limits) into a shared function and apply it in `maybe_handle_rpc/3` before calling `PluginManager.call_rpc`.
- **Confidence**: Confirmed (code).

### Plugin hook RPC exposes every exported plugin function to any authenticated user

- **Location**: `apps/game_server_core/lib/game_server/hooks/plugin_manager.ex:108-149, 430-439` (`call_rpc/4`, `resolve_function_atom/3`); entry points `hook_controller.ex:invoke`, `user_channel.ex`, `webrtc_peer.ex`.
- **Issue**: The only restriction on which plugin functions a client may invoke is the reserved-name blocklist (`internal_hooks/0`) plus the scheduled-callback check — and even those are enforced only in the controller/user_channel, not in `call_rpc` itself. There is no positive allowlist. Every other public function exported by the plugin's `hooks_module` (helpers, arbitrary business logic, anything the plugin author did not intend to expose as an RPC) is callable by any authenticated user with attacker-controlled arguments.
- **Exploit/Impact**: A plugin that exports internal helper functions (common in Elixir, where "private" intent is only conveyed by `defp`) inadvertently exposes them as RPCs. Combined with the caller being injected into the process dictionary, this is a broad and easily-misused attack surface; the security boundary depends entirely on plugin authors exporting nothing sensitive.
- **Fix**: Require plugins to declare an explicit RPC allowlist (e.g. via the dynamic-RPC `exports` registry that already exists in `DynamicRpcs`) and reject any `call_rpc` for a function not on that allowlist, rather than allowing all module exports minus a blocklist.
- **Confidence**: Confirmed (design).

---

## Medium

### Google Play webhook fails open when RTDN token is not configured

- **Location**: `apps/game_server_core/lib/game_server/payments/providers/google.ex:298-317` (`verify_rtdn_token/1`), reached from `payments.ex:482-493` and `POST /api/v1/payments/webhooks/google`.
- **Issue**: When `GOOGLE_PLAY_RTDN_TOKEN` is unset/empty, `verify_rtdn_token(nil)` and `verify_rtdn_token(_)` return `:ok`, so the webhook accepts unauthenticated requests. Google recommends a shared bearer token on the Pub/Sub push endpoint; if the operator has not set one, there is no authentication on this endpoint at all.
- **Exploit/Impact**: Anyone can POST crafted RTDN envelopes. Direct entitlement forgery is mitigated because `process_google_event` re-validates purchase tokens against the Google Publisher API (needs real credentials), but forged notifications referencing existing/real purchase tokens can drive state transitions (e.g. revoke/refund processing → griefing, or re-processing) and consume resources. The failure mode is silent (no warning that the endpoint is unauthenticated).
- **Fix**: Require `GOOGLE_PLAY_RTDN_TOKEN` (or verify the Pub/Sub OIDC JWT) in production; fail closed when unconfigured, or gate the route behind a feature flag that is off until a token is set.
- **Confidence**: Likely (config-dependent). Needs-verification on the exact side effects of `process_google_event` for forged tokens.

### `/metrics` authorization relies on source IP and is not constant-time

- **Location**: `apps/game_server_web/lib/game_server_web/plugs/metrics_auth.ex:39-66, 69-74`; IP set by `apps/game_server_web/lib/game_server_web/plugs/real_ip.ex:44-101`; route pipeline `router/shared.ex:483-487`.
- **Issue**: `MetricsAuth` allows any request whose `conn.remote_ip` is in a private/loopback range with no token. `RealIp` only rewrites `remote_ip` from `X-Forwarded-For` when the direct peer is a trusted proxy, and if all XFF entries are themselves "trusted" (private) it returns `:error` and leaves `remote_ip` as the proxy's private address (`real_ip.ex:48-57, 92-101`) — which `MetricsAuth` then treats as local and serves without a token. Additionally the token check uses `token == expected` (`metrics_auth.ex:56`), not a constant-time compare.
- **Exploit/Impact**: In deployments where the app trusts a proxy in a private range, a client that can influence `X-Forwarded-For` (or reach the app from within the private network) may retrieve Prometheus metrics without the configured `METRICS_AUTH_TOKEN`, exposing internal operational data. The non-constant-time token compare is a (minor) timing side channel.
- **Fix**: Do not treat "remote_ip is private" as authenticated when behind a proxy; require the bearer token for all non-loopback scrapes, or bind `/metrics` to a separate internal listener. Use `Plug.Crypto.secure_compare/2` for the token.
- **Confidence**: Needs-verification (depends on proxy/network topology); the non-constant-time compare is Confirmed.

### Password change via API does not require the current password

- **Location**: `apps/game_server_web/lib/game_server_web/controllers/api/v1/me_controller.ex:121-136` (`update_password/2`), `PATCH /api/v1/me/password`.
- **Issue**: The endpoint sets a new password using only the access token; it never verifies the current password.
- **Exploit/Impact**: A leaked/stolen access token (15-min TTL) can be escalated into a permanent password reset, locking out the legitimate user. Impact is bounded because the token already grants account access and the change bumps `token_version` (revoking other sessions), but requiring the current password is a standard and expected control that would blunt token-theft escalation.
- **Fix**: Require and verify the current password (or a recent re-authentication) before allowing a password change on this endpoint.
- **Confidence**: Confirmed.

---

## Low

### OAuth changesets cast `:is_admin` (latent mass-assignment)

- **Location**: `apps/game_server_core/lib/game_server/accounts/user.ex:191-296` — `discord_oauth_changeset/2`, `steam_oauth_changeset/2`, `apple_oauth_changeset/2`, `google_oauth_changeset/2`, `facebook_oauth_changeset/2` each `cast(attrs, [..., :is_admin, ...])`.
- **Issue**: These changesets permit `is_admin` to be set from the `attrs` map. Today the callers (`auth_controller.ex:462-522`, `api_google_id_token`) build `attrs` server-side with only `email`/provider-id/`display_name`/`profile_url`, so `is_admin` is never present and this is not currently exploitable. It is a fragile invariant: any future caller that forwards user-controlled params into these changesets would grant privilege escalation.
- **Exploit/Impact**: None today; privilege escalation if a future code path passes client-controlled attrs.
- **Fix**: Remove `:is_admin` from the OAuth `cast/3` lists; set admin only through the dedicated first-user path (`accounts.ex:1077-1080`, `maybe_make_first_user_admin`) and `admin_changeset/2`.
- **Confidence**: Confirmed (present in code); not currently exploitable.

### CORS defaults to `*` when `PHX_ALLOWED_ORIGINS` is unset

- **Location**: `config/host_runtime.exs:361-387` (`cors_allowed_origins` → `"*"`), consumed by `GameServerWeb.Plugs.DynamicCors` (endpoint plug `endpoint.ex:69`).
- **Issue**: With no configured origins, HTTP CORS allows all origins. The JSON API authenticates with bearer tokens (not cookies — `endpoint.ex:65` skips session for `/api/v1`), so cross-origin token theft is limited, but a wildcard default is permissive and easy to ship to production unintentionally.
- **Exploit/Impact**: Low for the token API; any future cookie-authenticated JSON endpoint would be exposed to cross-origin reads.
- **Fix**: Default to a closed/explicit origin list in production and require operators to opt into broader origins.
- **Confidence**: Confirmed.

### Device login enables unauthenticated account creation

- **Location**: `apps/game_server_web/lib/game_server_web/controllers/api/v1/session_controller.ex:118-146` (`create_device/2`), `apps/game_server_core/lib/game_server/accounts.ex:873-912` (`find_or_create_from_device/2`). Rate-limited via the auth bucket (`plugs/rate_limiter.ex:87-89`, path `login`).
- **Issue**: `POST /api/v1/login/device` creates a new user for any `device_id` with no secret, when `DEVICE_AUTH_ENABLED` is true (default true). This is an intentional SDK convenience but permits unbounded anonymous account creation (subject to the per-IP auth rate limit and optional `REQUIRE_ACCOUNT_ACTIVATION`).
- **Exploit/Impact**: Automated creation of throwaway accounts / data growth; a guessable `device_id` scheme could also let one client resume another's device account.
- **Fix**: Document and default-review this in production; consider requiring a signed device attestation or disabling by default. Ensure `device_id` values are high-entropy client secrets.
- **Confidence**: Confirmed (by-design behavior; flagged for risk awareness).

### `refresh` token endpoint is not in the strict auth rate-limit bucket

- **Location**: `apps/game_server_web/lib/game_server_web/plugs/rate_limiter.ex:87-113` — only `login`/`register` path segments map to `auth_bucket`; `POST /api/v1/refresh` falls through to the general bucket (default 240/min vs 10/min).
- **Issue**: Refresh gets the looser general limit. Low impact because a refresh requires a valid signed refresh JWT (not brute-forceable), but it is inconsistent with the intent of throttling auth endpoints.
- **Fix**: Include `refresh` in the auth bucket match, or keep as-is by explicit decision.
- **Confidence**: Confirmed.

---

## Informational

### OAuth API polling returns tokens to any holder of the session id

- **Location**: `apps/game_server_web/lib/game_server_web/controllers/auth_controller.ex:1318-1334` (`api_session_status/2`) returns `access_token`/`refresh_token` stored in the `OAuthSession` data.
- **Issue**: The session id is a 32-byte random value acting as a bearer secret for the polling flow (by design). Anyone who obtains the id before the client polls can retrieve the tokens. No additional binding to the requesting client exists. Ensure the id is never logged or placed in referer-leaking URLs beyond `/auth/success?session_id=…` and that sessions expire quickly.
- **Confidence**: Confirmed (documented design; noted for awareness).

### Positive observations (verified, not findings)

- **SQL injection**: All dynamic `LIKE` queries use `Repo.escape_like/1` with an explicit `ESCAPE '\\'` and parameterized `^` bindings (`repo.ex:28-34`, `accounts.ex:123-171`, `groups.ex:1111-1112`, `lobbies.ex:359-360`, `kv.ex:643-646`, `payments.ex:1973-1977`). `advisory_lock.ex:81-88` uses static SQL with bound parameters. Lobby `metadata_key`/`metadata_value` filtering is done in-memory, not in SQL (`lobbies.ex:200-244`). No string interpolation of user input into queries was found.
- **Path traversal**: `PaymentDownloadController` enforces ownership (`list_user_entitlements` membership) and `safe_basename?/1` (`payment_download_controller.ex:6-19, 33-46, 73`); `WellKnown` serves only two fixed filenames (`well_known.ex:10-18`).
- **Stripe webhook**: Uses the SDK's `construct_event` HMAC verification with a 300s tolerance and event-id dedup (`stripe.ex:77-97`, `payments.ex:334-347`) — properly authenticated and replay-guarded.
- **IDOR checks**: Chat (`can_access_message?`, `authorize_conversation`), notifications (scoped to `user.id`), friends (`handle_delete_friendship` requester/target checks), lobby update/kick (host + own-lobby via `user.lobby_id`), and KV reads (`before_kv_get` + `kv_access_allowed?`) all verify ownership/membership rather than mere authentication. Admin API routes are gated by `RequireAdminApi` (checks `is_admin`) and admin LiveViews by the `require_admin` on_mount.
- **Token revocation**: Guardian embeds a `tv` (token_version) claim and rejects tokens whose `tv` mismatches the user's current `token_version`, and rejects tokens lacking `tv` (`guardian.ex:31-59`) — password/email changes and `revoke_all_tokens` invalidate outstanding tokens.
- **Sockets**: `UserSocket.connect/3` requires a valid JWT and enforces a per-user socket cap (`user_socket.ex:63-86`). Production `check_origin` is derived from `PHX_ALLOWED_ORIGINS` and defaults to Phoenix's host check when unset; `check_origin: false` is only set in `config/dev.exs`.
