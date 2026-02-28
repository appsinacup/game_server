# `GameServer.Content`

Reads and renders Markdown content from files/directories configured
in the theme JSON config (`"changelog"` and `"blog"` keys).

Paths are resolved relative to the project working directory.

All content is cached in `:persistent_term` after the first read.
Call `reload/0` to invalidate everything (e.g. after a config change).

# `blog_dir`

```elixir
@spec blog_dir() :: String.t() | nil
```

Returns the resolved absolute path to the blog directory, or `nil`.

# `blog_neighbours`

```elixir
@spec blog_neighbours(String.t()) :: {map() | nil, map() | nil}
```

Returns `{prev_post, next_post}` neighbours for the given slug (newest-first order).
Either may be `nil`.

# `blog_post_html`

```elixir
@spec blog_post_html(String.t()) :: String.t() | nil
```

Renders a blog post's markdown to HTML, or `nil`.

# `blog_posts_grouped`

```elixir
@spec blog_posts_grouped() :: [{integer(), [{integer(), [map()]}]}]
```

Groups blog posts by `{year, month}` (newest first).
Returns a list of `{year, [{month, [posts]}]}`.

# `changelog_html`

```elixir
@spec changelog_html() :: String.t() | nil
```

Returns the rendered changelog HTML, or `nil` when the changelog path is
not configured or the file doesn't exist.

# `changelog_path`

```elixir
@spec changelog_path() :: String.t() | nil
```

Returns the resolved absolute path to the changelog file, or `nil`.

# `content_asset_path`

```elixir
@spec content_asset_path(String.t(), String.t()) :: String.t() | nil
```

Returns the absolute path for a content asset (image etc.) relative to the
blog or changelog directory. Returns `nil` when not found or path traversal
is attempted.

# `get_blog_post`

```elixir
@spec get_blog_post(String.t()) :: map() | nil
```

Returns a single blog post map by slug, or `nil`.

# `list_blog_posts`

```elixir
@spec list_blog_posts() :: [map()]
```

Lists all blog posts sorted newest-first.

Each post is a map with keys:
  * `:slug`  – URL-safe identifier derived from the filename
  * `:title` – extracted from the first `# ` heading (or humanised slug)
  * `:date`  – `Date.t()` parsed from filename prefix or file mtime
  * `:path`  – absolute path to the `.md` file
  * `:excerpt` – first non-heading paragraph (≤ 200 chars)

# `reload`

```elixir
@spec reload() :: :ok
```

Clears all cached content so the next call re-reads from disk.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
