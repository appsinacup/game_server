# September 2026

- [added] **`gamend_core` and `gamend_web` publish to Hex.** Both packages were held back by pigeon: its kadabra-to-mint rewrite sat unreleased for over a year, Hex refuses a package with a git dependency, and the released 2.0.1 would have dragged httpoison and hackney back in. pigeon 2.1.0 shipped, so the dependency points at Hex and CI publishes both packages alongside the SDK.
- [changed] **Push credential errors stop retrying.** pigeon 2.1.0 reports a rejected FCM service account as `:unauthenticated` and Apple's two token-key mismatches as their own responses, instead of folding them into the generic error every dispatcher retried until the attempt budget ran out.
- [fixed] **mint 1.10** — closes two denial-of-service advisories in the HTTP client that push and outbound requests run on.
- [fixed] **Typed text survives a reconnect.** A chat draft or message edit, the login email, the group create/edit forms and the admin live-lobby forms come back after the connection drops; which edit or panel is open now lives in the URL, since a form missing from the re-mounted page cannot be recovered.
- [fixed] **Admin quest and tournament filters** respond again — LiveView only sends change events from inputs inside a form.

# August 2026

- [added] **`mix host.proto.check`** — checks every registered protobuf schema against the JSON actually stored under it, and reports which values fall back to JSON and why. A schema missing one field is not an error anywhere: it simply never encodes, so the optimisation looks shipped and is inert. Covers KV entry values and user/lobby/group/party metadata, takes a captured payload with `--json FILE --message Mod`, and exits 1 so it can gate CI. Also lists what is *not* typed — the KV keys, entities and hooks still going out as JSON.
- [fixed] **Godot binding generation fails loudly.** Godot's headless script runner exits 0 whether or not the script succeeded, so `mix host.proto.gen` reported success while godobuf had written nothing — one `reserved` field it could not parse froze a game's Godot bindings for weeks while Elixir and JS kept regenerating fine. `reserved` is now stripped from godobuf's copy of the proto (it generates no code, and protoc keeps enforcing it), and a run that writes nothing is an error.

- [fixed] **Server scripting works in a release.** Plugins were loaded at runtime but a release boots in embedded mode, which refuses to load them — every plugin failed with `{:error, :embedded}` while the startup banner still counted them as loaded.
- [added] **Brotli for static assets**, alongside the gzip files the digest already wrote.

- [added] **Hero tour video** — a click-to-play walkthrough of the admin panel, quests, store, matchmaking and server hooks; `scripts/screenshots/record_tour.js` re-records it.
- [added] **Image lightbox** — clicking a home-page screenshot opens it full-size (ported from the Polyglot Pirates host).
- [changed] **Home page shows the product** — real screenshots (light and dark) of the admin dashboard, quests, groups, login, store, matchmaking, analytics, runtime hooks and economy pages instead of icons; the hero states that Gamend is backend, player website and admin panel in one. `scripts/screenshots/` recaptures them.
- [added] **News dropdown** in the navigation — blog, changelog, roadmap and guides.
- [changed] **Home page reflects the current feature set** — quests instead of achievements, GDScript/Gleam scripting, and new economy/storage and analytics/observability sections.
- [added] **Friends admin page**
- [added] **Retention admin page**
- [added] **16 new guides**
- [added] **Plugins can be written in GDScript**
- [added] **Plugins can be written in Gleam**
- [added] **Client logs**
- [added] **Logs page filters by client session and user**, and separates client entries from the server's own tail.
- [fixed] **Logins survive a busy database** — the analytics day-marker and daily counters drop a failed write instead of failing the request they ride on.
- [fixed] **Repeat quests** re-arm right away again, instead of once an hour.
- [changed] **Matchmaking is near-instant** — a join sweeps immediately instead of waiting for the tick.
- [added] **Performance guide** — measured throughput, capacity and database choice.
- [added] **Socket buffer size** is configurable — the largest per-connection memory cost.
- [changed] **Logins return sooner** — the last-seen and activity writes moved off the request path.
- [fixed] **Concurrent signups** no longer queue behind each other on SQLite.
- [added] **Load-test harness** — per-feature benchmarks and a capacity journey, in `stress/`.
- [fixed] **Benchmark RPCs** measured an error path, not a locked write.
- [fixed] **Realtime events arrived twice**
- [fixed] **Language flags** are cached, so they no longer pop in after the text.
- [fixed] **Deleting an account deletes its avatar** from storage.
- [changed] **One heading scale** across the shipped pages.
- [added] **Player analytics** — D1 / D7 / D30
- [fixed] **Accessible theme colors**
- [added] **RULES.md** — design & accessibility rules.
- [added] **Grouped** quests.
- [added] **Repeat** quest reset type.

# July 2026

- [breaking] **Renamed to Gamend.**
- [added] **Captcha** on the register and magic-link forms
- [added] **Chat moderation** — word filter, report queue, mutes
- [breaking] **One theme file**
- [added] **Translation pipeline**
- [added] All **30 locales fully translated** (machine-translated, pending review).
- [added] **Icons everywhere** — `icon_url` on notifications, tournaments, groups and leaderboards;
- [added] **Quest chains** are browsable; a chain lists as one quest.
- [breaking] **API paths use underscores**
- [breaking] One **pagination meta** shape on every list response.
- [added] **API conventions** spec + `mix gamend.api.lint` in precommit and CI.
- [added] **Settings**: one declared config surface.
- [changed] **Guides are markdown files.** `/docs/setup`
- [changed] **Times are shown in the reader's timezone.**
- [added] Retention for every unbounded table.
- [added] **Ready checks**
- [added] **Push notifications**
- [added] **Lobby state**
- [added] **Quests / progression**.
- [breaking] **Achievements removed** — replaced by permanent quests
- [added] **Economy**.
- [added] **Inventory**.
- [added] **Object storage** — with local-disk and S3/R2 backends; presigned avatar uploads.
- [added] Admin **Oban Web** dashboard at `/admin/oban` + jobs/storage.
- [added] **Lobby snapshots** — opt-in via `LOBBY_SNAPSHOTS_ENABLED`.
- [added] **Matchmaking** (ticket queue), admin page and hooks.
- [added] **Party matchmaking**, matched as one unit.
- [added] **Tournaments** (bracket system).
- [added] **User blacklist**, enforced in matchmaking and lobbies.
- [added] **Admin runtime page**: hooks, env vars, protobuf, channels, events, ER diagram, plugins, jobs.
- [added] Protobuf realtime format (opt-in).
- [changed] Realtime state events send full payloads.
- [removed] JSON delta encoding.
- [removed] Dead modules and client delta code.
- [added] **Unique usernames**.
- [breaking] **UUIDv7 string ids**.
- [added] JWT revocation.
- [added] Persistent IP bans.
- [added] Redis rate limiting.
- [added] Data retention pruning.
- [added] New plugin hooks.
- [added] Observability metrics.
- [security] Auth, payments, RPC hardening.
- [perf] Faster broadcasts and queries.
- [fixed] WebRTC RPC replies.

# April 2026

- [changed] Root host app restructure.
- [added] Browser theme color, sitemap.xml, robots.txt.
- [added] **Native HTTPS**
- [added] **Account Activation** beta mode.
- [added] Translations: Spanish, French, Romanian.
- [added] Roadmap page.
- [added] Security: RealIp, IP bans, OAuth CSRF, rate limiting, WebRTC - limits, security headers.
- [added] **OPENAPI_ENABLED** feature gate.

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
