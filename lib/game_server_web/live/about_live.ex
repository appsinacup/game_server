defmodule GameServerWeb.HostAboutLive do
  @moduledoc """
  Host-owned About page that reads profile details from the host theme config.
  """

  use GameServerWeb, :live_view

  alias GameServerWeb.HostLayouts

  @default_headline "Builder, operator, and human behind this project."

  @default_bio """
  Add a short introduction about yourself here.

  You can share what you build, what you care about, and the best way for people to reach you.
  """

  @default_github_url "https://github.com/your-handle"
  @default_github_label "github.com/your-handle"
  @default_linkedin_url "https://www.linkedin.com/in/your-handle/"
  @default_linkedin_label "linkedin.com/in/your-handle/"

  @impl true
  def mount(_params, _session, socket) do
    locale = Gettext.get_locale(GameServerWeb.Gettext) || "en"
    theme = HostLayouts.resolve_theme(locale)
    about = Map.get(theme, "about", %{})

    {:ok,
     socket
     |> assign(:page_title, gettext("About"))
     |> assign(:about_name, Map.get(about, "name") || Map.get(theme, "title") || gettext("About"))
     |> assign(:about_headline, Map.get(about, "headline") || @default_headline)
     |> assign(:about_bio, bio_paragraphs(Map.get(about, "bio") || @default_bio))
     |> assign(:about_avatar_url, Map.get(about, "avatar_url"))
     |> assign(:github_url, Map.get(about, "github_url") || @default_github_url)
     |> assign(:github_label, Map.get(about, "github_label") || @default_github_label)
     |> assign(:linkedin_url, Map.get(about, "linkedin_url") || @default_linkedin_url)
     |> assign(:linkedin_label, Map.get(about, "linkedin_label") || @default_linkedin_label)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_path={assigns[:current_path]}>
      <div class="py-8 px-4 sm:px-6 max-w-5xl mx-auto space-y-8">
        <.header>
          <h1 class="text-3xl font-bold">{@about_name}</h1>
          <:subtitle>{@about_headline}</:subtitle>
        </.header>

        <div class="grid gap-8 lg:grid-cols-[minmax(0,1.5fr)_minmax(18rem,1fr)]">
          <section class="space-y-5">
            <div class="flex items-center gap-4">
              <%= if @about_avatar_url do %>
                <img
                  src={@about_avatar_url}
                  alt={@about_name}
                  class="size-18 rounded-full object-cover ring-1 ring-base-300/70"
                />
              <% else %>
                <div class="inline-flex size-18 items-center justify-center rounded-full bg-primary/12 text-lg font-semibold text-primary ring-1 ring-primary/15">
                  {initials(@about_name)}
                </div>
              <% end %>

              <div class="space-y-1">
                <h2 class="text-xl font-semibold">{@about_name}</h2>
                <p class="text-sm text-base-content/65">{@about_headline}</p>
              </div>
            </div>

            <div class="space-y-4 text-base leading-8 text-base-content/80">
              <p :for={paragraph <- @about_bio}>{paragraph}</p>
            </div>
          </section>

          <aside class="space-y-3">
            <h2 class="text-sm font-semibold uppercase tracking-[0.22em] text-base-content/60">
              {gettext("Find Me")}
            </h2>

            <.social_link
              href={@github_url}
              label="GitHub"
              value={@github_label}
              badge="GH"
              badge_class="bg-neutral text-neutral-content"
            />

            <.social_link
              href={@linkedin_url}
              label="LinkedIn"
              value={@linkedin_label}
              badge="in"
              badge_class="bg-info text-info-content"
            />
          </aside>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :href, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :badge, :string, required: true
  attr :badge_class, :string, required: true

  defp social_link(assigns) do
    ~H"""
    <a
      href={@href}
      target="_blank"
      rel="noopener noreferrer"
      class="group flex items-center gap-4 rounded-lg border border-base-300/60 bg-base-100/70 px-4 py-4 transition-colors hover:border-primary/40 hover:bg-base-100"
    >
      <span class={[
        "inline-flex size-11 shrink-0 items-center justify-center rounded-full text-sm font-semibold",
        @badge_class
      ]}>
        {@badge}
      </span>

      <span class="min-w-0 flex-1">
        <span class="block text-sm font-medium text-base-content">{@label}</span>
        <span class="block truncate text-sm text-base-content/65">{@value}</span>
      </span>

      <.icon
        name="hero-arrow-up-right"
        class="size-4 shrink-0 text-base-content/35 transition group-hover:text-primary"
      />
    </a>
    """
  end

  defp bio_paragraphs(text) when is_binary(text) do
    text
    |> String.split(~r/\n{2,}/, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp bio_paragraphs(_), do: bio_paragraphs(@default_bio)

  defp initials(name) when is_binary(name) do
    name
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join("", &String.first/1)
    |> case do
      "" -> "GH"
      value -> String.upcase(value)
    end
  end

  defp initials(_), do: "GH"
end
