defmodule GameServerWeb.AdminLive.TranslationMetadata do
  @moduledoc """
  Shared metadata helpers for admin translation editors.
  """

  def extract(nil), do: %{}

  def extract(metadata) when is_map(metadata) do
    titles = Map.get(metadata, "titles", %{})
    descriptions = Map.get(metadata, "descriptions", %{})

    locales = MapSet.union(MapSet.new(Map.keys(titles)), MapSet.new(Map.keys(descriptions)))

    Map.new(locales, fn locale ->
      {locale,
       %{
         "title" => Map.get(titles, locale, ""),
         "description" => Map.get(descriptions, locale, "")
       }}
    end)
  end

  def merge(params, translations) when translations == %{}, do: params

  def merge(params, translations) do
    metadata = Map.get(params, "metadata", %{})

    {titles, descriptions} =
      Enum.reduce(translations, {%{}, %{}}, fn {locale, fields}, {titles_acc, descs_acc} ->
        title = String.trim(Map.get(fields, "title", ""))
        desc = String.trim(Map.get(fields, "description", ""))

        titles_acc = if title != "", do: Map.put(titles_acc, locale, title), else: titles_acc
        descs_acc = if desc != "", do: Map.put(descs_acc, locale, desc), else: descs_acc

        {titles_acc, descs_acc}
      end)

    metadata =
      metadata
      |> then(fn m ->
        if titles == %{}, do: Map.delete(m, "titles"), else: Map.put(m, "titles", titles)
      end)
      |> then(fn m ->
        if descriptions == %{},
          do: Map.delete(m, "descriptions"),
          else: Map.put(m, "descriptions", descriptions)
      end)

    Map.put(params, "metadata", metadata)
  end

  def completeness(nil), do: 0

  def completeness(metadata) when is_map(metadata) do
    locales = Gettext.known_locales(GameServerWeb.Gettext) -- ["en"]

    if locales == [] do
      100
    else
      titles = Map.get(metadata, "titles", %{})

      translated =
        Enum.count(locales, fn locale ->
          title = Map.get(titles, locale, "")
          is_binary(title) and String.trim(title) != ""
        end)

      trunc(translated / length(locales) * 100)
    end
  end
end
