defmodule GameServerWeb.PublicDocs do
  @moduledoc """
  Static LiveView that renders setup guides, API usage examples, and public
  documentation pages for SDKs and provider setup instructions.
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

        <%!-- Infrastructure & Operations --%>
        {GameServerWeb.PublicDocsTemplates.deployment(assigns)}

        <%!-- Overview & Fundamentals --%>
        {GameServerWeb.PublicDocsTemplates.architecture(assigns)}
        {GameServerWeb.PublicDocsTemplates.data_schema(assigns)}
        {GameServerWeb.PublicDocsTemplates.authentication(assigns)}

        <%!-- SDK Integration --%>
        {GameServerWeb.PublicDocsTemplates.godot_sdk(assigns)}
        {GameServerWeb.PublicDocsTemplates.js_sdk(assigns)}

        <%!-- Core Features --%>
        {GameServerWeb.PublicDocsTemplates.realtime(assigns)}
        {GameServerWeb.PublicDocsTemplates.webrtc(assigns)}
        {GameServerWeb.PublicDocsTemplates.leaderboards(assigns)}
        {GameServerWeb.PublicDocsTemplates.achievements(assigns)}
        {GameServerWeb.PublicDocsTemplates.chat(assigns)}
        {GameServerWeb.PublicDocsTemplates.notifications(assigns)}
        {GameServerWeb.PublicDocsTemplates.server_scripting(assigns)}
        {GameServerWeb.PublicDocsTemplates.theme(assigns)}

        <%!-- Extending & Customizing --%>
        {GameServerWeb.PublicDocsTemplates.custom_host(assigns)}

        <%!-- OAuth Provider Setup --%>
        {GameServerWeb.PublicDocsTemplates.apple_sign_in(assigns)}
        {GameServerWeb.PublicDocsTemplates.steam_openid(assigns)}
        {GameServerWeb.PublicDocsTemplates.discord_oauth(assigns)}
        {GameServerWeb.PublicDocsTemplates.google_oauth(assigns)}
        {GameServerWeb.PublicDocsTemplates.facebook_oauth(assigns)}

        <%!-- Infrastructure & Operations (continued) --%>
        {GameServerWeb.PublicDocsTemplates.email_setup(assigns)}
        {GameServerWeb.PublicDocsTemplates.sentry_setup(assigns)}
        {GameServerWeb.PublicDocsTemplates.cache_setup(assigns)}
        {GameServerWeb.PublicDocsTemplates.scaling(assigns)}
        {GameServerWeb.PublicDocsTemplates.postgresql_setup(assigns)}
        {GameServerWeb.PublicDocsTemplates.well_known(assigns)}
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, gettext("Documentation"))}
  end
end
