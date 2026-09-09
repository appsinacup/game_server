# `Gamend.Content`
[🔗](https://github.com/appsinacup/gamend/blob/v1.0.7/lib/gamend/content.ex#L1)

Reads and renders Markdown content from project files and directories.

Lookup is path-based rather than theme-config driven. Hosts register named
content sources, and this module resolves whichever configured files or
directories exist for those sources.

All content is cached in `:persistent_term` after the first read.
Call `reload/0` to invalidate everything (e.g. after a config change).

# `apply_changelog_pills`

```elixir
@spec apply_changelog_pills(String.t()) :: String.t()
```

Converts `[tag]` markers in changelog or roadmap HTML into coloured badges.

A catch-all: any `[word]` becomes a pill, known tags in their own colour and
everything else in the neutral one. That is deliberate for a changelog, where
every line opens with a marker and an unrecognised one is a typo worth
seeing — unlike the guide, where brackets are prose.

Applied inside `changelog_html/0` and `roadmap_html/0`, so the result is
cached. Labels here are **English literals and must stay that way**: a
translated label baked into the cache would be served to every other locale.
A host that wants translated pills re-labels them per request — see `pill/2`.

# `asset_path`

```elixir
@spec asset_path(atom() | String.t(), String.t()) :: String.t() | nil
```

Returns the absolute path for an asset relative to a registered content
source. Returns `nil` when not found or path traversal is attempted.

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

# `doc_category`

```elixir
@spec doc_category(atom(), String.t()) :: map() | nil
```

The category a guide belongs to — its display title, icon and colour — or
`nil`.

Found by membership rather than by name: a guide carries its category's
*folder* ("10-setup") while the category carries the display title ("Setup").
Both pages that render a guide need this, so deriving it twice by hand was
how the two drifted apart.

# `doc_html`

```elixir
@spec doc_html(atom(), String.t()) :: String.t() | nil
```

Renders a guide's markdown to HTML, or `nil`.

The leading `# ` heading is dropped: the page renders the title itself, so
leaving it in would print it twice.

A collection registered with `:post_render` runs that `{module, function}`
over the finished HTML — the hook Polyglot Pirates' guide uses to turn
`[coins:250]` into a badge. It runs *after* markdown rendering because the
sanitiser strips raw HTML out of the markdown, and inside the cache because
the result is as static as the markdown it came from.

# `doc_neighbours`

```elixir
@spec doc_neighbours(atom(), String.t()) :: {map() | nil, map() | nil}
```

`{previous, next}` guides around `slug` in reading order, either possibly
`nil`.

Across categories, not within one: the collections are written to be read
front to back, and stopping at a category boundary would strand the reader on
the last page of each section.

# `frontmatter`

```elixir
@spec frontmatter(String.t()) :: %{required(String.t()) =&gt; String.t()}
```

Reads a leading `---` fenced block of `key: value` lines.

Deliberately not YAML: the values here are single-line strings, and a parser
dependency for that would be its own liability.

# `get_blog_post`

```elixir
@spec get_blog_post(String.t()) :: map() | nil
```

Returns a single blog post map by slug, or `nil`.

# `get_doc`

```elixir
@spec get_doc(atom(), String.t()) :: map() | nil
```

Returns a single guide map by slug, or `nil`.

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
  * `:excerpt` – first non-heading paragraph (≤ 200 chars), for cards and
    meta descriptions
  * `:lede` – that same paragraph in full, which is what a post opens with

# `list_doc_categories`

```elixir
@spec list_doc_categories(atom()) :: [%{category: String.t(), guides: [map()]}]
```

Lists every guide in a collection, grouped into categories in reading order.

Structure comes from the file tree rather than front matter, so a guide is a
file and nothing else has to be edited to add one:

    priv/docs/10-core-setup/20-deployment.md

The numeric prefixes order categories and guides and are stripped from the
slug; the folder name is the category; the title is the first `# ` heading.
Returns `[%{category: String.t(), guides: [guide]}]`, each guide a map of
`:slug`, `:title`, `:summary` and `:path`.

## Collections

A *collection* is the registered path name the guides are read from, so one
app can serve several unrelated sets — gamend serves `:docs`, Polyglot
Pirates serves both `:docs` (engineering, admin-only) and `:guide` (the
player guide). The collection is part of every cache key, so the sets never
see each other's entries. Everything defaults to `:docs`, which is what the
single-collection callers already had.

# `list_docs`

```elixir
@spec list_docs(atom()) :: [map()]
```

Every guide as a flat list, in the same order as `list_doc_categories/1`.

# `path`

```elixir
@spec path(atom() | String.t()) :: String.t() | nil
```

Returns the resolved absolute path for a registered content source, or `nil`.

# `pill`

```elixir
@spec pill(String.t(), String.t()) :: String.t()
```

One pill badge: `class_suffix` picks the colour, `label` is what it reads.

The markup lives here rather than at each call site because a host that adds
its own tags — Polyglot Pirates re-labels the roadmap's in the reader's
language — was copying this line, class name and all, and would not notice
the day the stylesheet changed underneath it.

# `register_path`

```elixir
@spec register_path(atom() | String.t(), keyword()) :: :ok
```

Registers a named content source.

Supported options:
  * `:kind` - `:file` or `:dir`
  * `:path` - single candidate path
  * `:candidates` - ordered candidate paths
  * `:asset_root` - `:self` or `:dirname` when serving assets
  * `:post_render` - `{module, function}` applied to rendered guide HTML

# `relabel_pills`

```elixir
@spec relabel_pills(String.t() | nil, %{
  optional(String.t()) =&gt; {String.t(), String.t()}
}) ::
  String.t() | nil
```

Re-labels pills that `apply_changelog_pills/1` rendered as neutral `other`.

The one seam a translated pill can use. `apply_changelog_pills/1` runs inside
the cache with English labels, so a host cannot translate there; this runs on
the way out, per request, and takes `%{"tag" => {class_suffix, label}}` with
the label already translated.

Both spellings are handled: a marker that reached the cache is already a
neutral `<span>`, while one written after the fact is still `[Tag]` — the
roadmap has had both, and handling only the first left `[Beta]` printed
verbatim in the middle of a heading.

# `reload`

```elixir
@spec reload() :: :ok
```

Clears all cached content so the next call re-reads from disk.

# `roadmap_html`

```elixir
@spec roadmap_html() :: String.t() | nil
```

Returns the rendered roadmap HTML, or `nil` when the roadmap path is
not configured or the file doesn't exist.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
