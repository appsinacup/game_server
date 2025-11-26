defmodule GameServer.Lobbies do
  @moduledoc """
  Context module for lobby management: creating, updating, listing and searching lobbies.

  This module contains the core domain operations; more advanced membership and
  permission logic will be added in follow-up tasks.

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

  # PubSub topic names
  @lobbies_topic "lobbies"

  @doc """
  Subscribe to global lobby events (lobby created, updated, deleted).
  """
  def subscribe_lobbies do
    Phoenix.PubSub.subscribe(GameServer.PubSub, @lobbies_topic)
  end

  @doc """
  Subscribe to a specific lobby's events (membership changes, updates).
  """
  def subscribe_lobby(lobby_id) do
    Phoenix.PubSub.subscribe(GameServer.PubSub, "lobby:#{lobby_id}")
  end

  @doc """
  Unsubscribe from a specific lobby's events.
  """
  def unsubscribe_lobby(lobby_id) do
    Phoenix.PubSub.unsubscribe(GameServer.PubSub, "lobby:#{lobby_id}")
  end

  defp broadcast_lobbies(event) do
    Phoenix.PubSub.broadcast(GameServer.PubSub, @lobbies_topic, event)
  end

  defp broadcast_lobby(lobby_id, event) do
    Phoenix.PubSub.broadcast(GameServer.PubSub, "lobby:#{lobby_id}", event)
  end

  @doc "List lobbies. Accepts optional search filters: %{q: string}"
  def list_lobbies(filters \\ %{}, opts \\ []) do
    q = from(l in Lobby)

    q =
      case Map.get(filters, :q) || Map.get(filters, "q") do
        nil ->
          q

        term ->
          ilike_term = "%#{term}%"
          ilike_term_down = String.downcase(ilike_term)

          # Use fragment + lower(...) to support both Postgres and SQLite
          from l in q,
            where:
              fragment("lower(?) LIKE ?", l.name, ^ilike_term_down) or
                fragment("lower(?) LIKE ?", l.title, ^ilike_term_down)
      end

    # never include hidden lobbies in list results
    q = from l in q, where: l.is_hidden == false

    page = Keyword.get(opts, :page, nil)
    page_size = Keyword.get(opts, :page_size, nil)

    results =
      if page && page_size do
        offset = (page - 1) * page_size
        Repo.all(from l in q, limit: ^page_size, offset: ^offset)
      else
        Repo.all(q)
      end

    # optional metadata filtering in-memory (DB JSON search varies by adapter).
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
  def count_list_lobbies(filters \\ %{}) do
    q = from(l in Lobby)

    q =
      case Map.get(filters, :q) || Map.get(filters, "q") do
        nil ->
          q

        term ->
          ilike_term_down = String.downcase("%#{term}%")

          from l in q,
            where:
              fragment("lower(?) LIKE ?", l.name, ^ilike_term_down) or
                fragment("lower(?) LIKE ?", l.title, ^ilike_term_down)
      end

    q = from l in q, where: l.is_hidden == false

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
  """
  def list_all_lobbies(opts \\ []) do
    page = Keyword.get(opts, :page, nil)
    page_size = Keyword.get(opts, :page_size, nil)

    q = from(l in Lobby)

    if page && page_size do
      offset = (page - 1) * page_size
      Repo.all(from l in q, limit: ^page_size, offset: ^offset)
    else
      Repo.all(q)
    end
  end

  @doc """
  List lobbies visible to a specific user.
  Includes the user's own lobby even if it's hidden.
  """
  def list_lobbies_for_user(user, filters \\ %{}, opts \\ [])

  def list_lobbies_for_user(%User{lobby_id: user_lobby_id}, filters, opts) do
    public_lobbies = list_lobbies(filters, opts)

    cond do
      # If user is not in a lobby, return public lobbies
      is_nil(user_lobby_id) ->
        public_lobbies

      # Check if user's lobby is hidden and needs to be included
      true ->
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
  def join_lobby(user, lobby_arg, opts \\ %{})

  def join_lobby(%User{id: user_id} = _user, %Lobby{} = lobby, opts) do
    if is_nil(lobby.id) do
      case Repo.get_by(Lobby, name: lobby.name) do
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

    cond do
      user && user.lobby_id ->
        {:error, :already_in_lobby}

      true ->
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
            password =
              if is_list(opts), do: Keyword.get(opts, :password), else: Map.get(opts, :password)

            validate_and_join(lobby, user_id, password)
        end
    end
  end

  defp validate_and_join(lobby, user_id, password) do
    case {lobby.password_hash, password} do
      {nil, _} ->
        create_membership(%{lobby_id: lobby.id, user_id: user_id})

      {phash, nil} when not is_nil(phash) ->
        {:error, :password_required}

      {phash, password} ->
        if Bcrypt.verify_pass(password, phash) do
          create_membership(%{lobby_id: lobby.id, user_id: user_id})
        else
          {:error, :invalid_password}
        end
    end
  end

  def get_lobby!(id), do: Repo.get!(Lobby, id)

  def get_lobby(id), do: Repo.get(Lobby, id)

  def create_lobby(attrs \\ %{}) do
    attrs = maybe_hash_password(attrs)
    # if host_id is provided, prevent a user who is already a member of a lobby
    # from creating an additional lobby
    host_id = Map.get(attrs, "host_id") || Map.get(attrs, :host_id)

    # Check if host is already in a lobby and return early if so
    already_in_lobby =
      if host_id do
        case Repo.get(GameServer.Accounts.User, host_id) do
          %GameServer.Accounts.User{lobby_id: lobby_id} when not is_nil(lobby_id) -> true
          _ -> false
        end
      else
        false
      end

    if already_in_lobby do
      {:error, :already_in_lobby}
    else
      # if no name was provided, generate a unique slug from the title
      has_name = Map.has_key?(attrs, "name") || Map.has_key?(attrs, :name)

      attrs =
        if has_name do
          attrs
        else
          title = Map.get(attrs, "title") || Map.get(attrs, :title) || "lobby"
          base = slugify(title)

          unique_name =
            Stream.iterate(0, &(&1 + 1))
            |> Stream.map(fn
              0 -> base
              n -> base <> "-" <> Integer.to_string(n)
            end)
            |> Enum.find(fn candidate -> Repo.get_by(Lobby, name: candidate) == nil end)

          Map.put(attrs, "name", unique_name)
        end

      Multi.new()
      |> Multi.insert(:lobby, Lobby.changeset(%Lobby{}, attrs))
      |> maybe_add_host_membership(attrs)
      |> Repo.transaction()
      |> case do
        {:ok, %{lobby: lobby}} ->
          broadcast_lobbies({:lobby_created, lobby})
          {:ok, lobby}

        {:error, _op, changeset, _} ->
          {:error, changeset}

        other ->
          other
      end
    end
  end

  defp maybe_add_host_membership(multi, %{"host_id" => host_id}) when not is_nil(host_id) do
    multi
    |> Multi.run(:membership, fn repo, %{lobby: lobby} ->
      user = repo.get(GameServer.Accounts.User, host_id)
      changeset = Ecto.Changeset.change(user, %{lobby_id: lobby.id})
      repo.update(changeset)
    end)
  end

  defp maybe_add_host_membership(multi, %{host_id: host_id}) when not is_nil(host_id) do
    multi
    |> Multi.run(:membership, fn repo, %{lobby: lobby} ->
      user = repo.get(GameServer.Accounts.User, host_id)
      changeset = Ecto.Changeset.change(user, %{lobby_id: lobby.id})
      repo.update(changeset)
    end)
  end

  defp maybe_add_host_membership(multi, _), do: multi

  defp slugify(title) when is_binary(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\-\s]/u, "")
    |> String.replace(~r/\s+/u, "-")
    |> String.slice(0, 80)
  end

  defp slugify(_), do: "lobby"

  def update_lobby(%Lobby{} = lobby, attrs) do
    result =
      lobby
      |> Lobby.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated} ->
        # broadcast updates so any UI/channel subscribers get the change
        broadcast_lobby(updated.id, {:lobby_updated, updated})
        broadcast_lobbies({:lobby_updated, updated})
        {:ok, updated}

      other ->
        other
    end
  end

  def delete_lobby(%Lobby{} = lobby) do
    case Repo.delete(lobby) do
      {:ok, deleted} ->
        broadcast_lobbies({:lobby_deleted, deleted.id})
        {:ok, deleted}

      other ->
        other
    end
  end

  def change_lobby(%Lobby{} = lobby, attrs \\ %{}) do
    Lobby.changeset(lobby, attrs)
  end

  ## Membership helpers (minimal for now)

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
          {:ok, _user} ->
            broadcast_lobby(lobby_id, {:user_joined, lobby_id, user_id})
            broadcast_lobbies({:lobby_membership_changed, lobby_id})
            result

          _ ->
            result
        end
    end
  end

  def delete_membership(%GameServer.Accounts.User{} = user) do
    user
    |> Ecto.Changeset.change(%{lobby_id: nil})
    |> Repo.update()
  end

  def leave_lobby(%User{id: user_id}) do
    case Repo.get(GameServer.Accounts.User, user_id) do
      nil ->
        {:error, :not_in_lobby}

      %GameServer.Accounts.User{lobby_id: nil} ->
        {:error, :not_in_lobby}

      %GameServer.Accounts.User{} = membership ->
        lobby = Repo.get!(Lobby, membership.lobby_id)
        lobby_id = lobby.id

        result =
          Repo.transaction(fn ->
            Repo.update!(Ecto.Changeset.change(membership, %{lobby_id: nil}))
            handle_host_transfer(lobby, user_id, membership.id)
          end)

        broadcast_leave_result(result, lobby_id, user_id)
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
            result = Repo.update(Ecto.Changeset.change(membership, %{lobby_id: nil}))

            case result do
              {:ok, _} ->
                broadcast_lobby(lobby_id, {:user_kicked, lobby_id, target_id})
                broadcast_lobbies({:lobby_membership_changed, lobby_id})
                result

              _ ->
                result
            end

          _ ->
            {:error, :not_in_lobby}
        end
    end
  end

  def kick_user(_host, _lobby, _target), do: {:error, :invalid}

  @doc """
  Check if a user can edit a lobby (is host or lobby is hostless).
  """
  def can_edit_lobby?(%User{id: user_id}, %Lobby{} = lobby) do
    lobby.host_id == user_id or lobby.hostless
  end

  def can_edit_lobby?(nil, _lobby), do: false
  def can_edit_lobby?(_user, nil), do: false

  @doc """
  Check if a user can view a lobby's details.
  Users can view any lobby they can see in the list.
  """
  def can_view_lobby?(%User{} = _user, %Lobby{} = _lobby), do: true
  def can_view_lobby?(nil, %Lobby{is_hidden: false}), do: true
  def can_view_lobby?(nil, _lobby), do: false

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
      Map.has_key?(attrs, "password") and not is_nil(attrs["password"]) ->
        Map.put(attrs, "password_hash", Bcrypt.hash_pwd_salt(attrs["password"]))
        |> Map.delete("password")

      Map.has_key?(attrs, :password) and not is_nil(attrs[:password]) ->
        Map.put(attrs, :password_hash, Bcrypt.hash_pwd_salt(attrs[:password]))
        |> Map.delete(:password)

      true ->
        attrs
    end
  end

  defp maybe_hash_password(other), do: other

  def list_memberships_for_lobby(lobby_id) do
    from(u in GameServer.Accounts.User, where: u.lobby_id == ^lobby_id)
    |> Repo.all()
  end
end
