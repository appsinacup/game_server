defmodule GameServerWeb.PageControllerTest do
  use GameServerWeb.ConnCase, async: false

  alias GameServer.Accounts.User
  alias GameServer.AccountsFixtures
  alias GameServer.Content
  alias GameServer.Repo
  alias GameServer.Theme.JSONConfig

  setup do
    # Ensure a known THEME_CONFIG is active so tests aren't affected by other
    # modules that may delete/restore the env var concurrently.
    # Use a temp file with known content for reliable path resolution.
    orig = System.get_env("THEME_CONFIG")

    base =
      Path.join(System.tmp_dir!(), "theme_page_test_#{System.unique_integer([:positive])}.json")

    en_path = String.trim_trailing(base, ".json") <> ".en.json"
    ro_path = String.trim_trailing(base, ".json") <> ".ro.json"

    theme = %{
      "title" => "Gamend",
      "tagline" => "Game + Backend",
      "logo" => "/images/logo.png",
      "banner" => "/images/banner.png",
      "favicon" => "/favicon.ico",
      "features" => [
        %{
          "title" => "Persistence & Caching",
          "description" => "SQLite (in memory) and PostgreSQL.",
          "icon" => "hero-server-stack"
        }
      ],
      "useful_links" => [
        %{
          "title" => "Discord",
          "url" => "https://discord.com/invite/example",
          "icon" => "hero-chat-bubble-left-ellipsis",
          "external" => true
        }
      ],
      "footer_links" => [
        %{"label" => "Privacy Policy", "href" => "/privacy"},
        %{"label" => "Terms and Conditions", "href" => "/terms"}
      ],
      "navigation" => %{
        "primary_links" => [
          %{"label" => "Play", "href" => "/play", "icon" => "hero-play-solid"},
          %{
            "label" => "Social",
            "icon" => "hero-user-group-solid",
            "items" => [
              %{
                "label" => "Leaderboards",
                "href" => "/leaderboards",
                "icon" => "hero-chart-bar-solid"
              },
              %{
                "label" => "Achievements",
                "href" => "/achievements",
                "icon" => "hero-trophy-solid"
              },
              %{"label" => "Groups", "href" => "/groups", "icon" => "hero-user-group-solid"},
              %{
                "label" => "Parties",
                "href" => "/parties",
                "icon" => "hero-user-plus-solid",
                "auth" => "authenticated"
              }
            ]
          }
        ],
        "account_links" => [
          %{"label" => "Billing", "href" => "/billing"},
          %{"label" => "Admin Console", "href" => "/admin", "admin_only" => true}
        ]
      }
    }

    json = Jason.encode!(theme)

    ro_json =
      Jason.encode!(
        Map.put(theme, "navigation", %{
          "primary_links" => [
            %{"label" => "Joacă", "href" => "/play", "icon" => "hero-play-solid"},
            %{
              "label" => "Social",
              "icon" => "hero-user-group-solid",
              "items" => [
                %{
                  "label" => "Clasamente",
                  "href" => "/leaderboards",
                  "icon" => "hero-chart-bar-solid"
                },
                %{
                  "label" => "Realizări",
                  "href" => "/achievements",
                  "icon" => "hero-trophy-solid"
                },
                %{
                  "label" => "Grupuri",
                  "href" => "/groups",
                  "icon" => "hero-user-group-solid"
                },
                %{
                  "label" => "Petreceri",
                  "href" => "/parties",
                  "icon" => "hero-user-plus-solid",
                  "auth" => "authenticated"
                }
              ]
            }
          ]
        })
      )

    File.write!(en_path, json)
    File.write!(ro_path, ro_json)
    System.put_env("THEME_CONFIG", base)
    JSONConfig.reload()
    Content.reload()

    on_exit(fn ->
      if orig, do: System.put_env("THEME_CONFIG", orig), else: System.delete_env("THEME_CONFIG")
      JSONConfig.reload()
      Content.reload()
      File.rm(en_path)
      File.rm(ro_path)
    end)

    :ok
  end

  test "home shows features", %{conn: conn} do
    conn = get(conn, "/")
    body = html_response(conn, 200)

    assert body =~ "Home"
    assert body =~ "Online"
    assert body =~ "Discord"
    assert body =~ "SQLite"
  end

  test "home uses localized primary nav labels from locale theme config", %{conn: conn} do
    conn = get(conn, "/ro")
    assert redirected_to(conn) == "/"

    conn = get(recycle(conn), "/")
    body = html_response(conn, 200)

    assert body =~ "Joacă"
    assert body =~ "Clasamente"
    assert body =~ "Realizări"
    assert body =~ "Grupuri"
  end

  test "home renders without errors when THEME_CONFIG is unset", %{conn: conn} do
    System.delete_env("THEME_CONFIG")
    JSONConfig.reload()
    Content.reload()

    conn = get(conn, "/")
    # Page should render without crashing even with no theme configured
    assert html_response(conn, 200) =~ "<html"
  end

  test "home hides admin-only account links for non-admin users", %{conn: conn} do
    user =
      AccountsFixtures.user_fixture()
      |> User.admin_changeset(%{"is_admin" => false})
      |> Repo.update!()

    body =
      conn
      |> log_in_user(user)
      |> get("/")
      |> html_response(200)

    assert body =~ "href=\"/billing\""
    refute body =~ "href=\"/admin\""
  end

  test "home hides auth-only dropdown items from guests", %{conn: conn} do
    body =
      conn
      |> get("/")
      |> html_response(200)

    assert body =~ "href=\"/leaderboards\""
    refute body =~ "href=\"/parties\""
  end

  test "home shows auth-only dropdown items to signed-in users", %{conn: conn} do
    user =
      AccountsFixtures.user_fixture()
      |> User.admin_changeset(%{"is_admin" => false})
      |> Repo.update!()

    body =
      conn
      |> log_in_user(user)
      |> get("/")
      |> html_response(200)

    assert body =~ "href=\"/leaderboards\""
    assert body =~ "href=\"/parties\""
  end

  test "home shows admin-only account links for admin users", %{conn: conn} do
    user =
      AccountsFixtures.user_fixture()
      |> User.admin_changeset(%{"is_admin" => true})
      |> Repo.update!()

    body =
      conn
      |> log_in_user(user)
      |> get("/")
      |> html_response(200)

    assert body =~ "href=\"/billing\""
    assert body =~ "href=\"/admin\""
  end

  test "privacy page present", %{conn: conn} do
    conn = get(conn, "/privacy")
    body = html_response(conn, 200)

    assert body =~ "Privacy Policy"
    assert body =~ "Information We Collect"
  end

  test "terms page present", %{conn: conn} do
    conn = get(conn, "/terms")
    body = html_response(conn, 200)

    assert body =~ "Terms and Conditions"
    assert body =~ "Acceptance of Terms"
  end

  test "privacy link present in layout", %{conn: conn} do
    conn = get(conn, "/")
    body = html_response(conn, 200)

    assert body =~ "href=\"/privacy\""
  end

  test "terms link present in layout", %{conn: conn} do
    conn = get(conn, "/")
    body = html_response(conn, 200)

    assert body =~ "href=\"/terms\""
  end
end
