defmodule GameServer.Theme.JSONConfig do
  @moduledoc """
  JSON-backed Theme provider. Reads a locale-specific JSON file specified by the
  THEME_CONFIG environment variable — e.g. THEME_CONFIG=modules/example_config.json

  Only locale-suffixed files are loaded (e.g. `example_config.en.json`,
  `example_config.es.json`). The base path itself (without a locale suffix) is
  never loaded directly — it serves only as a naming template to derive
  locale-specific paths.

  When THEME_CONFIG is not set, an empty map is returned. There is no implicit
  fallback to packaged defaults — the UI will display blanks until you configure
  a THEME_CONFIG path.

  Theme configs are cached in `:persistent_term` after the first read so
  subsequent requests never hit the filesystem. Call `reload/0` to clear the
  cache (e.g. after editing the JSON file at runtime).
  """

  @behaviour GameServer.Theme

  @impl true
  def get_theme do
    get_theme(nil)
  end

  @doc """
  Variant of `get_theme/0` that prefers a locale-specific THEME_CONFIG file when present.

  Given a base config like `modules/example_config.json` and locale `"es"`, we will
  try `modules/example_config.es.json` first, then fall back to `.en.json`.
  The base file itself is never loaded.
  """
  @spec get_theme(String.t() | nil) :: map()
  def get_theme(locale) when is_binary(locale) or is_nil(locale) do
    cache = :persistent_term.get({__MODULE__, :theme_cache}, %{})

    case Map.get(cache, locale, :not_cached) do
      :not_cached ->
        result = do_get_theme(locale)
        :persistent_term.put({__MODULE__, :theme_cache}, Map.put(cache, locale, result))
        result

      cached ->
        cached
    end
  end

  # Performs the actual file-based theme resolution (uncached).
  #
  # When THEME_CONFIG is not set → empty map.
  # When THEME_CONFIG is set → resolve locale-specific file, load directly
  # (no merging with packaged defaults). Only locale-suffixed files are tried.
  defp do_get_theme(locale) do
    case config_path() do
      nil ->
        # No THEME_CONFIG configured → return empty.
        %{}

      base_path ->
        candidates = locale_only_candidates(base_path, locale)

        case Enum.find_value(candidates, :error, &read_json/1) do
          {:ok, map} when is_map(map) -> normalize_asset_paths(map)
          _ -> %{}
        end
    end
  end

  # Build locale-specific file candidates from the base path.
  # Never includes the base path itself (only locale-suffixed variants).
  # Always includes the ".en" variant as a final fallback.
  defp locale_only_candidates(base_path, locale) do
    locale_variants(locale)
    |> append_if_missing("en")
    |> Enum.map(&localized_config_path(base_path, &1))
  end

  # Appends an item to the end of a list only if it's not already present.
  defp append_if_missing(list, item) do
    if item in list, do: list, else: Enum.reverse([item | Enum.reverse(list)])
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
    # Reset the theme cache so the next get_theme call re-reads from disk.
    :persistent_term.put({__MODULE__, :theme_cache}, %{})
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
    # Read the packaged English default as a reference config. This is only used
    # by `packaged_default/0` for programmatic access (e.g. admin dashboards).
    # It is NOT merged into runtime themes.
    path = Path.join(:code.priv_dir(:game_server_web), "static/theme/default_config.en.json")
    read_json(path)
  end

  @doc """
  Return the packaged default theme config found under
  `priv/static/theme/default_config.en.json` as a map (or an empty map when
  missing/invalid). This is a convenience wrapper for programmatic access
  (e.g. admin dashboards showing reference values). It is NOT merged into
  runtime themes.
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
