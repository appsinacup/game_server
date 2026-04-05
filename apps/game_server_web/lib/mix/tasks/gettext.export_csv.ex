defmodule Mix.Tasks.Gettext.ExportCsv do
  @moduledoc """
  Exports all PO translations and theme JSON config for a locale to CSV.

  ## Usage

      mix gettext.export_csv LOCALE [--output FILE] [--config BASE_PATH]

  ## Examples

      mix gettext.export_csv es
      mix gettext.export_csv es --output translations/es.csv
      mix gettext.export_csv es --config modules/example_config.json

  The CSV has columns: `domain`, `msgid`, `source`, `translation`, `fuzzy`.

  - For PO messages: `source` is empty (the `msgid` itself is the English
    source text), `translation` is the `msgstr` value.
  - `fuzzy` is `"yes"` when the entry is marked fuzzy, otherwise empty.
  - For JSON config: domain is `_config`, `msgid` is the JSON key path,
    `source` is the English reference text from the base config,
    `translation` is the locale text. Edit `translation` to change.

  Empty `translation` cells indicate untranslated strings that need work.
  """
  use Mix.Task

  @shortdoc "Export PO translations and theme config for a locale to CSV"

  @gettext_dir "apps/game_server_web/priv/gettext"

  @impl Mix.Task
  def run(args) do
    {opts, positional, _} =
      OptionParser.parse(args, strict: [output: :string, config: :string])

    locale = List.first(positional) || raise_usage!()
    locale_dir = Path.join([@gettext_dir, locale, "LC_MESSAGES"])

    unless File.dir?(locale_dir) do
      Mix.raise("Locale directory not found: #{locale_dir}")
    end

    output_path = opts[:output] || "translations/#{locale}.csv"

    po_rows = export_po_rows(locale_dir)
    config_rows = export_config_rows(locale, opts[:config]) |> dedup_config_rows()

    all_rows = po_rows ++ config_rows
    csv_content = encode_csv([header_row() | all_rows])
    File.write!(output_path, csv_content)

    Mix.shell().info(
      "Exported #{length(po_rows)} PO + #{length(config_rows)} config = " <>
        "#{length(all_rows)} total translations to #{output_path}"
    )
  end

  defp export_po_rows(locale_dir) do
    locale_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".po"))
    |> Enum.sort()
    |> Enum.flat_map(fn filename ->
      domain = String.replace_suffix(filename, ".po", "")
      path = Path.join(locale_dir, filename)
      {:ok, po} = Expo.PO.parse_file(path)

      Enum.map(po.messages, fn msg -> message_to_row(domain, msg) end)
    end)
  end

  defp header_row do
    ["domain", "msgid", "source", "translation", "fuzzy"]
  end

  defp message_to_row(domain, %Expo.Message.Singular{} = msg) do
    fuzzy = if fuzzy?(msg), do: "yes", else: ""

    [
      domain,
      IO.iodata_to_binary(msg.msgid),
      "",
      IO.iodata_to_binary(msg.msgstr),
      fuzzy
    ]
  end

  defp message_to_row(domain, %Expo.Message.Plural{} = msg) do
    fuzzy = if fuzzy?(msg), do: "yes", else: ""

    [
      domain,
      IO.iodata_to_binary(msg.msgid),
      "",
      IO.iodata_to_binary(Map.get(msg.msgstr, 0, [])),
      fuzzy
    ]
  end

  defp fuzzy?(%{flags: flags}) do
    Enum.any?(flags, fn flag_list ->
      Enum.any?(List.wrap(flag_list), &(&1 == "fuzzy"))
    end)
  end

  # Simple CSV encoding — handles quoting fields that contain commas,
  # quotes, or newlines. No external dependency needed.
  defp encode_csv(rows) do
    rows
    |> Enum.map_join("\n", fn row ->
      Enum.map_join(row, ",", &csv_escape/1)
    end)
    |> Kernel.<>("\n")
  end

  defp csv_escape(value) when is_binary(value) do
    if String.contains?(value, [",", "\"", "\n", "\r"]) do
      "\"" <> String.replace(value, "\"", "\"\"") <> "\""
    else
      value
    end
  end

  defp csv_escape(value), do: csv_escape(to_string(value))

  defp raise_usage! do
    Mix.raise("""
    Usage: mix gettext.export_csv LOCALE [--output FILE] [--config BASE_PATH]

    Example: mix gettext.export_csv es
             mix gettext.export_csv es --config modules/example_config.json
    """)
  end

  # ------------------------------------------------------------------
  # Theme JSON config export
  # ------------------------------------------------------------------

  # Translatable top-level keys
  @config_top_keys ~w(title tagline description)

  # Translatable array fields: {json_key, object_field_for_text}
  @config_array_fields [
    {"useful_links", "title"},
    {"nav_links", "label"},
    {"footer_links", "label"},
    {"features", "title"},
    {"features", "description"}
  ]

  # Deduplicate config rows that share the same English source text.
  # Keeps only the first occurrence (by path). The import script uses
  # source-text matching to apply translations to ALL matching paths.
  defp dedup_config_rows(rows) do
    {_seen, deduped} =
      Enum.reduce(rows, {MapSet.new(), []}, fn row, {seen, acc} ->
        # row = [domain, path, en_val, locale_val, fuzzy]
        en_val = Enum.at(row, 2)

        if MapSet.member?(seen, en_val) do
          {seen, acc}
        else
          {MapSet.put(seen, en_val), [row | acc]}
        end
      end)

    Enum.reverse(deduped)
  end

  defp export_config_rows(locale, config_opt) do
    base_path = detect_config_base(config_opt)

    if base_path do
      en_data = read_config_json(base_path, "en")
      locale_data = if locale == "en", do: en_data, else: read_config_json(base_path, locale)

      if en_data do
        top_rows = config_top_rows(en_data, locale_data || %{})
        array_rows = config_array_rows(en_data, locale_data || %{})
        top_rows ++ array_rows
      else
        []
      end
    else
      []
    end
  end

  defp config_top_rows(en_data, locale_data) do
    Enum.flat_map(@config_top_keys, fn key ->
      en_val = Map.get(en_data, key, "")
      locale_val = Map.get(locale_data, key, "")

      if en_val != "" do
        [["_config", key, en_val, locale_val, ""]]
      else
        []
      end
    end)
  end

  defp config_array_rows(en_data, locale_data) do
    @config_array_fields
    |> Enum.flat_map(fn {array_key, text_field} ->
      en_items = Map.get(en_data, array_key, [])
      locale_items = Map.get(locale_data, array_key, [])

      en_items
      |> Enum.with_index()
      |> Enum.map(fn {en_item, idx} ->
        locale_item = Enum.at(locale_items, idx) || %{}
        path = "#{array_key}[#{idx}].#{text_field}"
        en_val = Map.get(en_item, text_field, "")
        locale_val = Map.get(locale_item, text_field, "")
        ["_config", path, en_val, locale_val, ""]
      end)
    end)
  end

  defp detect_config_base(nil) do
    # Auto-detect: check THEME_CONFIG env, then common patterns
    env_path = System.get_env("THEME_CONFIG")

    cond do
      env_path && env_path != "" ->
        env_path

      File.exists?("modules/example_config.en.json") ->
        # Derive base from .en.json file
        "modules/example_config.json"

      true ->
        nil
    end
  end

  defp detect_config_base(explicit), do: explicit

  defp read_config_json(base_path, locale) do
    # Insert locale before extension: foo.json → foo.LOCALE.json
    ext = Path.extname(base_path)
    stem = String.replace_suffix(base_path, ext, "")
    locale_path = "#{stem}.#{locale}#{ext}"

    if File.exists?(locale_path) do
      locale_path |> File.read!() |> Jason.decode!()
    else
      nil
    end
  end
end
