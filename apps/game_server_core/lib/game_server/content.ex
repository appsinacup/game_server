defmodule GameServer.Content do
  @moduledoc """
  Reads and renders Markdown content from files/directories configured
  in the theme JSON config (`"changelog"` and `"blog"` keys).

  Paths are resolved relative to the project working directory.
  """

  alias GameServer.Theme.JSONConfig

  # ---------------------------------------------------------------------------
  # Changelog
  # ---------------------------------------------------------------------------

  @doc """
  Returns the rendered changelog HTML, or `nil` when the changelog path is
  not configured or the file doesn't exist.
  """
  @spec changelog_html() :: String.t() | nil
  def changelog_html do
    case changelog_path() do
      nil ->
        nil

      path ->
        case render_markdown_file(path, "changelog") do
          nil -> nil
          html -> apply_changelog_pills(html)
        end
    end
  end

  @doc """
  Returns the resolved absolute path to the changelog file, or `nil`.
  """
  @spec changelog_path() :: String.t() | nil
  def changelog_path do
    case JSONConfig.get_setting(:changelog) do
      p when is_binary(p) and p != "" -> resolve_path(p)
      _ -> nil
    end
  end

  # ---------------------------------------------------------------------------
  # Blog
  # ---------------------------------------------------------------------------

  @doc """
  Lists all blog posts sorted newest-first.

  Each post is a map with keys:
    * `:slug`  – URL-safe identifier derived from the filename
    * `:title` – extracted from the first `# ` heading (or humanised slug)
    * `:date`  – `Date.t()` parsed from filename prefix or file mtime
    * `:path`  – absolute path to the `.md` file
    * `:excerpt` – first non-heading paragraph (≤ 200 chars)
  """
  @spec list_blog_posts() :: [map()]
  def list_blog_posts do
    case blog_dir() do
      nil ->
        []

      dir ->
        dir
        |> Path.join("**/*.md")
        |> Path.wildcard()
        |> Enum.map(&parse_blog_post/1)
        |> Enum.sort_by(& &1.date, {:desc, Date})
    end
  end

  @doc """
  Returns a single blog post map by slug, or `nil`.
  """
  @spec get_blog_post(String.t()) :: map() | nil
  def get_blog_post(slug) when is_binary(slug) do
    Enum.find(list_blog_posts(), fn p -> p.slug == slug end)
  end

  @doc """
  Returns `{prev_post, next_post}` neighbours for the given slug (newest-first order).
  Either may be `nil`.
  """
  @spec blog_neighbours(String.t()) :: {map() | nil, map() | nil}
  def blog_neighbours(slug) do
    posts = list_blog_posts()
    idx = Enum.find_index(posts, fn p -> p.slug == slug end)

    if idx do
      prev = if idx > 0, do: Enum.at(posts, idx - 1)
      next = Enum.at(posts, idx + 1)
      {prev, next}
    else
      {nil, nil}
    end
  end

  @doc """
  Renders a blog post's markdown to HTML, or `nil`.
  """
  @spec blog_post_html(String.t()) :: String.t() | nil
  def blog_post_html(slug) do
    case get_blog_post(slug) do
      nil ->
        nil

      post ->
        case render_markdown_file(post.path, "blog") do
          nil -> nil
          html -> strip_first_h1(html)
        end
    end
  end

  @doc """
  Returns the resolved absolute path to the blog directory, or `nil`.
  """
  @spec blog_dir() :: String.t() | nil
  def blog_dir do
    case JSONConfig.get_setting(:blog) do
      p when is_binary(p) and p != "" -> resolve_path(p)
      _ -> nil
    end
  end

  @doc """
  Groups blog posts by `{year, month}` (newest first).
  Returns a list of `{year, [{month, [posts]}]}`.
  """
  @spec blog_posts_grouped() :: [{integer(), [{integer(), [map()]}]}]
  def blog_posts_grouped do
    list_blog_posts()
    |> Enum.group_by(fn p -> {p.date.year, p.date.month} end)
    |> Enum.sort_by(fn {{y, m}, _} -> {y, m} end, :desc)
    |> Enum.group_by(fn {{y, _m}, _posts} -> y end, fn {{_y, m}, posts} -> {m, posts} end)
    |> Enum.sort_by(fn {y, _} -> y end, :desc)
  end

  # ---------------------------------------------------------------------------
  # Content asset serving
  # ---------------------------------------------------------------------------

  @doc """
  Returns the absolute path for a content asset (image etc.) relative to the
  blog or changelog directory. Returns `nil` when not found or path traversal
  is attempted.
  """
  @spec content_asset_path(String.t(), String.t()) :: String.t() | nil
  def content_asset_path("blog", relative) do
    serve_asset(blog_dir(), relative)
  end

  def content_asset_path("changelog", relative) do
    case changelog_path() do
      nil -> nil
      path -> serve_asset(Path.dirname(path), relative)
    end
  end

  def content_asset_path(_, _), do: nil

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp serve_asset(nil, _relative), do: nil

  defp serve_asset(base_dir, relative) do
    # Prevent path traversal
    clean = Path.expand(relative, base_dir)

    if String.starts_with?(clean, Path.expand(base_dir)) and File.regular?(clean) do
      clean
    else
      nil
    end
  end

  defp resolve_path(path) do
    # Strip leading "/" since config paths like "/blog" should be relative
    # to the project root, not absolute filesystem paths (matching the
    # convention used for logo/banner which are web URL paths).
    clean = String.trim_leading(path, "/")
    expanded = Path.expand(clean, File.cwd!())

    cond do
      File.exists?(expanded) -> expanded
      File.exists?(clean) -> Path.expand(clean)
      File.exists?(path) -> Path.expand(path)
      true -> nil
    end
  end

  defp render_markdown_file(path, content_type) do
    case File.read(path) do
      {:ok, content} ->
        case Earmark.as_html(content, smartypants: false) do
          {:ok, html, _warnings} -> rewrite_relative_images(html, content_type)
          {:error, _html, _msgs} -> nil
        end

      _ ->
        nil
    end
  end

  # Rewrite relative image `src` attributes so that `./img.png` or `img.png`
  # become `/content/<type>/img.png`, which is served by ContentAssetController.
  defp rewrite_relative_images(html, content_type) do
    Regex.replace(
      ~r/<img([^>]*)\ssrc="([^"]+)"([^>]*)>/,
      html,
      fn full, before, src, after_attr ->
        if String.starts_with?(src, "http") or String.starts_with?(src, "/") do
          full
        else
          clean = src |> String.trim_leading("./")
          ~s(<img#{before} src="/content/#{content_type}/#{clean}"#{after_attr}>)
        end
      end
    )
  end

  defp parse_blog_post(path) do
    filename = Path.basename(path, ".md")
    {date, slug} = extract_date_and_slug(filename)
    content = File.read!(path)
    title = extract_title(content) || humanize_slug(slug)
    excerpt = extract_excerpt(content)

    %{
      slug: slug,
      title: title,
      date: date,
      path: path,
      excerpt: excerpt
    }
  end

  defp extract_date_and_slug(filename) do
    case Regex.run(~r/^(\d{4}-\d{2}-\d{2})-(.+)$/, filename) do
      [_, date_str, slug] ->
        case Date.from_iso8601(date_str) do
          {:ok, date} -> {date, slug}
          _ -> {file_date_fallback(), filename}
        end

      _ ->
        {file_date_fallback(), filename}
    end
  end

  defp file_date_fallback, do: Date.utc_today()

  defp extract_title(content) do
    content
    |> String.split("\n")
    |> Enum.find_value(fn line ->
      case Regex.run(~r/^#\s+(.+)$/, String.trim(line)) do
        [_, title] -> String.trim(title)
        _ -> nil
      end
    end)
  end

  defp extract_excerpt(content) do
    content
    |> String.split("\n")
    |> Enum.reject(fn line ->
      trimmed = String.trim(line)
      trimmed == "" or String.starts_with?(trimmed, "#")
    end)
    |> List.first("")
    |> String.trim()
    |> String.slice(0, 200)
  end

  defp humanize_slug(slug) do
    slug
    |> String.replace(~r/[-_]/, " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  # Remove the first <h1>...</h1> from rendered HTML since the blog post
  # header already displays the title separately.
  defp strip_first_h1(html) do
    Regex.replace(~r/<h1>.*?<\/h1>\s*/s, html, "", global: false)
  end

  # Pill tag definitions: [tag] → {css_class_suffix, display_label}
  @changelog_tags %{
    "fix" => {"fix", "Fix"},
    "fixed" => {"fix", "Fix"},
    "added" => {"added", "Added"},
    "add" => {"added", "Added"},
    "new" => {"added", "New"},
    "bug" => {"bug", "Bug"},
    "changed" => {"changed", "Changed"},
    "change" => {"changed", "Changed"},
    "removed" => {"removed", "Removed"},
    "remove" => {"removed", "Removed"},
    "security" => {"security", "Security"},
    "breaking" => {"breaking", "Breaking"},
    "deprecated" => {"deprecated", "Deprecated"},
    "perf" => {"perf", "Perf"},
    "docs" => {"docs", "Docs"}
  }

  # Convert `[tag]` markers in changelog HTML into colored pill badges.
  # Matches patterns like `[fix]`, `[added]`, etc. at the start of list items.
  defp apply_changelog_pills(html) do
    Regex.replace(
      ~r/\[([a-zA-Z]+)\]/,
      html,
      fn _full, tag ->
        key = String.downcase(tag)

        case Map.get(@changelog_tags, key) do
          {class_suffix, label} ->
            ~s(<span class="changelog-pill changelog-pill-#{class_suffix}">#{label}</span>)

          nil ->
            "[#{tag}]"
        end
      end
    )
  end
end
