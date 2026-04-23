defmodule GameServerWeb.HostLayouts do
  @moduledoc """
  Host-owned layout entrypoints and shared layout helpers.
  """

  use GameServerWeb, :html

  alias GameServer.Theme.JSONConfig
  alias GameServerWeb.HostLayoutShell

  @known_locales Gettext.known_locales(GameServerWeb.Gettext)

  @locale_labels %{
    "ar" => "العربية",
    "bg" => "български език",
    "cs" => "čeština",
    "da" => "Dansk",
    "de" => "Deutsch",
    "el" => "Ελληνικά",
    "en" => "English",
    "es" => "Español",
    "es_ES" => "Español (España)",
    "fi" => "suomi",
    "fr" => "Français",
    "hu" => "magyar",
    "id" => "Bahasa Indonesia",
    "it" => "Italiano",
    "ja" => "日本語",
    "ko" => "한국어",
    "nl" => "Nederlands",
    "no" => "Norsk",
    "pl" => "Polski",
    "pt" => "Português",
    "pt_BR" => "Português do Brasil",
    "ro" => "Română",
    "ru" => "Русский",
    "sv" => "Svenska",
    "th" => "ไทย",
    "tr" => "Türkçe",
    "uk" => "Українська",
    "vi" => "Tiếng Việt",
    "zh_CN" => "简体中文",
    "zh_TW" => "繁體中文"
  }

  embed_templates "host_layouts/*"

  @icon_slots [
    %{top: 13, left: 4, size: "size-9 sm:size-13", dur: 8, delay: 0},
    %{top: 12, right: 6, size: "size-8 sm:size-12", dur: 10, delay: 1},
    %{top: 21, left: 13, size: "size-7 sm:size-9", dur: 9, delay: 3.5},
    %{top: 28, right: 14, size: "size-7 sm:size-10", dur: 8, delay: 2.2},
    %{top: 36, left: 3, size: "size-9 sm:size-12", dur: 9, delay: 2},
    %{top: 42, right: 4, size: "size-10 sm:size-14", dur: 11, delay: 0.5},
    %{top: 51, left: 16, size: "size-7 sm:size-9", dur: 10, delay: 1.8},
    %{top: 57, right: 12, size: "size-8 sm:size-11", dur: 11, delay: 0.8},
    %{top: 66, left: 7, size: "size-8 sm:size-10", dur: 7, delay: 3},
    %{top: 72, right: 5, size: "size-10 sm:size-15", dur: 12, delay: 1.5},
    %{top: 81, left: 18, size: "size-8 sm:size-11", dur: 8, delay: 1.2},
    %{top: 88, right: 15, size: "size-7 sm:size-10", dur: 9, delay: 2.8}
  ]

  @host_theme_settings %{
    "css" => nil,
    "logo" => "/images/logo.png",
    "banner" => "/images/banner.png",
    "favicon" => "/favicon.ico"
  }

  @home_banner_link "/docs/setup"

  @app_version_fallback Mix.Project.config()[:version] || "1.0.0"

  @doc false
  def icon_placements(icons) when is_list(icons) do
    unique_icons = Enum.uniq(icons)

    if unique_icons == [] do
      []
    else
      unique_icons
      |> Enum.with_index()
      |> Enum.map(fn {icon, index} ->
        slot = Enum.at(@icon_slots, rem(index, length(@icon_slots)))
        Map.put(slot, :name, icon)
      end)
    end
  end

  @doc """
  Renders the application layout shell.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :current_path, :string, default: nil, doc: "current request path for nav active state"

  attr :flush, :boolean,
    default: false,
    doc: "when true, render content edge-to-edge with no main wrapper, padding, or footer"

  slot :inner_block, required: true

  def app(assigns) do
    assigns = prepare_app_assigns(assigns)
    HostLayoutShell.app(assigns)
  end

  @doc false
  def resolve_theme(locale \\ nil, assigned_theme \\ %{}) do
    theme = merge_assigned_theme(fetch_theme(locale), assigned_theme)
    missing? = Map.drop(theme, Map.keys(@host_theme_settings)) == %{}

    theme
    |> Map.put("title", Map.get(theme, "title") || if(missing?, do: "MISSING_CONFIG"))
    |> Map.put(
      "tagline",
      Map.get(theme, "tagline") || if(missing?, do: "Set THEME_CONFIG env")
    )
    |> Map.merge(@host_theme_settings)
  end

  @doc false
  def home_banner_link, do: @home_banner_link

  defp prepare_app_assigns(assigns) do
    conn = Map.get(assigns, :conn)

    current_path =
      Map.get(assigns, :current_path) ||
        if(conn, do: conn.request_path, else: "/")

    current_query = if conn, do: conn.query_string, else: ""
    locale = Gettext.get_locale(GameServerWeb.Gettext) || "en"

    theme = resolve_theme(locale, Map.get(assigns, :theme, %{}))
    en_theme = resolve_theme("en")

    navigation = navigation_config(theme, en_theme)
    footer_links = theme_list(theme, en_theme, "footer_links")
    background_icons = theme_list(theme, en_theme, "background_icons")
    site_message_source = Map.get(en_theme, "site_message", "")

    site_message =
      case Map.get(theme, "site_message", "") do
        "" -> site_message_source
        message -> message
      end

    site_message_hash =
      if site_message_source != "" do
        :erlang.phash2(site_message_source) |> Integer.to_string()
      else
        ""
      end

    notif_unread_count =
      if assigns[:current_scope] do
        GameServer.Notifications.count_unread_notifications(assigns.current_scope.user.id)
      else
        0
      end

    assign(assigns,
      current_path: current_path,
      current_query: current_query,
      locale: locale,
      known_locales: @known_locales,
      theme: theme,
      navigation: navigation,
      footer_links: footer_links,
      background_icons: background_icons,
      site_message: site_message,
      site_message_hash: site_message_hash,
      notif_unread_count: notif_unread_count,
      app_version: app_version()
    )
  end

  defp fetch_theme(locale) do
    theme_mod = Application.get_env(:game_server_web, :theme_module, JSONConfig)

    _ = Code.ensure_loaded?(theme_mod)

    if is_binary(locale) and function_exported?(theme_mod, :get_theme, 1) do
      case safe_get_theme_1(theme_mod, locale) do
        theme when is_map(theme) and map_size(theme) > 0 -> theme
        _ -> try_primary_or_fallback(theme_mod, locale)
      end
    else
      safe_get_theme_0(theme_mod)
    end
  rescue
    _ -> %{}
  end

  defp try_primary_or_fallback(theme_mod, locale) do
    primary =
      locale
      |> String.trim()
      |> String.downcase()
      |> String.split(~r/[-_]/, parts: 2)
      |> List.first()

    if is_binary(primary) and primary != locale and function_exported?(theme_mod, :get_theme, 1) do
      case safe_get_theme_1(theme_mod, primary) do
        theme when is_map(theme) and map_size(theme) > 0 -> theme
        _ -> safe_get_theme_0(theme_mod)
      end
    else
      safe_get_theme_0(theme_mod)
    end
  end

  defp safe_get_theme_1(theme_mod, locale) do
    theme_mod.get_theme(locale) || %{}
  rescue
    _ -> %{}
  end

  defp safe_get_theme_0(theme_mod) do
    if function_exported?(theme_mod, :get_theme, 0), do: theme_mod.get_theme() || %{}, else: %{}
  rescue
    _ -> %{}
  end

  defp merge_assigned_theme(full_theme, assigned_theme) when is_map(assigned_theme) do
    Enum.reduce(assigned_theme, full_theme, fn
      {_key, nil}, acc -> acc
      {_key, ""}, acc -> acc
      {key, value}, acc -> Map.put(acc, key, value)
    end)
  end

  defp merge_assigned_theme(full_theme, _assigned_theme), do: full_theme

  defp navigation_config(provider_theme, en_theme) do
    provider_navigation = Map.get(provider_theme, "navigation") || %{}
    en_navigation = Map.get(en_theme, "navigation") || %{}

    %{
      "primary_links" =>
        navigation_links(
          provider_navigation,
          en_navigation,
          "primary_links",
          default_primary_nav_links()
        ),
      "guest_links" => navigation_links(provider_navigation, en_navigation, "guest_links"),
      "authenticated_links" =>
        navigation_links(provider_navigation, en_navigation, "authenticated_links"),
      "account_links" => navigation_links(provider_navigation, en_navigation, "account_links")
    }
  end

  defp navigation_links(provider_navigation, en_navigation, key, default \\ []) do
    case Map.get(provider_navigation, key) do
      links when is_list(links) ->
        links

      _ ->
        case Map.get(en_navigation, key) do
          links when is_list(links) -> links
          _ -> default
        end
    end
  end

  defp theme_list(provider_theme, en_theme, key, default \\ []) do
    case Map.get(provider_theme, key) do
      links when is_list(links) ->
        links

      _ ->
        case Map.get(en_theme, key) do
          links when is_list(links) -> links
          _ -> default
        end
    end
  end

  defp default_primary_nav_links do
    [
      %{
        "label" => gettext("Leaderboards"),
        "href" => "/leaderboards",
        "icon" => "hero-chart-bar-solid"
      },
      %{
        "label" => gettext("Achievements"),
        "href" => "/achievements",
        "icon" => "hero-trophy-solid"
      },
      %{
        "label" => gettext("Groups"),
        "href" => "/groups",
        "icon" => "hero-user-group-solid"
      }
    ]
  end

  def locale_labels, do: @locale_labels

  def strip_locale_prefix(path, known_locales) when is_binary(path) do
    segments = String.split(path, "/", trim: true)

    case segments do
      [first | rest] when is_list(rest) ->
        if first in known_locales do
          case rest do
            [] -> "/"
            _ -> "/" <> Enum.join(rest, "/")
          end
        else
          if String.starts_with?(path, "/"), do: path, else: "/"
        end

      _ ->
        if String.starts_with?(path, "/"), do: path, else: "/"
    end
  end

  def strip_locale_prefix(_, _known_locales), do: "/"

  defp app_version do
    case System.get_env("APP_VERSION") || Application.spec(:game_server, :vsn) do
      nil -> @app_version_fallback
      vsn -> to_string(vsn)
    end
  end

  @doc """
  Shows the flash group with standard titles and content.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("Loading...")}
        phx-disconnected={JS.dispatch("gs:lv-disconnected")}
        phx-connected={JS.dispatch("gs:lv-connected")}
        phx-hook="ReconnectNotice"
        data-delay-ms="5000"
        hidden
      >
        {gettext("Loading...")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Loading...")}
        phx-disconnected={JS.dispatch("gs:lv-disconnected")}
        phx-connected={JS.dispatch("gs:lv-connected")}
        phx-hook="ReconnectNotice"
        data-delay-ms="5000"
        hidden
      >
        {gettext("Loading...")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/2 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=dark]_&]:left-1/2 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/2"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/2"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
