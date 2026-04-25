defmodule GameServerWeb.HostPublicDocs do
  @moduledoc """
  Host-owned static LiveView that renders setup guides and product docs.
  """

  use GameServerHostWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_path={assigns[:current_path]}>
      <div class="space-y-6">
        <.header>
          <h1 class="text-3xl font-bold">
            {"Setup & Guides"}
          </h1>
          <:subtitle>
            {"Platform setup, OAuth providers, email, error monitoring, and server hooks"}
          </:subtitle>
        </.header>

        <.guide_category_heading title="Core Setup" />
        {GameServerWeb.HostPublicDocsTemplates.deployment(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.elixir_app_starter(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.architecture(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.data_schema(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.theme(assigns)}

        <.guide_category_heading title="Authentication & Providers" />
        {GameServerWeb.HostPublicDocsTemplates.authentication(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.apple_sign_in(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.steam_openid(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.discord_oauth(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.google_oauth(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.facebook_oauth(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.email_setup(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.well_known(assigns)}

        <.guide_category_heading title="Clients & Realtime" />
        {GameServerWeb.HostPublicDocsTemplates.godot_sdk(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.js_sdk(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.realtime(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.webrtc(assigns)}

        <.guide_category_heading title="Gameplay & Social Systems" />
        {GameServerWeb.HostPublicDocsTemplates.leaderboards(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.achievements(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.chat(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.notifications(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.server_scripting(assigns)}

        <.guide_category_heading title="Operations & Infrastructure" />
        {GameServerWeb.HostPublicDocsTemplates.sentry_setup(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.cache_setup(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.scaling(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.postgresql_setup(assigns)}
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, gettext("Documentation"))}
  end

  attr :title, :string, required: true

  defp guide_category_heading(assigns) do
    ~H"""
    <div class="space-y-2 border-t border-base-300/60 pt-6 first:border-t-0 first:pt-0">
      <h2 class="font-semibold uppercase tracking-[0.24em]">{@title}</h2>
    </div>
    """
  end
end
