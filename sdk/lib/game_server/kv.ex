defmodule GameServer.KV do
  @moduledoc ~S"""
  Generic key/value storage.
  
  This is intentionally minimal and un-opinionated.
  
  If you want namespacing, encode it in `key` (e.g. `"polyglot_pirates:key1"`).
  If you want per-user values, pass `user_id: ...` to `get/2`, `put/4`, and `delete/2`.
  
  This module uses the app cache (`GameServer.Cache`) as a best-effort read cache.
  Writes update the cache and deletes evict it.
  

  **Note:** This is an SDK stub. Calling these functions will raise an error.
  The actual implementation runs on the GameServer.
  """

  @type list_opts() :: [
  page: pos_integer(),
  page_size: pos_integer(),
  user_id: pos_integer(),
  global_only: boolean(),
  key: String.t()
]
  @type attrs() :: %{
  :key => String.t(),
  optional(:user_id) => pos_integer(),
  :value => value(),
  optional(:metadata) => metadata()
}
  @type payload() :: %{value: value(), metadata: metadata()}
  @type metadata() :: map()
  @type value() :: map()

  @doc ~S"""
    Count the number of entries that match the optional filter.
    
    Accepts the same options as `list_entries/1` (see `t:list_opts/0`). Returns a non-negative integer.
    
  """
  @spec count_entries() :: non_neg_integer()
  def count_entries() do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        0

      _ ->
        raise "GameServer.KV.count_entries/0 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Count the number of entries that match the optional filter.
    
    Accepts the same options as `list_entries/1` (see `t:list_opts/0`). Returns a non-negative integer.
    
  """
  @spec count_entries(list_opts()) :: non_neg_integer()
  def count_entries(_opts) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        0

      _ ->
        raise "GameServer.KV.count_entries/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Create a new `Entry` from `attrs` (expecting `key`, optional `user_id`, `value`, `metadata`).
    Returns `{:ok, entry}` or `{:error, changeset}`.
    
  """
  @spec create_entry(attrs()) :: {:ok, GameServer.KV.Entry.t()} | {:error, Ecto.Changeset.t()}
  def create_entry(_attrs) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.KV.create_entry/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Delete the entry at `key`.
    
    Pass `user_id: id` in `opts` to delete a per-user key. Returns `:ok`.
    
  """
  @spec delete(String.t()) :: :ok
  def delete(_key) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        :ok

      _ ->
        raise "GameServer.KV.delete/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Delete the entry at `key`.
    
    Pass `user_id: id` in `opts` to delete a per-user key. Returns `:ok`.
    
  """
  @spec delete(
  String.t(),
  keyword()
) :: :ok
  def delete(_key, _opts) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        :ok

      _ ->
        raise "GameServer.KV.delete/2 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Delete an entry by its `id`.
    
    Returns `:ok` whether or not the entry existed.
    
  """
  @spec delete_entry(pos_integer()) :: :ok
  def delete_entry(_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        :ok

      _ ->
        raise "GameServer.KV.delete_entry/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Retrieve the value and metadata stored for `key`.
    
    Pass `user_id: id` in `opts` to scope the lookup to a specific user.
    Returns `{:ok, %{value: map(), metadata: map()}}` when found, or `:error` when not present.
    
  """
  @spec get(String.t()) :: {:ok, payload()} | :error
  def get(_key) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        if :erlang.phash2(make_ref(), 2) == 0, do: :error, else: {:ok, %{value: %{}, metadata: %{}}}

      _ ->
        raise "GameServer.KV.get/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Retrieve the value and metadata stored for `key`.
    
    Pass `user_id: id` in `opts` to scope the lookup to a specific user.
    Returns `{:ok, %{value: map(), metadata: map()}}` when found, or `:error` when not present.
    
  """
  @spec get(
  String.t(),
  keyword()
) :: {:ok, payload()} | :error
  def get(_key, _opts) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        if :erlang.phash2(make_ref(), 2) == 0, do: :error, else: {:ok, %{value: %{}, metadata: %{}}}

      _ ->
        raise "GameServer.KV.get/2 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Fetch an `Entry` by its numeric `id`.
    Returns the `Entry` struct or `nil` if not found.
    
  """
  @spec get_entry(pos_integer()) :: GameServer.KV.Entry.t() | nil
  def get_entry(_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        nil

      _ ->
        raise "GameServer.KV.get_entry/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    List key/value entries with optional pagination and filtering.
    
    Supported options: `:page`, `:page_size`, `:user_id`, `:global_only`, and `:key` (substring filter).
    See `t:list_opts/0` for the expected option types.
    Returns a list of `Entry` structs ordered by most recently updated.
    
  """
  @spec list_entries() :: [GameServer.KV.Entry.t()]
  def list_entries() do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        []

      _ ->
        raise "GameServer.KV.list_entries/0 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    List key/value entries with optional pagination and filtering.
    
    Supported options: `:page`, `:page_size`, `:user_id`, `:global_only`, and `:key` (substring filter).
    See `t:list_opts/0` for the expected option types.
    Returns a list of `Entry` structs ordered by most recently updated.
    
  """
  @spec list_entries(list_opts()) :: [GameServer.KV.Entry.t()]
  def list_entries(_opts) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        []

      _ ->
        raise "GameServer.KV.list_entries/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Store `value` with optional `metadata` at `key`.
    
    When using the 4-arity, supported options include `user_id: id` to scope the entry to a user.
    Returns `{:ok, entry}` on success or `{:error, changeset}` on validation failure.
    
  """
  @spec put(String.t(), value()) :: {:ok, GameServer.KV.Entry.t()} | {:error, Ecto.Changeset.t()}
  def put(_key, _value) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.KV.put/2 is a stub - only available at runtime on GameServer"
    end
  end


  @doc false
  @spec put(String.t(), value(), metadata()) ::
  {:ok, GameServer.KV.Entry.t()} | {:error, Ecto.Changeset.t()}
  def put(_key, _value, _metadata) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.KV.put/3 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Store `value` with optional `metadata` at `key`.
    
    When using the 4-arity, supported options include `user_id: id` to scope the entry to a user.
    Returns `{:ok, entry}` on success or `{:error, changeset}` on validation failure.
    
  """
  @spec put(String.t(), value(), metadata(), list_opts()) ::
  {:ok, GameServer.KV.Entry.t()} | {:error, Ecto.Changeset.t()}
  def put(_key, _value, _metadata, _opts) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.KV.put/4 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Update an existing entry by `id` with `attrs`.
    Returns `{:ok, entry}`, `{:error, :not_found}` if missing, or `{:error, changeset}` on validation error.
    
  """
  @spec update_entry(pos_integer(), attrs()) ::
  {:ok, GameServer.KV.Entry.t()} | {:error, :not_found} | {:error, Ecto.Changeset.t()}
  def update_entry(_id, _attrs) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.KV.update_entry/2 is a stub - only available at runtime on GameServer"
    end
  end

end
