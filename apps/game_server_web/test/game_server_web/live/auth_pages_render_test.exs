defmodule GameServerWeb.AuthPagesRenderTest do
  @moduledoc """
  Basic render tests for pages that require authentication
  (live_session :require_authenticated_user).
  These catch crashes like missing assigns or template errors.
  """
  use GameServerWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "redirects to login when unauthenticated" do
    test "GET /notifications redirects", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/notifications")
    end

    test "GET /chat redirects", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/chat")
    end
  end

  describe "renders when authenticated" do
    setup :register_and_log_in_user

    test "GET /notifications renders", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/notifications")
      assert html =~ "Notifications"
    end

    test "GET /chat renders", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/chat")
      assert html =~ "Chat"
    end
  end
end
