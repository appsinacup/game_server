defmodule GameServer.Theme do
  @moduledoc """
  Behaviour for pluggable site theming providers.

  Implementations should provide a map-like theme object that the UI
  and templates can render from. We ship a small JSON-backed default
  implementation that reads a JSON file (see GameServer.Theme.JSONConfig).

  Recommended keys in the theme map:
    - "title" (string)
    - "tagline" (string)
    - "css" (string: public path to a CSS file such as "/theme/theme.css")
    - "logo" (public URL path)
    - "banner" (public URL path)
    - "metadata" (map)
  """

  @callback get_theme() :: map()
  @callback get_setting(key :: atom() | String.t()) :: any()
  @callback reload() :: :ok | {:error, term()}
end
