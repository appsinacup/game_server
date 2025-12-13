defmodule GameServer.Lobbies do
  @moduledoc ~S"""
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
  

  **Note:** This is an SDK stub. Calling these functions will raise an error.
  The actual implementation runs on the GameServer.
  """

  @doc ~S"""
    Check if a user can edit a lobby (is host or lobby is hostless).
    
  """
  def can_edit_lobby?(_user, _lobby) do
    raise "GameServer.Lobbies.can_edit_lobby?/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Check if a user can view a lobby's details.
    Users can view any lobby they can see in the list.
    
  """
  def can_view_lobby?(_user, _lobby) do
    raise "GameServer.Lobbies.can_view_lobby?/2 is a stub - only available at runtime on GameServer"
  end


  @doc false
  def change_lobby(_lobby) do
    raise "GameServer.Lobbies.change_lobby/1 is a stub - only available at runtime on GameServer"
  end


  @doc false
  def change_lobby(_lobby, _attrs) do
    raise "GameServer.Lobbies.change_lobby/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Returns the count of hidden lobbies.
    
  """
  @spec count_hidden_lobbies() :: non_neg_integer()
  def count_hidden_lobbies() do
    raise "GameServer.Lobbies.count_hidden_lobbies/0 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Returns the count of hostless lobbies.
    
  """
  @spec count_hostless_lobbies() :: non_neg_integer()
  def count_hostless_lobbies() do
    raise "GameServer.Lobbies.count_hostless_lobbies/0 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Count ALL lobbies matching filters. For admin pagination.
    
  """
  def count_list_all_lobbies() do
    raise "GameServer.Lobbies.count_list_all_lobbies/0 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Count ALL lobbies matching filters. For admin pagination.
    
  """
  def count_list_all_lobbies(_filters) do
    raise "GameServer.Lobbies.count_list_all_lobbies/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Count lobbies matching filters (excludes hidden ones unless admin list used). If metadata filters are supplied, they will be applied after fetching.
  """
  def count_list_lobbies() do
    raise "GameServer.Lobbies.count_list_lobbies/0 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Count lobbies matching filters (excludes hidden ones unless admin list used). If metadata filters are supplied, they will be applied after fetching.
  """
  def count_list_lobbies(_filters) do
    raise "GameServer.Lobbies.count_list_lobbies/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Returns the count of locked lobbies.
    
  """
  @spec count_locked_lobbies() :: non_neg_integer()
  def count_locked_lobbies() do
    raise "GameServer.Lobbies.count_locked_lobbies/0 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Returns the count of lobbies with passwords.
    
  """
  @spec count_passworded_lobbies() :: non_neg_integer()
  def count_passworded_lobbies() do
    raise "GameServer.Lobbies.count_passworded_lobbies/0 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Creates a new lobby.
    
    ## Attributes
    
    See `t:GameServer.Types.lobby_create_attrs/0` for available fields.
    
  """
  def create_lobby() do
    raise "GameServer.Lobbies.create_lobby/0 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Creates a new lobby.
    
    ## Attributes
    
    See `t:GameServer.Types.lobby_create_attrs/0` for available fields.
    
  """
  @spec create_lobby(GameServer.Types.lobby_create_attrs()) ::
  {:ok, GameServer.Lobbies.Lobby.t()} | {:error, Ecto.Changeset.t() | term()}
  def create_lobby(_attrs) do
    raise "GameServer.Lobbies.create_lobby/1 is a stub - only available at runtime on GameServer"
  end


  @doc false
  def create_membership(_attrs) do
    raise "GameServer.Lobbies.create_membership/1 is a stub - only available at runtime on GameServer"
  end


  @doc false
  @spec delete_lobby(GameServer.Lobbies.Lobby.t()) ::
  {:ok, GameServer.Lobbies.Lobby.t()} | {:error, Ecto.Changeset.t() | term()}
  def delete_lobby(_lobby) do
    raise "GameServer.Lobbies.delete_lobby/1 is a stub - only available at runtime on GameServer"
  end


  @doc false
  def delete_membership(_user) do
    raise "GameServer.Lobbies.delete_membership/1 is a stub - only available at runtime on GameServer"
  end


  @doc false
  @spec get_lobby(integer() | String.t()) :: GameServer.Lobbies.Lobby.t() | nil
  def get_lobby(_id) do
    raise "GameServer.Lobbies.get_lobby/1 is a stub - only available at runtime on GameServer"
  end


  @doc false
  @spec get_lobby!(integer() | String.t()) :: GameServer.Lobbies.Lobby.t()
  def get_lobby!(_id) do
    raise "GameServer.Lobbies.get_lobby!/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Gets all users currently in a lobby.
    
    Returns a list of User structs.
    
    ## Examples
    
        iex> get_lobby_members(lobby)
        [%User{}, %User{}]
    
        iex> get_lobby_members(lobby_id)
        [%User{}]
    
    
  """
  @spec get_lobby_members(GameServer.Lobbies.Lobby.t() | integer() | String.t()) :: [
  GameServer.Accounts.User.t()
]
  def get_lobby_members(_lobby_id) do
    raise "GameServer.Lobbies.get_lobby_members/1 is a stub - only available at runtime on GameServer"
  end


  @doc false
  def join_lobby(_user, _lobby) do
    raise "GameServer.Lobbies.join_lobby/2 is a stub - only available at runtime on GameServer"
  end


  @doc false
  @spec join_lobby(
  GameServer.Accounts.User.t(),
  GameServer.Lobbies.Lobby.t() | integer() | String.t(),
  map() | keyword()
) :: {:ok, GameServer.Accounts.User.t()} | {:error, term()}
  def join_lobby(_user, _lobby_arg, _opts) do
    raise "GameServer.Lobbies.join_lobby/3 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Kick a user from a lobby. Only the host can kick users.
    Returns {:ok, user} on success, {:error, reason} on failure.
    
  """
  @spec kick_user(
  GameServer.Accounts.User.t(),
  GameServer.Lobbies.Lobby.t(),
  GameServer.Accounts.User.t()
) :: {:ok, GameServer.Accounts.User.t()} | {:error, term()}
  def kick_user(_host, _lobby, _target) do
    raise "GameServer.Lobbies.kick_user/3 is a stub - only available at runtime on GameServer"
  end


  @doc false
  @spec leave_lobby(GameServer.Accounts.User.t()) :: {:ok, term()} | {:error, term()}
  def leave_lobby(_user) do
    raise "GameServer.Lobbies.leave_lobby/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
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
  def list_all_lobbies() do
    raise "GameServer.Lobbies.list_all_lobbies/0 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
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
  def list_all_lobbies(_filters) do
    raise "GameServer.Lobbies.list_all_lobbies/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
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
  def list_all_lobbies(_filters, _opts) do
    raise "GameServer.Lobbies.list_all_lobbies/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
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
  def list_lobbies() do
    raise "GameServer.Lobbies.list_lobbies/0 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
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
  def list_lobbies(_filters) do
    raise "GameServer.Lobbies.list_lobbies/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
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
  @spec list_lobbies(map(), GameServer.Types.lobby_list_opts()) :: [GameServer.Lobbies.Lobby.t()]
  def list_lobbies(_filters, _opts) do
    raise "GameServer.Lobbies.list_lobbies/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    List lobbies visible to a specific user.
    Includes the user's own lobby even if it's hidden.
    
  """
  def list_lobbies_for_user(_user) do
    raise "GameServer.Lobbies.list_lobbies_for_user/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    List lobbies visible to a specific user.
    Includes the user's own lobby even if it's hidden.
    
  """
  def list_lobbies_for_user(_user, _filters) do
    raise "GameServer.Lobbies.list_lobbies_for_user/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    List lobbies visible to a specific user.
    Includes the user's own lobby even if it's hidden.
    
  """
  def list_lobbies_for_user(_user, _filters, _opts) do
    raise "GameServer.Lobbies.list_lobbies_for_user/3 is a stub - only available at runtime on GameServer"
  end


  @doc false
  def list_memberships_for_lobby(_lobby_id) do
    raise "GameServer.Lobbies.list_memberships_for_lobby/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Attempt to find an open lobby matching the given criteria and join it, or
    create a new lobby if none matches.
    
    Signature: quick_join(user, title \ nil, max_users \ nil, metadata \ %{})
    
    - If the user is already in a lobby returns {:error, :already_in_lobby}
    - On successful join or creation returns {:ok, lobby}
    - Propagates errors from join or create flows
    
  """
  def quick_join(_user) do
    raise "GameServer.Lobbies.quick_join/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Attempt to find an open lobby matching the given criteria and join it, or
    create a new lobby if none matches.
    
    Signature: quick_join(user, title \ nil, max_users \ nil, metadata \ %{})
    
    - If the user is already in a lobby returns {:error, :already_in_lobby}
    - On successful join or creation returns {:ok, lobby}
    - Propagates errors from join or create flows
    
  """
  def quick_join(_user, _title) do
    raise "GameServer.Lobbies.quick_join/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Attempt to find an open lobby matching the given criteria and join it, or
    create a new lobby if none matches.
    
    Signature: quick_join(user, title \ nil, max_users \ nil, metadata \ %{})
    
    - If the user is already in a lobby returns {:error, :already_in_lobby}
    - On successful join or creation returns {:ok, lobby}
    - Propagates errors from join or create flows
    
  """
  def quick_join(_user, _title, _max_users) do
    raise "GameServer.Lobbies.quick_join/3 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Attempt to find an open lobby matching the given criteria and join it, or
    create a new lobby if none matches.
    
    Signature: quick_join(user, title \ nil, max_users \ nil, metadata \ %{})
    
    - If the user is already in a lobby returns {:error, :already_in_lobby}
    - On successful join or creation returns {:ok, lobby}
    - Propagates errors from join or create flows
    
  """
  def quick_join(_user, _title, _max_users, _metadata) do
    raise "GameServer.Lobbies.quick_join/4 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Subscribe to global lobby events (lobby created, updated, deleted).
    
  """
  @spec subscribe_lobbies() :: :ok | {:error, term()}
  def subscribe_lobbies() do
    raise "GameServer.Lobbies.subscribe_lobbies/0 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Subscribe to a specific lobby's events (membership changes, updates).
    
  """
  @spec subscribe_lobby(integer()) :: :ok | {:error, term()}
  def subscribe_lobby(_lobby_id) do
    raise "GameServer.Lobbies.subscribe_lobby/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Unsubscribe from a specific lobby's events.
    
  """
  def unsubscribe_lobby(_lobby_id) do
    raise "GameServer.Lobbies.unsubscribe_lobby/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Updates an existing lobby.
    
    ## Attributes
    
    See `t:GameServer.Types.lobby_update_attrs/0` for available fields.
    
  """
  @spec update_lobby(GameServer.Lobbies.Lobby.t(), GameServer.Types.lobby_update_attrs()) ::
  {:ok, GameServer.Lobbies.Lobby.t()} | {:error, Ecto.Changeset.t() | term()}
  def update_lobby(_lobby, _attrs) do
    raise "GameServer.Lobbies.update_lobby/2 is a stub - only available at runtime on GameServer"
  end


  @doc false
  def update_lobby_by_host(_user, _lobby, _attrs) do
    raise "GameServer.Lobbies.update_lobby_by_host/3 is a stub - only available at runtime on GameServer"
  end

end
