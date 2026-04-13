defmodule GameServerWeb.SRI do
  @moduledoc """
  Computes Subresource Integrity (SRI) hashes for static assets.

  Returns a `sha384-<base64>` string suitable for the `integrity` attribute
  on `<script>` and `<link>` tags. Hashes are computed once per path and
  cached in `persistent_term` for the lifetime of the BEAM node.

  Returns `nil` when the file doesn't exist (e.g. in dev before digest),
  so the attribute is safely omitted from the rendered HTML.

  ## Usage in HEEx templates

      <% path = ~p"/assets/js/app.js" %>
      <script src={path} integrity={SRI.integrity(path)} crossorigin="anonymous"></script>

  The module is aliased as `SRI` in html_helpers, so it's available in all
  templates without an explicit alias.
  """

  @pt_namespace {__MODULE__, :integrity}

  @doc """
  Returns the SRI integrity hash (`"sha384-..."`) for the given static path,
  or `nil` if the file cannot be found.

  The `path` should be the URL path as returned by the `~p` sigil
  (e.g. `"/assets/js/app.js"` or `"/assets/js/app-ABC123.js"` after digest).
  """
  @spec integrity(String.t() | nil) :: String.t() | nil
  def integrity(path) when is_binary(path) and path != "" do
    key = {@pt_namespace, path}

    case :persistent_term.get(key, :miss) do
      :miss -> compute_and_cache(key, path)
      result -> result
    end
  end

  def integrity(_), do: nil

  defp compute_and_cache(key, path) do
    # Strip leading slash and any query string / fragment
    clean =
      path
      |> String.trim_leading("/")
      |> URI.parse()
      |> Map.get(:path)

    hash =
      if is_binary(clean) and clean != "" do
        static_dir = Application.app_dir(:game_server_web, "priv/static")
        file_path = Path.join(static_dir, clean)

        if File.exists?(file_path) do
          content = File.read!(file_path)
          digest = :crypto.hash(:sha384, content) |> Base.encode64()
          "sha384-#{digest}"
        end
      end

    :persistent_term.put(key, hash)
    hash
  end
end
