defmodule GamendWeb.DocsLive do
  @moduledoc """
  The shared renderer for a markdown guide collection: an index and a page.

  A guide is a markdown file and nothing else — the folder gives its category,
  the numeric filename prefix its order, the first heading its title, and
  optional front matter its heroicon. A folder's `_category.md` names the
  category and gives it an icon and a colour, which its guides inherit so each
  section reads as one group. Adding one takes no Elixir change.

  ## Why this is in core

  Three copies of this page existed: gamend's public `/docs`, Polyglot
  Pirates' player guide at `/guide`, and its admin engineering docs at
  `/admin/docs` — the last two forked from the first, along with a second copy
  of the loader in `Gamend.Content`. They drifted in both directions. The
  guide grew pill badges, prev/next navigation, a coloured title icon and the
  standard Back button; the docs kept the sibling list, `:persistent_term`
  caching and a real 404. Every host wanted the union and no host had it.

  ## Why a `use` macro rather than a configured route

  A host needs its own `<title>` copy, its own gettext domain and its own base
  path, and `live/4` gives a LiveView nowhere to put any of that. A module per
  collection also keeps `GamendHost.PageMeta` and the router referring to a
  real module name, the way they already do.

      defmodule MyAppWeb.GuideLive do
        use GamendWeb.DocsLive,
          collection: :guide,
          index_path: "/guide",
          item_path: "/guide"

        def index_title, do: gettext("Player guide")
        def index_subtitle, do: gettext("How the game actually works.")
      end

  Options:

    * `:collection` — the `Gamend.Content` registered path name. Default `:docs`.
    * `:index_path` — where the index lives, for the "all guides" link.
    * `:item_path` — the prefix a guide's own URL is built from.
    * `:not_found` — `:raise` (a 404, the default) or `:redirect` back to the
      index. Only ever use `:redirect` off a public URL knowingly: a bad slug
      answering 200 is a soft 404, which is worse for a crawler than a hard one.

  ## Navigation carries both shapes

  Prev/next *and* the sibling list. A collection written to be read front to
  back needs the first; one read as reference needs the second; and a reader
  who wants neither loses nothing by their being there. Picking one per
  collection was the alternative, and it is a knob that exists only because
  two authors happened to write two pages.
  """

  use GamendWeb, :html

  @doc "The heading and `<title>` of the index page."
  @callback index_title() :: String.t()

  @doc "The line under the index heading, or `nil` for none."
  @callback index_subtitle() :: String.t() | nil

  @doc "Shown when the collection's directory is missing or empty."
  @callback empty_message() :: String.t()

  @doc false
  defmacro __using__(opts) do
    collection = Keyword.get(opts, :collection, :docs)
    index_path = Keyword.get(opts, :index_path, "/docs/setup")
    item_path = Keyword.get(opts, :item_path, "/docs")

    # Decided here rather than at runtime. A helper that took `:raise |
    # :redirect` and dispatched read fine and typed terribly: with `:raise`
    # always the argument, its only reachable clause never returns, so
    # dialyzer reported the call itself as one that "will not succeed" in
    # every host. Emitting one branch or the other makes the generated code
    # say what it does.
    not_found =
      case Keyword.get(opts, :not_found, :raise) do
        :raise ->
          quote(do: raise(GamendWeb.NotFoundError))

        :redirect ->
          quote(do: {:noreply, push_navigate(socket, to: unquote(index_path))})

        other ->
          raise ArgumentError,
                "GamendWeb.DocsLive :not_found must be :raise or :redirect, got: #{inspect(other)}"
      end

    quote do
      use GamendWeb, :live_view

      @behaviour GamendWeb.DocsLive

      alias Gamend.Content
      alias GamendWeb.OnMount.SeoTitle

      @doc_collection unquote(collection)
      @doc_index_path unquote(index_path)
      @doc_item_path unquote(item_path)

      @impl GamendWeb.DocsLive
      def index_title, do: gettext("Documentation")

      @impl GamendWeb.DocsLive
      def index_subtitle, do: nil

      @impl GamendWeb.DocsLive
      def empty_message, do: gettext("No guides found.")

      defoverridable GamendWeb.DocsLive

      @impl true
      def mount(_params, _session, socket) do
        {:ok, assign(socket, :categories, Content.list_doc_categories(@doc_collection))}
      end

      # The two components are called as plain functions, not `<.show />`, so
      # their `attr` defaults never run — those are a call-site feature of the
      # HEEx compiler. Anything optional is therefore defaulted here instead.
      @impl true
      def render(%{live_action: :show} = assigns) do
        assigns
        |> GamendWeb.DocsLive.with_layout_assigns()
        |> assign(index_path: @doc_index_path, item_path: @doc_item_path)
        |> GamendWeb.DocsLive.show()
      end

      def render(assigns) do
        assigns
        |> GamendWeb.DocsLive.with_layout_assigns()
        |> assign(
          item_path: @doc_item_path,
          title: index_title(),
          subtitle: index_subtitle(),
          empty_message: empty_message()
        )
        |> GamendWeb.DocsLive.index()
      end

      @impl true
      def handle_params(%{"slug" => slug}, _uri, socket) do
        case Content.get_doc(@doc_collection, slug) do
          nil ->
            unquote(not_found)

          guide ->
            {prev, next} = Content.doc_neighbours(@doc_collection, slug)
            category = Content.doc_category(@doc_collection, slug)

            {:noreply,
             socket
             |> SeoTitle.assign_page_title(guide.title)
             |> assign(:guide, guide)
             |> assign(:category, category)
             |> assign(:html, Content.doc_html(@doc_collection, slug))
             |> assign(:prev, prev)
             |> assign(:next, next)
             |> assign(:siblings, GamendWeb.DocsLive.siblings(category, slug))}
        end
      end

      # `?guide=` is how the single-page version of these pages deep-linked a
      # section. Those links are in blog posts, chat history and the guides'
      # own cross-references, so they move to the guide's own URL rather than
      # silently landing on the index.
      def handle_params(%{"guide" => slug}, _uri, socket) do
        if Content.get_doc(@doc_collection, slug) do
          {:noreply, push_navigate(socket, to: "#{@doc_item_path}/#{slug}")}
        else
          {:noreply, SeoTitle.assign_page_title(socket, index_title())}
        end
      end

      def handle_params(_params, _uri, socket) do
        {:noreply, SeoTitle.assign_page_title(socket, index_title())}
      end

      defoverridable mount: 3, handle_params: 3, render: 1
    end
  end

  @doc """
  Fills in the assigns the layout reads but a LiveView does not always have.

  `current_path` is set by a plug that not every host mounts, and
  `current_scope` is absent on a public page with no session. Both are optional
  to the layout and neither can be defaulted by `attr` here — see `render/1`.
  """
  @spec with_layout_assigns(map()) :: map()
  def with_layout_assigns(assigns) do
    assigns
    |> assign_new(:current_path, fn -> nil end)
    |> assign_new(:current_scope, fn -> nil end)
  end

  @doc """
  The other guides in a guide's category, in reading order.

  Empty rather than nil when the guide is alone in its category — or has no
  `_category.md` at all — so the template's `:if` reads as a list check.
  """
  @spec siblings(map() | nil, String.t()) :: [map()]
  def siblings(nil, _slug), do: []

  def siblings(category, slug), do: Enum.reject(category.guides, &(&1.slug == slug))

  attr :flash, :map, required: true
  attr :current_scope, :any, default: nil
  attr :current_path, :string, default: nil
  attr :categories, :list, required: true
  attr :item_path, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :empty_message, :string, required: true

  @doc """
  The index: every category, every guide's title and summary.

  Titles and summaries only. Repeating the bodies here would make every guide
  duplicate content competing with itself, and make the index the longest page
  in the collection.
  """
  def index(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_path={@current_path}>
      <div class="space-y-6">
        <.header>
          <h1 class="text-3xl font-bold">{@title}</h1>
          <:subtitle :if={@subtitle}>{@subtitle}</:subtitle>
        </.header>

        <p :if={@categories == []} class="text-base-content/60">{@empty_message}</p>

        <section :for={category <- @categories} class="space-y-2">
          <h2 class="flex items-center gap-2 border-t border-base-300/60 pt-6 font-semibold uppercase tracking-[0.24em]">
            <.icon name={category.icon} class={"size-5 #{category.color}"} />
            {category.category}
          </h2>

          <.link
            :for={guide <- category.guides}
            navigate={"#{@item_path}/#{guide.slug}"}
            class="card block bg-base-100 shadow-sm transition-shadow hover:shadow-md"
          >
            <div class="card-body flex-row items-center gap-3 py-4">
              <.icon name={guide.icon} class={"size-6 shrink-0 opacity-80 #{category.color}"} />
              <span class="card-title shrink-0 text-xl">{guide.title}</span>
              <span class="line-clamp-1 grow text-sm text-base-content/50">{guide.summary}</span>
              <.icon name="hero-chevron-right" class="size-4 shrink-0" />
            </div>
          </.link>
        </section>
      </div>
    </Layouts.app>
    """
  end

  attr :flash, :map, required: true
  attr :current_scope, :any, default: nil
  attr :current_path, :string, default: nil
  attr :guide, :map, required: true
  attr :category, :map, default: nil
  attr :html, :string, default: nil
  attr :prev, :map, default: nil
  attr :next, :map, default: nil
  attr :siblings, :list, default: []
  attr :index_path, :string, required: true
  attr :item_path, :string, required: true

  @doc """
  One guide: title, body, then both navigations.

  No category eyebrow above the title. The category is on the title icon as a
  colour and named again at the foot of the page, where "More in Operations"
  heads a list you can act on — an uppercase band between the breadcrumb and
  the heading said it a third time and linked nowhere.
  """
  def show(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_path={@current_path}>
      <article class="space-y-6">
        <%!-- `.header back=` is the same Back button as every other page with a
              parent, on the title's own line rather than a stray text link
              floating above it. --%>
        <.header back={@index_path} class="flex items-center gap-3">
          <.icon
            name={@guide.icon}
            class={"size-8 shrink-0 opacity-80 #{(@category && @category.color) || "text-primary"}"}
          />
          {@guide.title}
        </.header>

        <%!-- `markdown-content`, not `prose`: the Tailwind Typography plugin is
              not installed, so `prose` matches no rules at all and the body
              renders as unstyled text. `.markdown-content` is the hand-written
              stylesheet in `assets/css/app.css`. --%>
        <div class="markdown-content">{raw(@html)}</div>

        <nav
          :if={@prev || @next}
          class="flex justify-between gap-3 border-t border-base-300/60 pt-6"
          aria-label={gettext("More pages")}
        >
          <%!-- The empty span keeps `justify-between` pushing a lone "next"
                to the right on the first page. --%>
          <.link :if={@prev} navigate={"#{@item_path}/#{@prev.slug}"} class="btn btn-outline btn-sm">
            <.icon name="hero-chevron-left" class="size-4" />
            {@prev.title}
          </.link>
          <span :if={!@prev}></span>
          <.link :if={@next} navigate={"#{@item_path}/#{@next.slug}"} class="btn btn-outline btn-sm">
            {@next.title}
            <.icon name="hero-chevron-right" class="size-4" />
          </.link>
        </nav>

        <nav :if={@siblings != []} class="space-y-2 border-t border-base-300/60 pt-6">
          <h2 class="text-sm font-semibold uppercase tracking-[0.24em]">
            {gettext("More in %{category}", category: (@category && @category.category) || "")}
          </h2>
          <ul class="space-y-1">
            <li :for={sibling <- @siblings}>
              <.link navigate={"#{@item_path}/#{sibling.slug}"} class="link link-hover">
                {sibling.title}
              </.link>
            </li>
          </ul>
        </nav>
      </article>
    </Layouts.app>
    """
  end
end
