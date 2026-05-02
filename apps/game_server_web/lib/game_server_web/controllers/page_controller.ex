defmodule GameServerWeb.PageController do
  use GameServerWeb, :controller

  alias GameServerWeb.PresentationPage

  def home(conn, _params) do
    render_presentation_page(conn, "/", gettext("Home"))
  end

  def configured_page(conn, %{"path" => path}) do
    render_presentation_page(conn, "/" <> Enum.join(path, "/"), gettext("Page"))
  end

  def privacy(conn, _params) do
    conn
    |> assign(:page_title, gettext("Privacy"))
    |> render(:privacy)
  end

  def data_deletion(conn, _params) do
    conn
    |> assign(:page_title, gettext("Delete"))
    |> render(:data_deletion)
  end

  def terms(conn, _params) do
    conn
    |> assign(:page_title, gettext("Terms"))
    |> render(:terms)
  end

  defp render_presentation_page(conn, path, fallback_title) do
    locale = Gettext.get_locale(GameServerWeb.Gettext)
    theme = GameServerWeb.Layouts.resolve_theme(locale, conn.assigns[:theme] || %{})

    case PresentationPage.page_for_path(theme, path) || missing_home_page(theme, path) do
      nil ->
        conn
        |> put_status(:not_found)
        |> text("Not Found")

      page ->
        conn
        |> assign(:page_title, PresentationPage.page_title(page, fallback_title))
        |> render(:presentation_page, presentation_page: page, theme: theme)
    end
  end

  defp missing_home_page(theme, "/") do
    %{
      "path" => "/",
      "hero" => %{
        "title" => Map.get(theme, "title", ""),
        "text" => Map.get(theme, "description", ""),
        "image" => %{
          "light" => Map.get(theme, "banner", "/images/banner.png"),
          "alt" => Map.get(theme, "title", "")
        }
      },
      "sections" => []
    }
  end

  defp missing_home_page(_theme, _path), do: nil
end
