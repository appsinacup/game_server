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



  @doc false
  @spec count_entries() :: non_neg_integer()
  def count_entries() do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        0

      _ ->
        raise "GameServer.KV.count_entries/0 is a stub - only available at runtime on GameServer"
    end
  end


  @doc false
  @spec count_entries(keyword()) :: non_neg_integer()
  def count_entries(_opts) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        0

      _ ->
        raise "GameServer.KV.count_entries/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc false
  @spec create_entry(map()) :: {:ok, GameServer.KV.Entry.t()} | {:error, Ecto.Changeset.t()}
  def create_entry(_attrs) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.KV.create_entry/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc false
  @spec delete(String.t()) :: :ok
  def delete(_key) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        :ok

      _ ->
        raise "GameServer.KV.delete/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc false
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


  @doc false
  @spec delete_entry(pos_integer()) :: :ok
  def delete_entry(_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        :ok

      _ ->
        raise "GameServer.KV.delete_entry/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc false
  @spec get(String.t()) :: {:ok, %{value: map(), metadata: map()}} | :error
  def get(_key) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.KV.get/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc false
  @spec get(
  String.t(),
  keyword()
) :: {:ok, %{value: map(), metadata: map()}} | :error
  def get(_key, _opts) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.KV.get/2 is a stub - only available at runtime on GameServer"
    end
  end


  @doc false
  @spec get_entry(pos_integer()) :: GameServer.KV.Entry.t() | nil
  def get_entry(_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        nil

      _ ->
        raise "GameServer.KV.get_entry/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc false
  @spec list_entries() :: [GameServer.KV.Entry.t()]
  def list_entries() do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        []

      _ ->
        raise "GameServer.KV.list_entries/0 is a stub - only available at runtime on GameServer"
    end
  end


  @doc false
  @spec list_entries(keyword()) :: [GameServer.KV.Entry.t()]
  def list_entries(_opts) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        []

      _ ->
        raise "GameServer.KV.list_entries/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc false
  @spec put(String.t(), map()) :: {:ok, GameServer.KV.Entry.t()} | {:error, Ecto.Changeset.t()}
  def put(_key, _value) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.KV.put/2 is a stub - only available at runtime on GameServer"
    end
  end


  @doc false
  @spec put(String.t(), map(), map()) :: {:ok, GameServer.KV.Entry.t()} | {:error, Ecto.Changeset.t()}
  def put(_key, _value, _metadata) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.KV.put/3 is a stub - only available at runtime on GameServer"
    end
  end


  @doc false
  @spec put(String.t(), map(), map(), keyword()) ::
  {:ok, GameServer.KV.Entry.t()} | {:error, Ecto.Changeset.t()}
  def put(_key, _value, _metadata, _opts) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.KV.put/4 is a stub - only available at runtime on GameServer"
    end
  end


  @doc false
  @spec update_entry(pos_integer(), map()) ::
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
