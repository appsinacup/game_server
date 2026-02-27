defmodule GameServerWeb.Gettext.Stats do
  @moduledoc """
  Provides translation completeness statistics for a given locale.

  Parses PO files at runtime using `Expo` (a dependency of Gettext) to count
  total vs. translated strings per domain and overall.

  ## Example

      iex> GameServerWeb.Gettext.Stats.completeness("es")
      %{
        locale: "es",
        domains: [
          %{domain: "auth", translated: 60, total: 60, percent: 100.0},
          ...
        ],
        translated: 366,
        total: 366,
        percent: 100.0
      }
  """

  @priv_dir :code.priv_dir(:game_server_web) |> to_string()
  @gettext_dir Path.join(@priv_dir, "gettext")

  @doc """
  Returns a list of available non-default locale codes (e.g. `["es"]`).

  Discovers locales by listing directories in the gettext priv folder,
  excluding `"en"` (the default/source locale).
  """
  @spec locales() :: [String.t()]
  def locales do
    case File.ls(@gettext_dir) do
      {:ok, entries} ->
        entries
        |> Enum.filter(fn entry ->
          entry != "en" and
            File.dir?(Path.join(@gettext_dir, entry)) and
            not String.ends_with?(entry, ".pot")
        end)
        |> Enum.sort()

      {:error, _} ->
        []
    end
  end

  @doc """
  Returns completeness stats for all non-default locales.

  Returns a list of maps (one per locale), same shape as `completeness/1`.
  """
  @spec all_completeness() :: [map()]
  def all_completeness do
    Enum.map(locales(), &completeness/1)
  end

  @doc """
  Returns translation completeness stats for the given locale.

  Returns a map with `:locale`, `:domains` (list of per-domain stats),
  `:translated`, `:total`, and `:percent` keys.
  """
  @spec completeness(String.t()) :: map()
  def completeness(locale) when is_binary(locale) do
    po_dir = Path.join([@gettext_dir, locale, "LC_MESSAGES"])

    domains =
      case File.ls(po_dir) do
        {:ok, files} ->
          files
          |> Enum.filter(&String.ends_with?(&1, ".po"))
          |> Enum.sort()
          |> Enum.map(fn filename ->
            domain = String.trim_trailing(filename, ".po")
            path = Path.join(po_dir, filename)
            domain_stats(domain, path)
          end)

        {:error, _} ->
          []
      end

    total = Enum.reduce(domains, 0, fn d, acc -> acc + d.total end)
    translated = Enum.reduce(domains, 0, fn d, acc -> acc + d.translated end)

    %{
      locale: locale,
      domains: domains,
      translated: translated,
      total: total,
      percent: if(total > 0, do: Float.round(translated / total * 100, 1), else: 0.0)
    }
  end

  @doc """
  Returns a compact summary string like `"es: 366/373 (98.1%)"`.
  """
  @spec summary(String.t()) :: String.t()
  def summary(locale) do
    stats = completeness(locale)
    "#{locale}: #{stats.translated}/#{stats.total} (#{stats.percent}%)"
  end

  defp domain_stats(domain, path) do
    case Expo.PO.parse_file(path) do
      {:ok, %Expo.Messages{messages: messages}} ->
        # Filter out the header entry (empty msgid)
        entries = Enum.reject(messages, &header?/1)
        total = length(entries)
        translated = Enum.count(entries, &translated?/1)

        %{
          domain: domain,
          translated: translated,
          total: total,
          percent: if(total > 0, do: Float.round(translated / total * 100, 1), else: 0.0)
        }

      {:error, _} ->
        %{domain: domain, translated: 0, total: 0, percent: 0.0}
    end
  end

  defp header?(%Expo.Message.Singular{msgid: [""]}), do: true
  defp header?(_), do: false

  defp translated?(%Expo.Message.Singular{msgstr: msgstr}) do
    msgstr != [""]
  end

  defp translated?(%Expo.Message.Plural{msgstr: msgstr}) do
    Enum.all?(msgstr, fn {_idx, strs} -> strs != [""] end)
  end
end
