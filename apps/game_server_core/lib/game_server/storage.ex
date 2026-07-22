defmodule GameServer.Storage do
  @moduledoc """
  Object storage for user uploads (avatars, and future user-generated content).

  A thin facade over a configured backend so game code never depends on where
  bytes live:

    * `GameServer.Storage.Local` — local disk, the default (great for dev and
      single-node deploys).
    * `GameServer.Storage.S3` — any S3-compatible service (AWS S3, Cloudflare
      R2, Backblaze B2, MinIO, DigitalOcean Spaces).

  Select the backend with `STORAGE_ADAPTER` (`local` | `s3`); see the deployment
  docs for the full `STORAGE_*` variable list.

  ## Direct uploads

  Clients never stream bytes through the app. The server issues an upload ticket
  and the client uploads straight to the backend:

      key = Storage.build_key("avatars", user.id, "me.png")
      {:ok, ticket} = Storage.presigned_upload(key, content_type: "image/png")
      # -> client PUTs the file to ticket.url, then tells the server `key` is ready

  The ticket shape is identical for local disk and S3, so the client code does
  not change between environments.
  """

  alias GameServer.Storage.Adapter

  # Conservative default allow-list; callers can override per upload.
  @default_content_types ~w(image/png image/jpeg image/webp image/gif)

  @doc "The configured backend module (defaults to `GameServer.Storage.Local`)."
  @spec adapter() :: module()
  def adapter, do: Keyword.get(config(), :adapter, GameServer.Storage.Local)

  @doc false
  def config, do: Application.get_env(:game_server_core, __MODULE__, [])

  @spec put(Adapter.key(), iodata(), keyword()) :: {:ok, Adapter.key()} | {:error, term()}
  def put(key, data, opts \\ []), do: adapter().put(key, data, opts)

  @spec get(Adapter.key()) :: {:ok, binary()} | {:error, term()}
  def get(key), do: adapter().get(key)

  @spec delete(Adapter.key()) :: :ok | {:error, term()}
  def delete(key), do: adapter().delete(key)

  @spec exists?(Adapter.key()) :: boolean()
  def exists?(key), do: adapter().exists?(key)

  @doc "A readable URL for `key` (public or signed, backend-dependent)."
  @spec url(Adapter.key(), keyword()) :: String.t()
  def url(key, opts \\ []), do: adapter().url(key, opts)

  @doc "An upload ticket for the client (see the module doc)."
  @spec presigned_upload(Adapter.key(), keyword()) ::
          {:ok, Adapter.presigned()} | {:error, term()}
  def presigned_upload(key, opts \\ []), do: adapter().presigned_upload(key, opts)

  @doc "One page of stored objects. Opts: `:prefix`, `:offset`, `:limit` (admin use)."
  @spec list_objects(keyword()) :: [Adapter.object()]
  def list_objects(opts \\ []), do: adapter().list(opts)

  @doc "Total object count and byte size. Opts: `:prefix`."
  @spec usage(keyword()) :: %{count: non_neg_integer(), bytes: non_neg_integer()}
  def usage(opts \\ []), do: adapter().usage(opts)

  @doc """
  Build a collision-resistant object key: `<namespace>/<owner_id>/<random><ext>`.

  The extension is taken (lower-cased) from `filename`; everything else is
  server-chosen so a client can't overwrite another object.
  """
  @spec build_key(String.t(), String.t(), String.t()) :: String.t()
  def build_key(namespace, owner_id, filename) do
    ext = filename |> Path.extname() |> String.downcase()
    rand = 16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
    "#{namespace}/#{owner_id}/#{rand}#{ext}"
  end

  @doc """
  Validate an upload's content type and size before issuing a ticket.

  Options: `:content_types` (allow-list, defaults to common images),
  `:max_bytes` (defaults to `LIMIT_MAX_UPLOAD_BYTES`).
  """
  @spec validate_upload(String.t(), non_neg_integer(), keyword()) ::
          :ok | {:error, :unsupported_content_type | :too_large}
  def validate_upload(content_type, size, opts \\ []) do
    allowed = Keyword.get(opts, :content_types, @default_content_types)
    max = Keyword.get(opts, :max_bytes, GameServer.Limits.get(:max_upload_bytes))

    cond do
      content_type not in allowed -> {:error, :unsupported_content_type}
      size > max -> {:error, :too_large}
      true -> :ok
    end
  end
end
