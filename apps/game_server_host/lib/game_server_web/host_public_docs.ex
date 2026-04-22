defmodule GameServerWeb.HostPublicDocs do
  @moduledoc """
  Host-owned static LiveView that renders setup guides and product docs.
  """

  use GameServerWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_path={assigns[:current_path]}>
      <div class="py-8 px-6 max-w-5xl mx-auto space-y-6">
        <.header>
          {"Setup & Guides"}
          <:subtitle>
            {"Platform setup, OAuth providers, email, error monitoring, and server hooks"}
          </:subtitle>
        </.header>

        {GameServerWeb.HostPublicDocsTemplates.deployment(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.architecture(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.data_schema(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.authentication(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.godot_sdk(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.js_sdk(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.realtime(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.webrtc(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.leaderboards(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.achievements(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.chat(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.notifications(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.server_scripting(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.theme(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.custom_host(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.apple_sign_in(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.steam_openid(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.discord_oauth(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.google_oauth(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.facebook_oauth(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.email_setup(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.sentry_setup(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.cache_setup(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.scaling(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.postgresql_setup(assigns)}
        {GameServerWeb.HostPublicDocsTemplates.well_known(assigns)}
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, gettext("Documentation"))}
  end
end
