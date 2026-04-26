# GameServer Web

Web interface for Gamend GameServer, built with Phoenix Framework. Provides APIs, authentication, and real-time features.

## Installation

Add `game_server_web` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:game_server_web, "~> 1.0.0"}
  ]
end
```

The package includes `priv/gettext` (translations), `priv/static/fonts` (Inter woff2), `priv/static/images` (logos/banners), `priv/static/.well-known` (app association examples), `robots.txt`, and `favicon.ico`. Compiled JS/CSS (`priv/static/assets/`) and game assets (`priv/static/game/`) are excluded — host apps compile their own assets.

## Icons when consuming from Hex

`game_server_web` templates use `<.icon name="hero-..." />`, which renders CSS classes like `hero-x-mark`.

When publishing to Hex, CI strips the GitHub `:heroicons` dependency from the package metadata (Hex only accepts Hex deps), so host apps should provide icon generation themselves.

Recommended setup in your host app:

1. Add Heroicons to host deps:

```elixir
{:heroicons,
 github: "tailwindlabs/heroicons",
 tag: "v2.2.0",
 sparse: "optimized",
 app: false,
 compile: false,
 depth: 1}
```

2. Ensure your Tailwind CSS includes the Heroicons plugin. The shared plugin lives in `apps/game_server_web/assets/vendor/heroicons.js`.

For this monorepo layout (host app at repo root):

```css
@plugin "../../apps/game_server_web/assets/vendor/heroicons";
```

For starter/fork layouts where `game_server_web` is installed as a dependency:

```css
@plugin "../../deps/game_server_web/assets/vendor/heroicons";
```

3. If you extract this into a standalone host app, keep the shared JS/vendor asset tree with the reusable web package or copy the same `vendor/heroicons.js` plugin alongside your web assets so it can still read from `deps/heroicons/optimized`.

If you want your own icon set, keep compatibility by either:
- providing CSS for the same `hero-*` class names used by templates, or
- replacing icon names/component usage in your fork.
