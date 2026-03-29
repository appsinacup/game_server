defmodule GameServerWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use GameServerWeb, :html

  embed_templates "page_html/*"

  @bold_pattern ~r/\*\*(.+?)\*\*/

  @doc """
  Converts a plain-text description to safe HTML, supporting `**bold**` markdown.

  The input is HTML-escaped first, then `**text**` patterns are replaced with
  `<strong>text</strong>` tags. Returns a `Phoenix.HTML.safe()` tuple.
  """
  @spec format_description(String.t()) :: Phoenix.HTML.safe()
  def format_description(text) when is_binary(text) do
    text
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
    |> String.replace(@bold_pattern, "<strong>\\1</strong>")
    |> Phoenix.HTML.raw()
  end

  def format_description(_), do: Phoenix.HTML.raw("")
end
