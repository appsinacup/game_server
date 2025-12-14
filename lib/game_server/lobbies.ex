defmodule GameServer.Lobbies do
  @moduledoc """
  Context module for lobby management: creating, updating, listing and searching lobbies.

  This module contains the core domain operations; more advanced membership and
  permission logic will be added in follow-up tasks.

  ## Usage

      # Create a lobby (returns {:ok, lobby} | {:error, changeset})
      {:ok, lobby} = GameServer.Lobbies.create_lobby(%{name: "fun-room", title: "Fun Room", host_id: host_id})

      # List public lobbies (paginated/filterable)
      lobbies = GameServer.Lobbies.list_lobbies(%{}, page: 1, page_size: 25)

      # Join and leave
      {:ok, user} = GameServer.Lobbies.join_lobby(user, lobby.id)
      {:ok, _} = GameServer.Lobbies.leave_lobby(user)

      # Get current lobby members
      members = GameServer.Lobbies.get_lobby_members(lobby)

      # Subscribe to global or per-lobby events
      :ok = GameServer.Lobbies.subscribe_lobbies()
      :ok = GameServer.Lobbies.subscribe_lobby(lobby.id)

  ## PubSub Events

  This module broadcasts the following events:

  - `"lobbies"` topic (global lobby list changes):
    - `{:lobby_created, lobby}` - a new lobby was created
    - `{:lobby_updated, lobby}` - a lobby was updated
    - `{:lobby_deleted, lobby_id}` - a lobby was deleted

  - `"lobby:<lobby_id>"` topic (per-lobby membership changes):
    - `{:user_joined, lobby_id, user_id}` - a user joined the lobby
    - `{:user_left, lobby_id, user_id}` - a user left the lobby
    - `{:user_kicked, lobby_id, user_id}` - a user was kicked from the lobby
    - `{:lobby_updated, lobby}` - the lobby settings were updated
    - `{:host_changed, lobby_id, new_host_id}` - the host changed (e.g., after host leaves)
  """

  import Ecto.Query, warn: false

  alias Bcrypt
  alias Ecto.Multi
  alias GameServer.Accounts.User
  alias GameServer.Lobbies.Lobby
  alias GameServer.Repo
  alias GameServer.Types

  # PubSub topic names
  @lobbies_topic "lobbies"

  @doc """
  Subscribe to global lobby events (lobby created, updated, deleted).
  """
  @spec subscribe_lobbies() :: :ok | {:error, term()}
  def subscribe_lobbies do
    Phoenix.PubSub.subscribe(GameServer.PubSub, @lobbies_topic)
  end

  @doc """
  Subscribe to a specific lobby's events (membership changes, updates).
  """
  @spec subscribe_lobby(integer()) :: :ok | {:error, term()}
  def subscribe_lobby(lobby_id) do
    Phoenix.PubSub.subscribe(GameServer.PubSub, "lobby:#{lobby_id}")
  end

  @doc """
  Unsubscribe from a specific lobby's events.
  """
  @spec unsubscribe_lobby(integer()) :: :ok
  def unsubscribe_lobby(lobby_id) do
    Phoenix.PubSub.unsubscribe(GameServer.PubSub, "lobby:#{lobby_id}")
  end

  defp broadcast_lobbies(event) do
    Phoenix.PubSub.broadcast(GameServer.PubSub, @lobbies_topic, event)
  end

  defp broadcast_lobby(lobby_id, event) do
    Phoenix.PubSub.broadcast(GameServer.PubSub, "lobby:#{lobby_id}", event)
  end

  @doc """
  List lobbies. Accepts optional search filters.

  ## Filters

    * `:title` - Filter by title (partial match)
    * `:is_passworded` - boolean or string 'true'/'false' (omit for any)
    * `:is_locked` - boolean or string 'true'/'false' (omit for any)
    * `:min_users` - Filter lobbies with max_users >= value
    * `:max_users` - Filter lobbies with max_users <= value
    * `:metadata_key` - Filter by metadata key
    * `:metadata_value` - Filter by metadata value (requires metadata_key)

  ## Options

  See `t:GameServer.Types.lobby_list_opts/0` for available options.
  """
  @spec list_lobbies() :: [Lobby.t()]
  @spec list_lobbies(map()) :: [Lobby.t()]
  @spec list_lobbies(map(), Types.lobby_list_opts()) :: [Lobby.t()]
  def list_lobbies(filters \\ %{}, opts \\ []) do
    q = from(l in Lobby)

    q =
      q
      |> filter_by_title(filters)
      |> filter_by_hidden_false()
      |> filter_by_passworded(filters)
      |> filter_by_locked(filters)
      |> filter_by_min_users(filters)
      |> filter_by_max_users(filters)

    results = paginate(q, opts)

    filter_by_metadata_in_memory(results, filters)
  end

  defp filter_by_hidden_false(q) do
    from l in q, where: l.is_hidden == false
  end

  defp filter_by_passworded(q, filters) do
    case Map.get(filters, :is_passworded) || Map.get(filters, "is_passworded") do
      nil -> q
      v when v in [true, "true", "1"] -> from l in q, where: not is_nil(l.password_hash)
      v when v in [false, "false", "0"] -> from l in q, where: is_nil(l.password_hash)
      _ -> q
    end
  end

  defp filter_by_min_users(q, filters) do
    case Map.get(filters, :min_users) || Map.get(filters, "min_users") do
      nil -> q
      v when is_binary(v) -> from l in q, where: l.max_users >= ^String.to_integer(v)
      v when is_integer(v) -> from l in q, where: l.max_users >= ^v
      _ -> q
    end
  end

  defp filter_by_max_users(q, filters) do
    case Map.get(filters, :max_users) || Map.get(filters, "max_users") do
      nil -> q
      v when is_binary(v) -> from l in q, where: l.max_users <= ^String.to_integer(v)
      v when is_integer(v) -> from l in q, where: l.max_users <= ^v
      _ -> q
    end
  end

  defp filter_by_metadata_in_memory(results, filters) do
    case Map.get(filters, :metadata_key) || Map.get(filters, "metadata_key") do
      nil ->
        results

      key ->
        value = Map.get(filters, :metadata_value) || Map.get(filters, "metadata_value")

        Enum.filter(results, fn l ->
          case Map.get(l.metadata || %{}, key) do
            nil -> false
            _ when is_nil(value) -> true
            v -> String.contains?(to_string(v), to_string(value))
          end
        end)
    end
  end

  @doc "Count lobbies matching filters (excludes hidden ones unless admin list used). If metadata filters are supplied, they will be applied after fetching."
  @spec count_list_lobbies() :: non_neg_integer()
  @spec count_list_lobbies(map()) :: non_neg_integer()
  def count_list_lobbies(filters \\ %{}) do
    q = from(l in Lobby)

    q =
      q
      |> filter_by_title(filters)
      |> filter_by_hidden_false()

    # basic db count
    db_count = Repo.one(from l in q, select: count(l.id)) || 0

    # if metadata filter present, we must apply the in-memory filter to count accurately
    case Map.get(filters, :metadata_key) || Map.get(filters, "metadata_key") do
      nil ->
        db_count

      key ->
        value = Map.get(filters, :metadata_value) || Map.get(filters, "metadata_value")
        results = Repo.all(q)

        Enum.count(results, fn l ->
          case Map.get(l.metadata || %{}, key) do
            nil -> false
            _ when is_nil(value) -> true
            v -> String.contains?(to_string(v), to_string(value))
          end
        end)
    end
  end

  @doc """
  List ALL lobbies including hidden ones. For admin use only.
  Accepts filters: %{
    title: string,
    is_hidden: boolean/string,
    is_locked: boolean/string,
    has_password: boolean/string,
    min_users: integer (filter by max_users >= val),
    max_users: integer (filter by max_users <= val)
  }
  """
  @spec list_all_lobbies() :: [Lobby.t()]
  @spec list_all_lobbies(map()) :: [Lobby.t()]
  @spec list_all_lobbies(map(), Types.pagination_opts()) :: [Lobby.t()]
  def list_all_lobbies(filters \\ %{}, opts \\ []) do
    page = Keyword.get(opts, :page, nil)
    page_size = Keyword.get(opts, :page_size, nil)

    q = from(l in Lobby)

    q = apply_admin_filters(q, filters)

    if page && page_size do
      offset = (page - 1) * page_size
      Repo.all(from l in q, limit: ^page_size, offset: ^offset)
    else
      Repo.all(q)
    end
  end

  @doc """
  Count ALL lobbies matching filters. For admin pagination.
  """
  @spec count_list_all_lobbies() :: non_neg_integer()
  @spec count_list_all_lobbies(map()) :: non_neg_integer()
  def count_list_all_lobbies(filters \\ %{}) do
    q = from(l in Lobby)
    q = apply_admin_filters(q, filters)
    Repo.aggregate(q, :count, :id)
  end

  @doc """
  Returns the count of hostless lobbies.
  """
  @spec count_hostless_lobbies() :: non_neg_integer()
  def count_hostless_lobbies do
    Repo.one(from l in Lobby, where: l.hostless == true, select: count(l.id)) || 0
  end

  @doc """
  Returns the count of hidden lobbies.
  """
  @spec count_hidden_lobbies() :: non_neg_integer()
  def count_hidden_lobbies do
    Repo.one(from l in Lobby, where: l.is_hidden == true, select: count(l.id)) || 0
  end

  @doc """
  Returns the count of locked lobbies.
  """
  @spec count_locked_lobbies() :: non_neg_integer()
  def count_locked_lobbies do
    Repo.one(from l in Lobby, where: l.is_locked == true, select: count(l.id)) || 0
  end

  @doc """
  Returns the count of lobbies with passwords.
  """
  @spec count_passworded_lobbies() :: non_neg_integer()
  def count_passworded_lobbies do
    Repo.one(from l in Lobby, where: not is_nil(l.password_hash), select: count(l.id)) || 0
  end

  defp apply_admin_filters(q, filters) do
    q
    |> filter_by_title(filters)
    |> filter_by_hidden(filters)
    |> filter_by_locked(filters)
    |> filter_by_password(filters)
    |> filter_by_min_users_admin(filters)
    |> filter_by_max_users_admin(filters)
  end

  defp filter_by_title(q, filters) do
    case Map.get(filters, :title) || Map.get(filters, "title") do
      nil ->
        q

      "" ->
        q

      term ->
        ilike_term = "%#{term}%"
        ilike_term_down = String.downcase(ilike_term)
        from l in q, where: fragment("lower(?) LIKE ?", l.title, ^ilike_term_down)
    end
  end

  defp filter_by_hidden(q, filters) do
    case Map.get(filters, :is_hidden) || Map.get(filters, "is_hidden") do
      nil -> q
      "" -> q
      val when val in [true, "true", "1"] -> from l in q, where: l.is_hidden == true
      val when val in [false, "false", "0"] -> from l in q, where: l.is_hidden == false
      _ -> q
    end
  end

  defp filter_by_locked(q, filters) do
    case Map.get(filters, :is_locked) || Map.get(filters, "is_locked") do
      nil -> q
      "" -> q
      val when val in [true, "true", "1"] -> from l in q, where: l.is_locked == true
      val when val in [false, "false", "0"] -> from l in q, where: l.is_locked == false
      _ -> q
    end
  end

  defp filter_by_password(q, filters) do
    case Map.get(filters, :has_password) || Map.get(filters, "has_password") do
      nil -> q
      "" -> q
      val when val in [true, "true", "1"] -> from l in q, where: not is_nil(l.password_hash)
      val when val in [false, "false", "0"] -> from l in q, where: is_nil(l.password_hash)
      _ -> q
    end
  end

  defp filter_by_min_users_admin(q, filters) do
    case Map.get(filters, :min_users) || Map.get(filters, "min_users") do
      nil ->
        q

      "" ->
        q

      val ->
        val_int = if is_binary(val), do: String.to_integer(val), else: val
        from l in q, where: l.max_users >= ^val_int
    end
  end

  defp filter_by_max_users_admin(q, filters) do
    case Map.get(filters, :max_users) || Map.get(filters, "max_users") do
      nil ->
        q

      "" ->
        q

      val ->
        val_int = if is_binary(val), do: String.to_integer(val), else: val
        from l in q, where: l.max_users <= ^val_int
    end
  end

  @doc """
  List lobbies visible to a specific user.
  Includes the user's own lobby even if it's hidden.
  """
  @spec list_lobbies_for_user(User.t() | nil) :: [Lobby.t()]
  @spec list_lobbies_for_user(User.t() | nil, map()) :: [Lobby.t()]
  @spec list_lobbies_for_user(User.t() | nil, map(), Types.lobby_list_opts()) :: [Lobby.t()]
  def list_lobbies_for_user(user, filters \\ %{}, opts \\ [])

  def list_lobbies_for_user(%User{lobby_id: user_lobby_id}, filters, opts) do
    public_lobbies = list_lobbies(filters, opts)

    if is_nil(user_lobby_id) do
      public_lobbies
    else
      # Check if user's lobby is hidden and needs to be included
      user_lobby = Repo.get(Lobby, user_lobby_id)

      if user_lobby && user_lobby.is_hidden &&
           !Enum.any?(public_lobbies, &(&1.id == user_lobby_id)) do
        [user_lobby | public_lobbies]
      else
        public_lobbies
      end
    end
  end

  def list_lobbies_for_user(nil, filters, opts), do: list_lobbies(filters, opts)

  # join behavior for a user -> lobby
  @spec join_lobby(User.t(), Lobby.t() | integer() | String.t()) ::
          {:ok, User.t()} | {:error, term()}
  @spec join_lobby(User.t(), Lobby.t() | integer() | String.t(), map() | keyword()) ::
          {:ok, User.t()} | {:error, term()}
  def join_lobby(user, lobby_arg, opts \\ %{})

  def join_lobby(%User{id: user_id} = _user, %Lobby{} = lobby, opts) do
    if is_nil(lobby.id) do
      case Repo.get_by(Lobby, title: lobby.title) do
        nil ->
          {:error, :invalid_lobby}

        persisted ->
          do_join(user_id, persisted, opts)
      end
    else
      do_join(user_id, lobby, opts)
    end
  end

  def join_lobby(%User{} = user, lobby_id, opts)
      when is_binary(lobby_id) or is_integer(lobby_id) do
    lobby = Repo.get!(Lobby, lobby_id)
    join_lobby(user, lobby, opts)
  end

  def join_lobby(_user, _lobby, _opts), do: {:error, :invalid}

  defp do_join(user_id, lobby, opts) do
    user = Repo.get(GameServer.Accounts.User, user_id)

    if user && user.lobby_id do
      {:error, :already_in_lobby}
    else
      count =
        Repo.one(
          from(u in GameServer.Accounts.User,
            where: u.lobby_id == ^lobby.id,
            select: count(u.id)
          )
        ) || 0

      cond do
        count >= lobby.max_users ->
          {:error, :full}

        lobby.is_locked ->
          {:error, :locked}

        true ->
          run_before_join_and_validate(user, lobby, opts, user_id)
      end
    end
  end

  defp run_before_join_and_validate(user, lobby, opts, user_id) do
    case GameServer.Hooks.internal_call(:before_lobby_join, [user, lobby, opts]) do
      {:ok, _} ->
        password =
          if is_list(opts), do: Keyword.get(opts, :password), else: Map.get(opts, :password)

        validate_and_join(lobby, user_id, password)

      {:error, reason} ->
        {:error, {:hook_rejected, reason}}
    end
  end

  defp validate_and_join(lobby, user_id, password) do
    case {lobby.password_hash, password} do
      {nil, _} ->
        create_membership(%{lobby_id: lobby.id, user_id: user_id})

      {phash, nil} when phash != nil ->
        {:error, :password_required}

      {phash, password} ->
        if Bcrypt.verify_pass(password, phash) do
          create_membership(%{lobby_id: lobby.id, user_id: user_id})
        else
          {:error, :invalid_password}
        end
    end
  end

  @spec get_lobby!(integer() | String.t()) :: Lobby.t()
  def get_lobby!(id), do: Repo.get!(Lobby, id)

  @spec get_lobby(integer() | String.t()) :: Lobby.t() | nil
  def get_lobby(id), do: Repo.get(Lobby, id)

  @doc """
  Gets all users currently in a lobby.

  Returns a list of User structs.

  ## Examples

      iex> get_lobby_members(lobby)
      [%User{}, %User{}]

      iex> get_lobby_members(lobby_id)
      [%User{}]

  """
  @spec get_lobby_members(Lobby.t() | integer() | String.t()) :: [User.t()]
  def get_lobby_members(%Lobby{id: lobby_id}), do: get_lobby_members(lobby_id)

  def get_lobby_members(lobby_id) when is_binary(lobby_id) or is_integer(lobby_id) do
    Repo.all(
      from u in GameServer.Accounts.User,
        where: u.lobby_id == ^lobby_id,
        order_by: [asc: u.inserted_at]
    )
  end

  @doc """
  Creates a new lobby.

  ## Attributes

  See `t:GameServer.Types.lobby_create_attrs/0` for available fields.
  """
  @spec create_lobby() :: {:ok, Lobby.t()} | {:error, Ecto.Changeset.t() | term()}
  @spec create_lobby(Types.lobby_create_attrs()) ::
          {:ok, Lobby.t()} | {:error, Ecto.Changeset.t() | term()}
  def create_lobby(attrs \\ %{}) do
    attrs = maybe_hash_password(attrs)
    # if host_id is provided, prevent a user who is already a member of a lobby
    # from creating an additional lobby
    # ensure title is present and always ensure it is unique in the DB.
    # If the caller provided a title, use it as the base and derive a unique
    # candidate; otherwise fall back to the default base "lobby".
    # Treat keys that are present but blank/nil as "not provided" so we
    # generate a title in those cases.
    title_val = Map.get(attrs, "title") || Map.get(attrs, :title)

    has_title =
      case title_val do
        nil -> false
        v when is_binary(v) -> String.trim(v) != ""
        _ -> true
      end

    attrs =
      if has_title do
        # Caller provided a title — respect it as-is.
        attrs
      else
        # No title provided: generate a unique candidate using default base.
        Map.put(attrs, :title, unique_title_candidate("lobby"))
      end

    case GameServer.Hooks.internal_call(:before_lobby_create, [attrs]) do
      {:ok, attrs} ->
        Multi.new()
        |> Multi.insert(:lobby, Lobby.changeset(%Lobby{}, attrs))
        |> maybe_add_host_membership(attrs)
        |> Repo.transaction()

      {:error, reason} ->
        {:error, {:hook_rejected, reason}}
    end
    |> case do
      {:ok, %{lobby: lobby}} ->
        Task.start(fn -> GameServer.Hooks.internal_call(:after_lobby_create, [lobby]) end)
        broadcast_lobbies({:lobby_created, lobby})
        {:ok, lobby}

      {:error, _op, changeset, _} ->
        {:error, changeset}

      other ->
        other
    end
  end

  defp maybe_add_host_membership(multi, %{"host_id" => host_id}) when host_id != nil do
    multi
    |> Multi.run(:membership, fn repo, %{lobby: lobby} ->
      user = repo.get(GameServer.Accounts.User, host_id)
      changeset = Ecto.Changeset.change(user, %{lobby_id: lobby.id})
      repo.update(changeset)
    end)
  end

  defp maybe_add_host_membership(multi, %{host_id: host_id}) when host_id != nil do
    multi
    |> Multi.run(:membership, fn repo, %{lobby: lobby} ->
      user = repo.get(GameServer.Accounts.User, host_id)
      changeset = Ecto.Changeset.change(user, %{lobby_id: lobby.id})
      repo.update(changeset)
    end)
  end

  defp maybe_add_host_membership(multi, _), do: multi

  defp unique_title_candidate(base) when is_binary(base) do
    # Try the base first; if it exists in DB, append a short unique suffix.
    suffix = :erlang.unique_integer([:positive]) |> Integer.to_string()
    candidate = "#{base}-#{suffix}"

    if Repo.get_by(Lobby, title: candidate) == nil do
      candidate
    else
      unique_title_candidate(candidate)
    end
  end

  @doc """
  Updates an existing lobby.

  ## Attributes

  See `t:GameServer.Types.lobby_update_attrs/0` for available fields.
  """
  @spec update_lobby(Lobby.t(), Types.lobby_update_attrs()) ::
          {:ok, Lobby.t()} | {:error, Ecto.Changeset.t() | term()}
  def update_lobby(%Lobby{} = lobby, attrs) do
    case GameServer.Hooks.internal_call(:before_lobby_update, [lobby, attrs]) do
      {:ok, returned} ->
        # prefer hook-returned attrs if it's a plain map; if the hook
        # incorrectly returns something else (eg. a struct) fall back to
        # the original params we received so updates from the form are not lost.
        attrs_to_use =
          if is_map(returned) and not is_struct(returned) do
            returned
          else
            require Logger

            Logger.warning(
              "Hooks.before_lobby_update returned unexpected value; using original params"
            )

            attrs
          end

        result =
          lobby
          |> Lobby.changeset(attrs_to_use)
          |> Repo.update()

        case result do
          {:ok, updated} ->
            Task.start(fn -> GameServer.Hooks.internal_call(:after_lobby_update, [updated]) end)

            # broadcast updates so any UI/channel subscribers get the change
            broadcast_lobby(updated.id, {:lobby_updated, updated})
            broadcast_lobbies({:lobby_updated, updated})
            {:ok, updated}

          other ->
            other
        end

      {:error, reason} ->
        {:error, {:hook_rejected, reason}}
    end
  end

  @spec delete_lobby(Lobby.t()) :: {:ok, Lobby.t()} | {:error, Ecto.Changeset.t() | term()}
  def delete_lobby(%Lobby{} = lobby) do
    case GameServer.Hooks.internal_call(:before_lobby_delete, [lobby]) do
      {:ok, _} ->
        case Repo.delete(lobby) do
          {:ok, deleted} ->
            Task.start(fn -> GameServer.Hooks.internal_call(:after_lobby_delete, [deleted]) end)
            broadcast_lobbies({:lobby_deleted, deleted.id})
            {:ok, deleted}

          other ->
            other
        end

      {:error, reason} ->
        {:error, {:hook_rejected, reason}}
    end
  end

  @spec change_lobby(Lobby.t()) :: Ecto.Changeset.t()
  @spec change_lobby(Lobby.t(), map()) :: Ecto.Changeset.t()
  def change_lobby(%Lobby{} = lobby, attrs \\ %{}) do
    Lobby.changeset(lobby, attrs)
  end

  ## Membership helpers (minimal for now)

  @spec create_membership(%{lobby_id: integer(), user_id: integer()}) ::
          {:ok, User.t()} | {:error, :not_found | Ecto.Changeset.t() | term()}
  def create_membership(%{lobby_id: lobby_id, user_id: user_id} = _attrs) do
    case Repo.get(GameServer.Accounts.User, user_id) do
      nil ->
        {:error, :not_found}

      user ->
        result =
          user
          |> Ecto.Changeset.change(%{lobby_id: lobby_id})
          |> Repo.update()

        case result do
          {:ok, updated_user} ->
            broadcast_lobby(lobby_id, {:user_joined, lobby_id, user_id})
            broadcast_lobbies({:lobby_membership_changed, lobby_id})

            # Fetch the lobby before starting the background task so the task
            # does not need to check out a DB connection from the sandbox.
            # Using Repo.get/2 avoids raising if the lobby disappears (tests
            # shouldn't crash because of a background DB lookup).
            lobby = Repo.get(Lobby, lobby_id)

            Task.start(fn ->
              GameServer.Hooks.internal_call(:after_lobby_join, [updated_user, lobby])
            end)

            {:ok, updated_user}

          _ ->
            result
        end
    end
  end

  @spec delete_membership(User.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def delete_membership(%GameServer.Accounts.User{} = user) do
    user
    |> Ecto.Changeset.change(%{lobby_id: nil})
    |> Repo.update()
  end

  @spec leave_lobby(User.t()) :: {:ok, term()} | {:error, term()}
  def leave_lobby(%User{id: user_id}) do
    case Repo.get(GameServer.Accounts.User, user_id) do
      nil ->
        {:error, :not_in_lobby}

      %GameServer.Accounts.User{lobby_id: nil} ->
        {:error, :not_in_lobby}

      %GameServer.Accounts.User{} = membership ->
        lobby = Repo.get!(Lobby, membership.lobby_id)
        lobby_id = lobby.id

        case GameServer.Hooks.internal_call(:before_lobby_leave, [membership, lobby]) do
          {:ok, _} ->
            result =
              Repo.transaction(fn ->
                Repo.update!(Ecto.Changeset.change(membership, %{lobby_id: nil}))
                handle_host_transfer(lobby, user_id, membership.id)
              end)

            broadcast_leave_result(result, lobby_id, user_id)

          {:error, reason} ->
            {:error, {:hook_rejected, reason}}
        end
    end
  end

  defp handle_host_transfer(lobby, user_id, membership_id) do
    # if user was host, transfer host or delete lobby if empty
    if lobby.host_id == user_id and not lobby.hostless do
      remaining =
        Repo.all(
          from u in GameServer.Accounts.User,
            where: u.lobby_id == ^lobby.id and u.id != ^membership_id,
            order_by: u.inserted_at,
            limit: 1
        )

      case remaining do
        [%GameServer.Accounts.User{id: new_host_id} | _] ->
          Repo.update!(Ecto.Changeset.change(lobby, %{host_id: new_host_id}))
          {:host_changed, new_host_id}

        [] ->
          # no members left - delete lobby
          Repo.delete!(lobby)
          :lobby_deleted
      end
    else
      :ok
    end
  end

  defp broadcast_leave_result(result, lobby_id, user_id) do
    case result do
      {:ok, :lobby_deleted} ->
        broadcast_lobbies({:lobby_deleted, lobby_id})
        result

      {:ok, {:host_changed, new_host_id}} ->
        broadcast_lobby(lobby_id, {:user_left, lobby_id, user_id})
        broadcast_lobby(lobby_id, {:host_changed, lobby_id, new_host_id})
        broadcast_lobbies({:lobby_membership_changed, lobby_id})
        result

      {:ok, _} ->
        broadcast_lobby(lobby_id, {:user_left, lobby_id, user_id})
        broadcast_lobbies({:lobby_membership_changed, lobby_id})
        result

      _ ->
        result
    end
  end

  @doc """
  Kick a user from a lobby. Only the host can kick users.
  Returns {:ok, user} on success, {:error, reason} on failure.
  """
  @spec kick_user(User.t(), Lobby.t(), User.t()) :: {:ok, User.t()} | {:error, term()}
  def kick_user(%User{id: host_id}, %Lobby{id: lobby_id}, %User{id: target_id}) do
    lobby = Repo.get!(Lobby, lobby_id)

    cond do
      lobby.host_id != host_id and not lobby.hostless ->
        {:error, :not_host}

      target_id == host_id ->
        {:error, :cannot_kick_self}

      true ->
        case Repo.get(GameServer.Accounts.User, target_id) do
          nil ->
            {:error, :not_found}

          %GameServer.Accounts.User{lobby_id: ^lobby_id} = membership ->
            do_kick_membership(membership, host_id, lobby)

          _ ->
            {:error, :not_in_lobby}
        end
    end
  end

  def kick_user(_host, _lobby, _target), do: {:error, :invalid}

  defp do_kick_membership(membership, host_id, lobby) do
    case GameServer.Hooks.internal_call(:before_user_kicked, [
           %GameServer.Accounts.User{id: host_id},
           membership,
           lobby
         ]) do
      {:ok, _} ->
        result = Repo.update(Ecto.Changeset.change(membership, %{lobby_id: nil}))

        case result do
          {:ok, _} ->
            Task.start(fn ->
              GameServer.Hooks.internal_call(:after_user_kicked, [
                %GameServer.Accounts.User{id: host_id},
                membership,
                lobby
              ])
            end)

            broadcast_lobby(lobby.id, {:user_kicked, lobby.id, membership.id})
            broadcast_lobbies({:lobby_membership_changed, lobby.id})
            result

          _ ->
            result
        end

      {:error, reason} ->
        {:error, {:hook_rejected, reason}}
    end
  end

  @doc """
  Check if a user can edit a lobby (is host or lobby is hostless).
  """
  @spec can_edit_lobby?(User.t() | nil, Lobby.t() | nil) :: boolean()
  def can_edit_lobby?(%User{id: user_id}, %Lobby{} = lobby) do
    lobby.host_id == user_id or lobby.hostless
  end

  def can_edit_lobby?(nil, _lobby), do: false
  def can_edit_lobby?(_user, nil), do: false

  @doc """
  Check if a user can view a lobby's details.
  Users can view any lobby they can see in the list.
  """
  @spec can_view_lobby?(User.t() | nil, Lobby.t() | nil) :: boolean()
  def can_view_lobby?(%User{} = _user, %Lobby{} = _lobby), do: true
  def can_view_lobby?(nil, %Lobby{is_hidden: false}), do: true
  def can_view_lobby?(nil, _lobby), do: false

  @spec update_lobby_by_host(User.t(), Lobby.t(), Types.lobby_update_attrs()) ::
          {:ok, Lobby.t()} | {:error, :not_host | :too_small | Ecto.Changeset.t() | term()}
  def update_lobby_by_host(%User{id: host_id}, %Lobby{} = lobby, attrs) do
    if lobby.host_id == host_id or lobby.hostless do
      attrs = maybe_hash_password(attrs)
      new_max = Map.get(attrs, "max_users") || Map.get(attrs, :max_users)

      if is_nil(new_max) do
        broadcast_update_result(update_lobby(lobby, attrs), lobby.id)
      else
        validate_and_update_max_users(lobby, attrs, new_max)
      end
    else
      {:error, :not_host}
    end
  end

  defp validate_and_update_max_users(lobby, attrs, new_max) do
    # ensure new_max is an integer
    new_max = if is_binary(new_max), do: String.to_integer(new_max), else: new_max

    current_count =
      Repo.one(
        from(u in GameServer.Accounts.User,
          where: u.lobby_id == ^lobby.id,
          select: count(u.id)
        )
      ) || 0

    if new_max < current_count do
      {:error, :too_small}
    else
      broadcast_update_result(update_lobby(lobby, attrs), lobby.id)
    end
  end

  defp broadcast_update_result(result, lobby_id) do
    case result do
      {:ok, updated_lobby} ->
        broadcast_lobby(lobby_id, {:lobby_updated, updated_lobby})
        broadcast_lobbies({:lobby_updated, updated_lobby})
        result

      _ ->
        result
    end
  end

  defp maybe_hash_password(attrs) when is_map(attrs) do
    cond do
      Map.has_key?(attrs, "password") and attrs["password"] != nil ->
        Map.put(attrs, "password_hash", Bcrypt.hash_pwd_salt(attrs["password"]))
        |> Map.delete("password")

      Map.has_key?(attrs, :password) and attrs[:password] != nil ->
        Map.put(attrs, :password_hash, Bcrypt.hash_pwd_salt(attrs[:password]))
        |> Map.delete(:password)

      true ->
        attrs
    end
  end

  defp maybe_hash_password(other), do: other

  @spec list_memberships_for_lobby(integer() | String.t()) :: [User.t()]
  def list_memberships_for_lobby(lobby_id) do
    from(u in GameServer.Accounts.User, where: u.lobby_id == ^lobby_id)
    |> Repo.all()
  end

  @doc """
  Attempt to find an open lobby matching the given criteria and join it, or
  create a new lobby if none matches.

  Signature: quick_join(user, title \\ nil, max_users \\ nil, metadata \\ %{})

  - If the user is already in a lobby returns {:error, :already_in_lobby}
  - On successful join or creation returns {:ok, lobby}
  - Propagates errors from join or create flows
  """
  @spec quick_join(User.t()) ::
          {:ok, Lobby.t()} | {:error, :already_in_lobby | Ecto.Changeset.t() | term()}
  @spec quick_join(User.t(), String.t() | nil) ::
          {:ok, Lobby.t()} | {:error, :already_in_lobby | Ecto.Changeset.t() | term()}
  @spec quick_join(User.t(), String.t() | nil, integer() | nil) ::
          {:ok, Lobby.t()} | {:error, :already_in_lobby | Ecto.Changeset.t() | term()}
  @spec quick_join(User.t(), String.t() | nil, integer() | nil, map()) ::
          {:ok, Lobby.t()} | {:error, :already_in_lobby | Ecto.Changeset.t() | term()}
  def quick_join(%User{id: _user_id} = user, title \\ nil, max_users \\ nil, metadata \\ %{}) do
    # reload user in case their membership changed since the caller was loaded
    user = Repo.get(GameServer.Accounts.User, user.id)

    if user && user.lobby_id do
      {:error, :already_in_lobby}
    else
      # base query: only consider visible/unlocked and non-passworded lobbies
      # quick_join prioritizes public, passwordless matches to avoid prompting for password
      q =
        from(l in Lobby,
          where: l.is_hidden == false and l.is_locked == false and is_nil(l.password_hash)
        )

      q =
        if is_nil(max_users) do
          q
        else
          from(l in q, where: l.max_users == ^max_users)
        end

      # order candidates deterministically by insertion time and limit how many we try
      max_candidates = 5

      candidates =
        Repo.all(from(l in q, order_by: [asc: l.inserted_at], limit: ^max_candidates))

      # Try candidates in order — if a candidate fails due to full, move to next.
      tried =
        Enum.reduce_while(candidates, {:none, []}, fn lobby, _acc ->
          if matches_metadata?(lobby, metadata) do
            attempt_quick_join(user, lobby)
          else
            {:cont, {:none, []}}
          end
        end)

      case tried do
        {:ok, %Lobby{} = lobby} ->
          {:ok, lobby}

        {:error, _} = err ->
          err

        {:none, _} ->
          # no match found -> create a new lobby with the provided params
          attrs = %{}
          attrs = if title, do: Map.put(attrs, :title, title), else: attrs
          attrs = if max_users, do: Map.put(attrs, :max_users, max_users), else: attrs

          attrs =
            if metadata && metadata != %{}, do: Map.put(attrs, :metadata, metadata), else: attrs

          attrs = Map.put(attrs, :host_id, user.id)

          case create_lobby(attrs) do
            {:ok, lobby} -> {:ok, lobby}
            other -> other
          end
      end
    end
  end

  defp paginate(q, opts) do
    page = Keyword.get(opts, :page, nil)
    page_size = Keyword.get(opts, :page_size, nil)

    if page && page_size do
      offset = (page - 1) * page_size
      Repo.all(from l in q, limit: ^page_size, offset: ^offset)
    else
      Repo.all(q)
    end
  end

  defp matches_metadata?(lobby, metadata) do
    Enum.all?(Map.to_list(metadata || %{}), fn
      {_k, v} when is_nil(v) ->
        true

      {k, v} ->
        case Map.get(lobby.metadata || %{}, k) do
          nil -> false
          existing -> String.contains?(to_string(existing), to_string(v))
        end
    end)
  end

  defp attempt_quick_join(user, lobby) do
    case do_join(user.id, lobby, %{}) do
      {:ok, _} -> {:halt, {:ok, lobby}}
      {:error, :full} -> {:cont, {:none, []}}
      other -> {:halt, other}
    end
  end
end
