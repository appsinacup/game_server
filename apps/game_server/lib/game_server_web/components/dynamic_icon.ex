defmodule GameServerWeb.Components.DynamicIcon do
  @moduledoc """
  A tiny runtime SVG loader for hero-style icons stored under
  `priv/static/heroicons/`.

  Usage:

      <.dynamic_icon name={"hero-book-open"} class="w-5 h-5" />

  Behavior:
  - Loads the raw SVG at runtime from priv/static/heroicons/<name>.svg
  - Caches successful reads in an ETS cache for performance
  - Falls back to the compiled `<.icon>` component when the SVG file is
    missing or when the requested name is considered unsafe
  """

  use Phoenix.Component

  @cache_table :dynamic_icon_cache

  # Forgiving whitelist: only letters, numbers, dash and underscore
  @safe_re ~r/^[a-zA-Z0-9_\-]+$/

  attr :name, :string, required: true
  attr :class, :string, default: ""

  def dynamic_icon(assigns) do
    name = assigns.name || ""

    if safe_name?(name) do
      svg = cached_svg_for(name)

      if svg do
        assigns = assign(assigns, :svg, svg)

        ~H"""
        {Phoenix.HTML.raw(@svg)}
        """
      else
        # fallback to the compiled icon markup when available (span + classes)
        ~H"""
        <span class={[@name, @class]} />
        """
      end
    else
      # unsafe name -> render an empty placeholder
      ~H"""
      <svg class={@class} aria-hidden="true"></svg>
      """
    end
  end

  defp safe_name?(name) when is_binary(name) do
    String.trim(name) != "" && Regex.match?(@safe_re, name)
  end

  defp cached_svg_for(name) do
    ensure_cache_table()

    case :ets.lookup(@cache_table, name) do
      [{^name, svg}] ->
        svg

      [] ->
        svg = read_svg_from_priv(name)

        if svg do
          :ets.insert(@cache_table, {name, svg})
          svg
        else
          nil
        end
    end
  end

  defp ensure_cache_table do
    case :ets.info(@cache_table) do
      :undefined -> :ets.new(@cache_table, [:named_table, :public, read_concurrency: true])
      _info -> :ok
    end
  end

  defp read_svg_from_priv(name) do
    # Map name like 'hero-book-open' to a file path under priv/static/heroicons
    path = Path.join(:code.priv_dir(:game_server), "static/heroicons/#{name}.svg")

    case File.read(path) do
      {:ok, content} when is_binary(content) -> content
      _ -> nil
    end
  end
end
