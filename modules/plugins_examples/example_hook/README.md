# Example hook plugin

This is a minimal OTP hook plugin example.

## Build

From the repo root:

- `cd modules/plugins_examples/example_hook`
- `mix deps.get`
- `mix compile`

This compiles the plugin into `_build/dev/lib/example_hook/ebin/` (and generates the `.app` file with `hooks_module`).

## Package (plugin bundle)

The server loads plugins from a directory containing an `ebin/` folder.
To create a bundle directory you can drop into `modules/plugins/`:

- `mix plugin.bundle`

This also copies compiled dependency BEAMs into `deps/<dep>/ebin` (excluding `game_server_sdk`) so the server can load them if they are not already available in the server release.

## Run locally

- Set `GAME_SERVER_PLUGINS_DIR=modules/plugins_examples` (or copy the built bundle into `modules/plugins/example_hook`)
- Open the Admin Config page and click **Reload plugins**
- Call a function via the “Hooks - Test RPC” form using:
  - `plugin`: `example_hook`
  - `fn`: `hello` (or `set_current_user_meta`)
