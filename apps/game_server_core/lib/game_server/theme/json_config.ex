defmodule GameServer.Theme.JSONConfig do
  @moduledoc """
  JSON-backed Theme provider. Reads a JSON file specified by the THEME_CONFIG
  environment variable (single canonical runtime source) — e.g. THEME_CONFIG=theme/custom.json

  The path may be relative to the project root (eg. "theme/default_config.json")
  or an absolute path. When the file is missing we fall back to the built-in
  default at `priv/static/theme/default_config.json`.

  This implementation keeps things simple: every call will parse the JSON file
  and return a map. There's also a `reload/0` API for callers who want to
  force a re-read (not required for normal usage).
  """

  @behaviour GameServer.Theme

  # Path relative to the app's priv dir
  @default_path "static/theme/default_config.json"

  @impl true
  def get_theme do
    get_theme(nil)
  end

  @doc """
  Variant of `get_theme/0` that prefers a locale-specific THEME_CONFIG file when present.

  Given a base config like `modules/example_config.json` and locale `"en"`, we will
  try `modules/example_config.en.json` first (and fall back to the base file).
  """
  @spec get_theme(String.t() | nil) :: map()
  def get_theme(locale) when is_binary(locale) or is_nil(locale) do
    base_path = config_path() || @default_path
    path_candidates = runtime_path_candidates(base_path, locale)

    # Load packaged defaults first (read_default always returns {:ok, map}
    # including a baked-in fallback). If the runtime THEME_CONFIG path points
    # at a JSON file we'll merge the runtime file over the defaults so missing
    # keys are filled in.
    default =
      case read_default() do
        {:ok, map} when is_map(map) -> map
        _ -> %{}
      end

    runtime_json =
      Enum.find_value(path_candidates, :error, fn p ->
        read_json(p)
      end)

    case runtime_json do
      {:ok, map} when is_map(map) ->
        # Ignore runtime-provided empty strings/nil values so packaged defaults
        # are not accidentally overwritten by blank values.
        cleaned = clean_runtime_map(map)
        cleaned_runtime = Map.merge(default, cleaned)

        # Normalize asset keys so authors can use relative paths like
        # "custom/example_logo.png" in their runtime JSON and the web UI will
        # treat them as web-accessible paths ("/custom/example_logo.png").
        normalize_asset_paths(cleaned_runtime)

      _ ->
        default
    end
  end

  # Recursively remove keys whose values are nil, empty strings, or empty
  # maps. This ensures runtime JSON won't overwrite packaged defaults with
  # blank values at any nesting level.
  defp clean_runtime_map(map) when is_map(map) do
    map
    |> Enum.reduce(%{}, fn {k, v}, acc ->
      case v do
        nil ->
          acc

        s when is_binary(s) ->
          if String.trim(s) == "", do: acc, else: Map.put(acc, k, s)

        m when is_map(m) ->
          cleaned = clean_runtime_map(m)
          if map_size(cleaned) > 0, do: Map.put(acc, k, cleaned), else: acc

        other ->
          Map.put(acc, k, other)
      end
    end)
  end

  @impl true
  def get_setting(key) when is_atom(key) do
    get_setting(Atom.to_string(key))
  end

  def get_setting(key) when is_binary(key) do
    Map.get(get_theme(), key)
  end

  @impl true
  def reload do
    # noop for now — get_theme reads fresh each time, keep reload for API
    :ok
  end

  defp config_path do
    # The single canonical runtime configuration source is the THEME_CONFIG
    # environment variable. Treat blank/empty values as unset so accidental
    # empty env vars don't cause the loader to attempt invalid file reads.
    case System.get_env("THEME_CONFIG") do
      p when is_binary(p) ->
        if String.trim(p) == "", do: nil, else: p

      _ ->
        nil
    end
  end

  @doc """
  Returns the runtime THEME_CONFIG path if present and non-blank, otherwise nil.
  This function intentionally treats blank env values as unset.
  """
  def runtime_path do
    case System.get_env("THEME_CONFIG") do
      p when is_binary(p) ->
        if String.trim(p) == "", do: nil, else: p

      _ ->
        nil
    end
  end

  defp runtime_path_candidates(nil, _locale), do: [nil]

  defp runtime_path_candidates(base_path, locale) when is_binary(base_path) do
    locale_variants = locale_variants(locale)

    localized =
      Enum.map(locale_variants, fn loc ->
        localized_config_path(base_path, loc)
      end)

    Enum.reverse([base_path | Enum.reverse(localized)])
  end

  defp locale_variants(nil), do: []

  defp locale_variants(locale) when is_binary(locale) do
    normalized = locale |> String.trim() |> String.downcase()

    primary =
      normalized
      |> String.split(~r/[-_]/, parts: 2)
      |> List.first()

    variants =
      [normalized, primary]
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&Regex.replace(~r/[^a-z0-9]/, &1, "_"))
      |> Enum.uniq()

    variants
  end

  defp localized_config_path(base_path, locale) when is_binary(base_path) and is_binary(locale) do
    ext = Path.extname(base_path)

    if ext == "" do
      base_path <> "." <> locale
    else
      root = String.trim_trailing(base_path, ext)
      root <> "." <> locale <> ext
    end
  end

  defp read_default do
    # Attempt to load the packaged default. If it's missing or invalid we
    # return :error (don't invent a fake title) — callers should handle an
    # empty/default-less case explicitly.
    read_json(Path.join(:code.priv_dir(:game_server_web), @default_path))
  end

  @doc """
  Return the packaged default theme config found under priv/static/theme/default_config.json
  as a map (or an empty map when missing/invalid). This is a convenience wrapper so other
  modules can rely on a single source of truth for the packaged defaults.
  """
  def packaged_default do
    case read_default() do
      {:ok, map} when is_map(map) -> map
      _ -> %{}
    end
  end

  defp read_json(nil), do: :error

  defp read_json(path) when is_binary(path) do
    # If the path is relative to the project root, check it directly.
    candidates = [
      path,
      Path.join(File.cwd!(), path),
      Path.join(:code.priv_dir(:game_server_web), path)
    ]

    Enum.find_value(candidates, :error, fn p ->
      try_decode_file(p)
    end)
  end

  defp try_decode_file(path) when is_binary(path) do
    with true <- File.exists?(path),
         {:ok, content} <- File.read(path),
         {:ok, decoded} when is_map(decoded) <- Jason.decode(content) do
      {:ok, decoded}
    else
      _ -> :error
    end
  end

  defp normalize_asset_paths(map) when is_map(map) do
    Enum.reduce(["css", "logo", "banner", "favicon"], map, fn key, acc ->
      case Map.get(acc, key) do
        v when is_binary(v) -> Map.put(acc, key, normalize_path(v))
        _ -> acc
      end
    end)
  end

  defp normalize_path(value) when is_binary(value) do
    v = String.trim(value)

    cond do
      v == "" -> v
      String.starts_with?(v, "/") -> v
      String.starts_with?(v, "data:") -> v
      Regex.match?(~r/^https?:\/\//i, v) -> v
      true -> "/" <> v
    end
  end
end
