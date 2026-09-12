defmodule GamendWeb.OnMount.SeoTitle do
  @moduledoc """
  Keeps a LiveView's `<title>` equal to the one the first render already put in
  the tab.

  The root layout titles a page `seo_title || page_title` — the SEO title
  because `page_title` is a short UI label ("Test", "Explore") and nobody
  searches for those. But a LiveView pushes its own `page_title` over the
  socket the moment it connects, and LiveView.js writes that straight into
  `document.title`. So every LiveView page painted its searchable title and
  then, about a second later, replaced it with the label: `/courses/spanish`
  went from "Learn Spanish: Units, Words and Tests" to "Courses" while the
  reader watched.

  This hook runs on `handle_params`, which is after `mount/3` and before the
  view's own callback, so it wins over the `page_title` that almost every
  LiveView assigns while mounting. A view that assigns one *later* — from an
  event, as the tests page does when the reader picks a topic — still wins,
  which is the intended split: the title follows what the reader does, not
  what the socket does on its own.

  Live navigation is covered too, and for free: a patch re-runs
  `handle_params` with the new URI, so the tab follows the URL the same way a
  full load would.

  Mounted after `GamendWeb.OnMount.Locale`, since the provider's titles are
  gettext strings and the locale is set there.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4]

  alias GamendWeb.Plugs.LocalePath
  alias GamendWeb.Plugs.PageMeta

  def on_mount(:default, _params, _session, socket) do
    {:cont, attach_hook(socket, :seo_title, :handle_params, &put_title/3)}
  end

  @doc """
  Assign `title` unless this page already has an SEO title.

  Use it instead of `assign(socket, :page_title, title)` **inside
  `handle_params/3`**: hooks run before the view's own callback, so a plain
  assign there lands after this one and puts the short label back. In `mount/3`
  a plain assign is fine — the hook runs after it.

  A page the provider has no title for is unaffected: a group's own name, a
  tournament's, a guide chapter's, all still reach the tab.
  """
  @spec assign_page_title(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def assign_page_title(socket, title) do
    if is_binary(socket.assigns[:seo_title]),
      do: socket,
      else: assign(socket, :page_title, title)
  end

  # Both assigns are rewritten on every params change, `nil` included: a patch
  # from /groups to /groups/42 leaves the index's title behind otherwise, and
  # `assign_page_title/2` would go on refusing to set the group's own name.
  defp put_title(_params, uri, socket) do
    case seo_title(uri) do
      nil ->
        {:cont, assign(socket, :seo_title, nil)}

      title ->
        {:cont, socket |> assign(:seo_title, title) |> assign(:page_title, title)}
    end
  end

  # `uri` is the full URL the browser is on, prefix and all; the provider is
  # keyed by the clean path, exactly as the plug keys it.
  defp seo_title(uri) when is_binary(uri) do
    case URI.parse(uri).path do
      path when is_binary(path) -> path |> LocalePath.clean_path() |> PageMeta.title_for()
      _ -> nil
    end
  end

  defp seo_title(_uri), do: nil
end
