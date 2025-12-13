# OTP Hooks Plugins — Implementation Plan

Date: 2025-12-12

## Goals

- Support **multiple hooks plugins** shipped independently of the main server’s Mix deps.
- Each plugin is a **real OTP application** (ships an `.app` file).
- Plugins live under `modules/plugins/*` and are discovered automatically.
- Lifecycle callbacks **fan-out** to all loaded plugin hook modules.
- The RPC endpoint `POST /api/v1/hooks/call` accepts **three explicit fields**:
  - `plugin` (string)
  - `fn` (string)
  - `args` (array)
- No backwards compatibility for the old `fn="plugin:fn"` shape.
- No filesystem watcher/hot reload daemon initially; instead provide an **Admin “Reload plugins” button** and show per-plugin load/start errors.
- Add a new lifecycle callback `before_stop/0` that is called for each plugin module before the plugin app is stopped/unloaded during reload.

## Non-goals (for the first iteration)

- No dynamic compilation of plugins inside the running server.
- No automatic dependency fetching at runtime (no Mix/Hex in production runtime).
- No support for NIF-heavy dependencies (can be revisited later).
- No “hot swap” without an admin-triggered reload (file watcher can be added later).

## Key constraints

- Plugins must be compiled against a compatible **Elixir + OTP** version to the server runtime.
- Plugins must ship compiled BEAMs for **their own code and their dependencies**.
- The server must be changed once to include a plugin loader/registry; thereafter plugins can be added/updated by shipping plugin bundles.

## Plugin format (what is placed in `modules/plugins/`)

Each plugin is a directory:

```
modules/plugins/<plugin_name>/
  ebin/
    <plugin_app>.app
    Elixir.GameServer.Modules.<YourHook>.beam
    ...
  deps/
    <dep_app_1>/ebin/*.beam
    <dep_app_2>/ebin/*.beam
  priv/ (optional)
```

Notes:
- `<plugin_app>` is the OTP application name (atom) used by `Application.load/1`.
- `<plugin_name>` on disk must equal `<plugin_app>` (string form), e.g. `polyglot_hook`.

## Entry point discovery (no custom manifest)

We store the hook entrypoint in the plugin’s `.app` environment.

- `.app` env key: `hooks_module`
- Value: `'Elixir.GameServer.Modules.PolyglotHook'` (charlist) or `"Elixir...."` (string)

Example excerpt from `ebin/polyglot_hook.app`:

```erlang
{env, [
  {hooks_module, 'Elixir.GameServer.Modules.PolyglotHook'}
]}.
```

Optional future env keys (not required in v1):
- `sdk_vsn_req` (e.g. `"~> 0.3"`) for compatibility checks.
- `server_vsn_req` for server compatibility checks.

## Server-side components (to implement)

### 1) Plugin loader + registry

Add a small module that:

- Scans `modules/plugins/*`.
- For each plugin directory:
  - Computes candidate code paths:
    - `modules/plugins/<plugin>/ebin`
    - `modules/plugins/<plugin>/deps/*/ebin`
  - Calls `Code.append_path/1` for each existing `ebin` directory.
  - Calls `Application.load(String.to_atom(plugin))`.
  - Reads `:application.get_key(plugin_app, :env)` and extracts `hooks_module`.
  - Optionally starts the plugin app:
    - `Application.ensure_all_started(plugin_app)`
    - If startup fails, record the error and keep the plugin marked as failed.
- Produces a registry structure kept in memory (ETS or GenServer state):
  - `plugin_app => %{status: :ok | {:error, reason}, hooks_module: module | nil, vsn: ..., loaded_at: ...}`

**Error handling requirements**
- One broken plugin must not prevent loading other plugins.
- Registry must keep errors so the Admin UI can display them.

### 2) Fan-out lifecycle dispatcher

Change lifecycle hook execution so it calls:

- The existing configured hooks module (if you still want it), AND/OR
- All loaded plugin hook modules

For this plan we will implement **fan-out to all plugin hook modules**.

Rules:
- If a plugin module does not export a given callback/arity, skip it.
- Each plugin callback runs inside the existing safe wrapper pattern (Task + timeout + rescue/catch).
- The lifecycle hook call should not crash the server if one plugin fails.

### 3) RPC call API update

Update OpenAPI spec and controller behavior:

`POST /api/v1/hooks/call`

Request body:

```json
{
  "plugin": "polyglot_hook",
  "fn": "set_current_user_meta",
  "args": ["lang", "en"]
}
```

Controller behavior:
- Validate `plugin` and `fn` are non-empty strings.
- Look up `plugin` in the plugin registry.
- Resolve `hooks_module` from registry.
- Invoke: `apply(hooks_module, String.to_atom(fn), args)` using the same safe wrapper/timeout strategy as current hooks.
- Return:
  - `200` with `{ok: true, result: ...}` on success
  - `400` with `{error: ...}` on validation errors or plugin/module/function not found

No backwards compatibility:
- Requests using `fn="plugin:fn"` must return `400`.

### 4) Admin “Reload plugins” UI

Extend the existing admin config LiveView:

- Show a “Plugins” section listing:
  - plugin name
  - version (from `.app`)
  - hooks module
  - status (`ok` / `error`) + error details
  - last loaded time
- Add a button: “Reload plugins”
  - On click, call the loader’s reload routine
  - After reload, call `after_startup/0` on all plugin modules that export it
  - Display a summarized result and per-plugin errors

No watcher in v1:
- No background file watching; reload is manual via the admin button.

## Plugin build & packaging workflow

Two supported workflows (same output bundle format):

### A) Plugin builds itself (recommended)

- Plugin repo is a normal Mix project.
- It depends on `game_server_sdk` at compile time.
- CI (or local) produces the bundle directory structure under `dist/`.
- Deployment copies `dist/<plugin_name>` into the server’s `modules/plugins/<plugin_name>`.

### B) Server Docker image builds plugins

- Dockerfile includes an optional build stage that:
  - clones or copies plugin sources
  - runs `mix deps.get` and `mix compile` for each plugin
  - copies the compiled `ebin/` + deps `ebin/` into `modules/plugins/` in the final image

## Testing strategy

- Unit tests for the plugin loader:
  - loads a fake plugin directory with a tiny `.app` + `.beam` fixture
  - verifies registry entries and error capture
- Controller tests for `POST /api/v1/hooks/call`:
  - plugin not found -> 400
  - plugin found but function missing -> 400
  - successful call -> 200
- LiveView tests (light):
  - “Plugins” section renders
  - “Reload plugins” triggers reload path (can stub loader)

## Security / safety notes

- Do not execute arbitrary Elixir code from plugin directories.
- Prefer `.app` metadata + BEAM loading rather than evaluating `.exs` manifests.
- Keep timeouts and isolation for plugin calls to avoid server stalls.

## Acceptance criteria

- Dropping a valid plugin bundle into `modules/plugins/<plugin>` and restarting server loads it and shows status in Admin.
- Calling `POST /api/v1/hooks/call` with `{plugin, fn, args}` routes to the plugin’s `hooks_module`.
- Lifecycle callbacks fan out across all loaded plugins.
- Admin “Reload plugins” reloads registry and calls `after_startup/0` fan-out.
- `mix precommit` passes.
