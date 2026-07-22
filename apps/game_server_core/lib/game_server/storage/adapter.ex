defmodule GameServer.Storage.Adapter do
  @moduledoc """
  Behaviour for object-storage backends.

  Implemented by `GameServer.Storage.Local` (disk, the dev default) and
  `GameServer.Storage.S3` (any S3-compatible service — AWS S3, Cloudflare R2,
  Backblaze B2, MinIO, DigitalOcean Spaces). Callers go through the
  `GameServer.Storage` facade, never an adapter directly.
  """

  @type key :: String.t()

  @typedoc """
  An upload ticket handed to a client so it can upload bytes directly to the
  backend (S3/R2) or to the local upload endpoint — the client flow is identical
  either way.
  """
  @type presigned :: %{
          method: String.t(),
          url: String.t(),
          headers: %{optional(String.t()) => String.t()},
          key: key(),
          expires_in: pos_integer()
        }

  @typedoc "A stored object's metadata, as listed by the admin tools."
  @type object :: %{
          key: key(),
          size: non_neg_integer(),
          last_modified: DateTime.t() | nil
        }

  @callback put(key(), iodata(), keyword()) :: {:ok, key()} | {:error, term()}
  @callback get(key()) :: {:ok, binary()} | {:error, term()}
  @callback delete(key()) :: :ok | {:error, term()}
  @callback exists?(key()) :: boolean()
  @callback url(key(), keyword()) :: String.t()
  @callback presigned_upload(key(), keyword()) :: {:ok, presigned()} | {:error, term()}

  @doc "One page of objects. Opts: `:prefix`, `:offset`, `:limit`."
  @callback list(keyword()) :: [object()]

  @doc "Total object count and byte size. Opts: `:prefix`."
  @callback usage(keyword()) :: %{count: non_neg_integer(), bytes: non_neg_integer()}
end
