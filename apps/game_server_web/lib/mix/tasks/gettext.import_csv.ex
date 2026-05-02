defmodule Mix.Tasks.Gettext.ImportCsv do
  @moduledoc """
  Imports translations from a CSV file back into PO files and theme JSON config.

  ## Usage

      mix gettext.import_csv LOCALE FILE [--dry-run] [--config BASE_PATH]

  ## Examples

      mix gettext.import_csv es translations_es.csv
      mix gettext.import_csv es translations_es.csv --dry-run
      mix gettext.import_csv es translations_es.csv --config modules/example_config.json

  The CSV must have at minimum the columns: `domain`, `msgid`, `translation`.
  Optional columns: `source`, `fuzzy`.

  Rows with domain `_config` are written to the theme JSON config file.
  All other rows update the corresponding PO files.

  The task matches PO rows by `(domain, msgid)` pair and updates only the
  `msgstr` (translation) fields. It will NOT add new msgids — those must be
  created via `mix gettext.extract --merge`.

  Use `--dry-run` to preview changes without writing files.
  """
  use Mix.Task

  @shortdoc "Import translations from CSV into PO files and theme config"

  @gettext_dirs [
    "priv/gettext",
    "apps/game_server_web/priv/gettext"
  ]

  @impl Mix.Task
  def run(args) do
    {opts, positional, _} =
      OptionParser.parse(args, strict: [dry_run: :boolean, config: :string])

    dry_run? = opts[:dry_run] || false

    case positional do
      [locale, csv_path] -> do_import(locale, csv_path, dry_run?, opts[:config])
      _ -> raise_usage!()
    end
  end

  defp do_import(locale, csv_path, dry_run?, config_opt) do
    locale_dir = Path.join([gettext_dir(), locale, "LC_MESSAGES"])

    unless File.dir?(locale_dir) do
      Mix.raise("Locale directory not found: #{locale_dir}")
    end

    unless File.exists?(csv_path) do
      Mix.raise("CSV file not found: #{csv_path}")
    end

    # Parse CSV into a map: %{domain => %{msgid => row}}
    translations = parse_csv(csv_path)

    # Split config entries from PO entries
    {config_entries, po_translations} = Map.pop(translations, "_config", %{})

    # Import PO translations
    stats = %{updated: 0, skipped: 0, not_found: 0}

    {stats, files_written} =
      po_translations
      |> Enum.sort_by(fn {domain, _} -> domain end)
      |> Enum.reduce({stats, 0}, fn {domain, entries}, {acc_stats, acc_files} ->
        po_path = Path.join(locale_dir, "#{domain}.po")

        if File.exists?(po_path) do
          {domain_stats, written?} = update_po_file(po_path, entries, dry_run?)

          acc_stats = %{
            updated: acc_stats.updated + domain_stats.updated,
            skipped: acc_stats.skipped + domain_stats.skipped,
            not_found: acc_stats.not_found + domain_stats.not_found
          }

          {acc_stats, acc_files + if(written?, do: 1, else: 0)}
        else
          count = map_size(entries)
          Mix.shell().info("  Skipping #{count} entries — #{po_path} not found")
          {%{acc_stats | not_found: acc_stats.not_found + count}, acc_files}
        end
      end)

    # Import config translations
    config_stats = import_config(locale, config_entries, dry_run?, config_opt)

    prefix = if dry_run?, do: "[DRY RUN] ", else: ""

    Mix.shell().info("""

    #{prefix}Import complete:
      PO updated: #{stats.updated}
      PO skipped (unchanged): #{stats.skipped}
      PO not found: #{stats.not_found}
      PO files written: #{files_written}
      Config entries updated: #{config_stats.updated}
    """)
  end

  defp update_po_file(po_path, entries, dry_run?) do
    {:ok, po} = Expo.PO.parse_file(po_path)

    {updated_messages, stats} =
      Enum.map_reduce(po.messages, %{updated: 0, skipped: 0, not_found: 0}, fn msg, acc ->
        msgid_key = extract_msgid(msg)

        case Map.get(entries, msgid_key) do
          nil ->
            {msg, acc}

          row ->
            case apply_translation(msg, row) do
              {:changed, new_msg} ->
                {new_msg, %{acc | updated: acc.updated + 1}}

              :unchanged ->
                {msg, %{acc | skipped: acc.skipped + 1}}
            end
        end
      end)

    # Count CSV entries that didn't match any PO message
    po_msgids = MapSet.new(po.messages, &extract_msgid/1)

    not_found_count =
      entries
      |> Map.keys()
      |> Enum.count(fn key -> not MapSet.member?(po_msgids, key) end)

    stats = %{stats | not_found: stats.not_found + not_found_count}

    written? =
      if stats.updated > 0 and not dry_run? do
        updated_po = %{po | messages: updated_messages}
        content = Expo.PO.compose(updated_po) |> IO.iodata_to_binary()
        File.write!(po_path, content)
        domain = Path.basename(po_path, ".po")
        Mix.shell().info("  Wrote #{stats.updated} updates to #{domain}.po")
        true
      else
        if stats.updated > 0 do
          domain = Path.basename(po_path, ".po")
          Mix.shell().info("  [DRY RUN] Would update #{stats.updated} entries in #{domain}.po")
        end

        false
      end

    {stats, written?}
  end

  defp extract_msgid(%Expo.Message.Singular{msgid: msgid}),
    do: IO.iodata_to_binary(msgid)

  defp extract_msgid(%Expo.Message.Plural{msgid: msgid}),
    do: IO.iodata_to_binary(msgid)

  defp apply_translation(%Expo.Message.Singular{} = msg, row) do
    new_translation = row[:translation] || ""
    current = IO.iodata_to_binary(msg.msgstr)

    if new_translation != "" and new_translation != current do
      new_msg = %{msg | msgstr: [new_translation]}
      # Remove fuzzy flag if translation is filled
      new_msg = remove_fuzzy(new_msg)
      {:changed, new_msg}
    else
      :unchanged
    end
  end

  defp apply_translation(%Expo.Message.Plural{} = msg, row) do
    new_0 = row[:translation] || ""
    current_0 = IO.iodata_to_binary(Map.get(msg.msgstr, 0, []))

    if new_0 != "" and new_0 != current_0 do
      new_msgstr = Map.put(msg.msgstr, 0, [new_0])
      new_msg = %{msg | msgstr: new_msgstr}
      new_msg = remove_fuzzy(new_msg)
      {:changed, new_msg}
    else
      :unchanged
    end
  end

  defp remove_fuzzy(%{flags: flags} = msg) do
    new_flags =
      Enum.map(flags, fn flag_list ->
        flag_list
        |> List.wrap()
        |> Enum.reject(&(&1 == "fuzzy"))
      end)
      |> Enum.reject(&(&1 == []))

    %{msg | flags: new_flags}
  end

  # ------------------------------------------------------------------
  # Minimal CSV parser — handles quoted fields, commas, newlines in
  # quoted values. No external dependency needed.
  # ------------------------------------------------------------------

  defp parse_csv(path) do
    content = File.read!(path)
    [header_line | data_lines] = csv_split_rows(content)
    headers = csv_split_fields(header_line)

    col_index = fn name ->
      Enum.find_index(headers, &(String.trim(&1) == name))
    end

    domain_idx = col_index.("domain") || raise_csv_error!("domain")
    msgid_idx = col_index.("msgid") || raise_csv_error!("msgid")
    translation_idx = col_index.("translation") || raise_csv_error!("translation")
    source_idx = col_index.("source") || col_index.("msgid_plural")

    data_lines
    |> Enum.reject(&(String.trim(&1) == ""))
    |> Enum.reduce(%{}, fn line, acc ->
      fields = csv_split_fields(line)
      get = fn idx -> if idx, do: Enum.at(fields, idx, ""), else: "" end

      domain = String.trim(get.(domain_idx))
      msgid = get.(msgid_idx)

      if domain == "" or msgid == "" do
        acc
      else
        row = %{
          msgid: msgid,
          source: get.(source_idx),
          translation: get.(translation_idx)
        }

        domain_map = Map.get(acc, domain, %{})
        Map.put(acc, domain, Map.put(domain_map, msgid, row))
      end
    end)
  end

  # Split CSV content into rows, respecting quoted fields that span
  # multiple lines.
  defp csv_split_rows(content) do
    content
    |> String.split("\n")
    |> merge_quoted_rows([])
    |> Enum.reverse()
  end

  defp merge_quoted_rows([], acc), do: acc

  defp merge_quoted_rows([line | rest], acc) do
    if balanced_quotes?(line) do
      merge_quoted_rows(rest, [line | acc])
    else
      # Line has unclosed quote — merge with next lines until balanced
      {merged, remaining} = consume_until_balanced(rest, line)
      merge_quoted_rows(remaining, [merged | acc])
    end
  end

  defp consume_until_balanced([], accumulated), do: {accumulated, []}

  defp consume_until_balanced([line | rest], accumulated) do
    merged = accumulated <> "\n" <> line

    if balanced_quotes?(merged) do
      {merged, rest}
    else
      consume_until_balanced(rest, merged)
    end
  end

  defp balanced_quotes?(str) do
    str
    |> String.graphemes()
    |> Enum.count(&(&1 == "\""))
    |> rem(2) == 0
  end

  # Split a single CSV row into fields, respecting quoted values.
  defp csv_split_fields(line) do
    do_split_fields(String.trim_trailing(line, "\r"), [], "", false)
  end

  defp do_split_fields("", acc, current, _in_quote) do
    Enum.reverse([current | acc])
  end

  defp do_split_fields(<<"\"\"", rest::binary>>, acc, current, true) do
    # Escaped quote inside quoted field
    do_split_fields(rest, acc, current <> "\"", true)
  end

  defp do_split_fields(<<"\"", rest::binary>>, acc, current, false) do
    # Start of quoted field
    do_split_fields(rest, acc, current, true)
  end

  defp do_split_fields(<<"\"", rest::binary>>, acc, current, true) do
    # End of quoted field
    do_split_fields(rest, acc, current, false)
  end

  defp do_split_fields(<<",", rest::binary>>, acc, current, false) do
    # Field separator (not inside quotes)
    do_split_fields(rest, [current | acc], "", false)
  end

  defp do_split_fields(<<ch::utf8, rest::binary>>, acc, current, in_quote) do
    do_split_fields(rest, acc, current <> <<ch::utf8>>, in_quote)
  end

  defp raise_csv_error!(column) do
    Mix.raise("CSV file must have a '#{column}' column header")
  end

  defp raise_usage! do
    Mix.raise("""
    Usage: mix gettext.import_csv LOCALE FILE [--dry-run] [--config BASE_PATH]

    Example: mix gettext.import_csv es translations_es.csv
             mix gettext.import_csv es translations_es.csv --config modules/example_config.json
    """)
  end

  defp gettext_dir do
    Enum.find(@gettext_dirs, "priv/gettext", &File.dir?/1)
  end

  # ------------------------------------------------------------------
  # Theme JSON config import
  # ------------------------------------------------------------------

  defp import_config(_locale, entries, _dry_run?, _config_opt) when map_size(entries) == 0 do
    %{updated: 0}
  end

  defp import_config(locale, entries, dry_run?, config_opt) do
    base_path = detect_config_base(config_opt)

    if base_path do
      do_import_config(locale, entries, dry_run?, base_path)
    else
      Mix.shell().info(
        "  Skipping #{map_size(entries)} config entries — no config base path detected"
      )

      %{updated: 0}
    end
  end

  defp do_import_config(locale, entries, dry_run?, base_path) do
    ext = Path.extname(base_path)
    stem = String.replace_suffix(base_path, ext, "")
    locale_path = "#{stem}.#{locale}#{ext}"

    # Read English config to build source-text → [paths] lookup
    en_path = "#{stem}.en#{ext}"

    en_data =
      if File.exists?(en_path) do
        en_path |> File.read!() |> Jason.decode!()
      else
        nil
      end

    data =
      if File.exists?(locale_path) do
        locale_path |> File.read!() |> Jason.decode!()
      else
        %{}
      end

    # Build a map from source text → list of all config paths that have that text
    source_to_paths = build_source_to_paths(en_data)

    # Apply each CSV entry: resolve by source text to find ALL matching paths
    {updated_data, count} =
      Enum.reduce(entries, {data, 0}, fn {path_key, row}, {acc_data, acc_count} ->
        new_val = row[:translation] || ""
        source_text = row[:source] || ""

        if new_val == "" do
          {acc_data, acc_count}
        else
          all_paths = resolve_config_paths(source_text, path_key, source_to_paths, en_data)
          apply_to_all_paths(all_paths, new_val, acc_data, acc_count)
        end
      end)

    if count > 0 and not dry_run? do
      json = Jason.encode!(updated_data, pretty: true) <> "\n"
      File.write!(locale_path, json)
      Mix.shell().info("  Wrote #{count} config updates to #{locale_path}")
    else
      if count > 0 do
        Mix.shell().info("  [DRY RUN] Would update #{count} config entries in #{locale_path}")
      end
    end

    %{updated: count}
  end

  # Find all config paths that share the same source text, falling back to
  # the original path key when the English config is unavailable.
  defp resolve_config_paths(source_text, path_key, source_to_paths, en_data) do
    if source_text != "" and en_data do
      Map.get(source_to_paths, source_text, [path_key])
    else
      [path_key]
    end
  end

  # Apply a translation value to every matching config path.
  defp apply_to_all_paths(paths, new_val, data, count) do
    Enum.reduce(paths, {data, count}, fn p, {d, c} ->
      if get_in_config(d, p) == new_val do
        {d, c}
      else
        {put_in_config(d, p, new_val), c + 1}
      end
    end)
  end

  # Build a map: %{english_text => [path1, path2, ...]} from the English config.
  # This lets us apply a translation to ALL config paths sharing the same source text.
  @config_top_keys ~w(title tagline description)
  @config_array_fields [
    {["useful_links"], "title"},
    {["footer_links"], "label"},
    {["features"], "title"},
    {["features"], "description"},
    {["home", "hero"], "title"},
    {["home", "hero"], "text"},
    {["home", "hero", "buttons"], "title"},
    {["home", "sections"], "title"},
    {["home", "sections"], "text"},
    {["home", "sections", "buttons"], "title"},
    {["navigation", "primary_links"], "label"},
    {["navigation", "primary_links", "items"], "label"},
    {["navigation", "guest_links"], "label"},
    {["navigation", "guest_links", "items"], "label"},
    {["navigation", "authenticated_links"], "label"},
    {["navigation", "authenticated_links", "items"], "label"},
    {["navigation", "account_links"], "label"},
    {["navigation", "account_links", "items"], "label"}
  ]

  defp build_source_to_paths(nil), do: %{}

  defp build_source_to_paths(en_data) do
    top_pairs =
      Enum.flat_map(@config_top_keys, fn key ->
        val = Map.get(en_data, key, "")
        if val != "", do: [{val, key}], else: []
      end)

    array_pairs =
      Enum.flat_map(@config_array_fields, fn {array_path, text_field} ->
        path_prefix = Enum.join(array_path, ".")

        en_data
        |> config_items_at_path(array_path)
        |> Enum.with_index()
        |> Enum.flat_map(fn {item, idx} ->
          val = Map.get(item, text_field, "")
          path = "#{path_prefix}[#{idx}].#{text_field}"
          if val != "", do: [{val, path}], else: []
        end)
      end)

    (top_pairs ++ array_pairs)
    |> Enum.group_by(fn {text, _path} -> text end, fn {_text, path} -> path end)
  end

  defp config_items_at_path(data, path_segments) when is_list(path_segments) do
    collect_config_items(data, path_segments)
  end

  defp collect_config_items(data, []), do: if(is_list(data), do: data, else: [])

  defp collect_config_items(data, [segment | rest]) when is_map(data) do
    collect_config_items(Map.get(data, segment, []), rest)
  end

  defp collect_config_items(data, path) when is_list(data) do
    Enum.flat_map(data, &collect_config_items(&1, path))
  end

  defp collect_config_items(_data, _path), do: []

  # Navigate into JSON using our path format: "key" or "array[idx].field"
  defp get_in_config(data, path) do
    path
    |> parse_config_path()
    |> Enum.reduce(data, fn
      {key, idx}, acc when is_map(acc) ->
        acc |> Map.get(key, []) |> Enum.at(idx)

      key, acc when is_map(acc) ->
        Map.get(acc, key)

      _key, nil ->
        nil
    end)
  end

  defp put_in_config(data, path, value) do
    segments = parse_config_path(path)
    do_put_in_config(data, segments, value)
  end

  defp do_put_in_config(_data, [], value), do: value

  defp do_put_in_config(data, [{key, idx} | rest], value) when is_map(data) do
    list = Map.get(data, key, [])

    if idx < length(list) do
      new_item = do_put_in_config(Enum.at(list, idx), rest, value)
      new_list = List.replace_at(list, idx, new_item)
      Map.put(data, key, new_list)
    else
      data
    end
  end

  defp do_put_in_config(data, [key | rest], value) when is_map(data) do
    current = Map.get(data, key, %{})
    Map.put(data, key, do_put_in_config(current, rest, value))
  end

  defp do_put_in_config(data, _rest, _value), do: data

  # Parse "useful_links[0].title" → [{"useful_links", 0}, "title"]
  # Parse "title" → ["title"]
  defp parse_config_path(path) do
    path
    |> String.split(".")
    |> Enum.map(fn segment ->
      case Regex.run(~r/^(.+)\[(\d+)\]$/, segment) do
        [_, key, idx] -> {key, String.to_integer(idx)}
        nil -> segment
      end
    end)
  end

  defp detect_config_base(nil) do
    env_path = System.get_env("THEME_CONFIG")

    cond do
      env_path && env_path != "" -> env_path
      File.exists?("modules/example_config.en.json") -> "modules/example_config.json"
      true -> nil
    end
  end

  defp detect_config_base(explicit), do: explicit
end
