defmodule GameServer.Friends do
  @moduledoc ~S"""
  Friends context - handles friend requests and relationships.
  
  Basic semantics:
  - A single `friendships` row represents a directed request from requester -> target.
  - status: "pending" | "accepted" | "rejected" | "blocked"
  - When a user accepts a pending incoming request, that request becomes `accepted`.
    If a reverse pending request exists, it will be removed to avoid duplicate rows.
  - Listing friends returns the other user from rows with status `accepted` in either
    direction.
  
  ## Usage
  
      # Create a friend request (requester -> target)
      {:ok, friendship} = GameServer.Friends.create_request(requester_id, target_id)
  
      # Accept a pending incoming request (performed by the target)
      {:ok, accepted} = GameServer.Friends.accept_friend_request(friendship.id, %GameServer.Accounts.User{id: target_id})
  
      # List accepted friends for a user (paginated)
      friends = GameServer.Friends.list_friends_for_user(user_id, page: 1, page_size: 25)
  
      # Count accepted friends for a user
      count = GameServer.Friends.count_friends_for_user(user_id)
  
      # Remove a friendship (either direction)
      {:ok, _} = GameServer.Friends.remove_friend(user_id, friend_id)
  
  

  **Note:** This is an SDK stub. Calling these functions will raise an error.
  The actual implementation runs on the GameServer.
  """

  @doc ~S"""
    Accept a friend request (only the target may accept). Returns {:ok, friendship}.
  """
  @spec accept_friend_request(integer(), GameServer.Accounts.User.t()) ::
  {:ok, GameServer.Friends.Friendship.t()} | {:error, term()}
  def accept_friend_request(_friendship_id, _user) do
    raise "GameServer.Friends.accept_friend_request/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Block an incoming request (only the target may block). Returns {:ok, friendship} with status "blocked".
  """
  @spec block_friend_request(integer(), GameServer.Accounts.User.t()) ::
  {:ok, GameServer.Friends.Friendship.t()} | {:error, term()}
  def block_friend_request(_friendship_id, _user) do
    raise "GameServer.Friends.block_friend_request/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Cancel an outgoing friend request (only the requester may cancel).
  """
  def cancel_request(_friendship_id, _user) do
    raise "GameServer.Friends.cancel_request/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Count blocked friendships for a user (number of blocked rows where user is target).
  """
  def count_blocked_for_user(_user_id) do
    raise "GameServer.Friends.count_blocked_for_user/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Count accepted friends for a given user (distinct other user ids).
  """
  def count_friends_for_user(_user_id) do
    raise "GameServer.Friends.count_friends_for_user/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Count incoming pending friend requests for a user.
  """
  def count_incoming_requests(_user_id) do
    raise "GameServer.Friends.count_incoming_requests/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Count outgoing pending friend requests for a user.
  """
  def count_outgoing_requests(_user_id) do
    raise "GameServer.Friends.count_outgoing_requests/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Create a friend request from requester -> target.
      If a reverse pending request exists (target -> requester) it will be accepted instead.
      Returns {:ok, friendship} on success or {:error, reason}.
      
  """
  @spec create_request(GameServer.Accounts.User.t() | integer(), integer()) ::
  {:ok, GameServer.Friends.Friendship.t()} | {:error, any()}
  def create_request(_requester_id, _target_id) do
    raise "GameServer.Friends.create_request/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Get friendship between two users (ordered requester->target) if exists
  """
  def get_by_pair(_requester_id, _target_id) do
    raise "GameServer.Friends.get_by_pair/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Get friendship by id
  """
  def get_friendship!(_id) do
    raise "GameServer.Friends.get_friendship!/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    List blocked friendships for a user (Friendship structs where the user is the blocker / target).
  """
  def list_blocked_for_user(_user_id) do
    raise "GameServer.Friends.list_blocked_for_user/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    List blocked friendships for a user (Friendship structs where the user is the blocker / target).
  """
  def list_blocked_for_user(_user_id, _opts) do
    raise "GameServer.Friends.list_blocked_for_user/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    List accepted friends for a given user id - returns list of User structs.
    
    ## Options
    
    See `t:GameServer.Types.pagination_opts/0` for available options.
    
  """
  def list_friends_for_user(_user_id) do
    raise "GameServer.Friends.list_friends_for_user/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    List accepted friends for a given user id - returns list of User structs.
    
    ## Options
    
    See `t:GameServer.Types.pagination_opts/0` for available options.
    
  """
  @spec list_friends_for_user(
  integer() | GameServer.Accounts.User.t(),
  GameServer.Types.pagination_opts()
) :: [GameServer.Accounts.User.t()]
  def list_friends_for_user(_user_id, _opts) do
    raise "GameServer.Friends.list_friends_for_user/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    List incoming pending friend requests for a user (Friendship structs).
    
    ## Options
    
    See `t:GameServer.Types.pagination_opts/0` for available options.
    
  """
  def list_incoming_requests(_user_id) do
    raise "GameServer.Friends.list_incoming_requests/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    List incoming pending friend requests for a user (Friendship structs).
    
    ## Options
    
    See `t:GameServer.Types.pagination_opts/0` for available options.
    
  """
  @spec list_incoming_requests(
  integer() | GameServer.Accounts.User.t(),
  GameServer.Types.pagination_opts()
) :: [GameServer.Friends.Friendship.t()]
  def list_incoming_requests(_user_id, _opts) do
    raise "GameServer.Friends.list_incoming_requests/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    List outgoing pending friend requests for a user (Friendship structs).
    
    ## Options
    
    See `t:GameServer.Types.pagination_opts/0` for available options.
    
  """
  def list_outgoing_requests(_user_id) do
    raise "GameServer.Friends.list_outgoing_requests/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    List outgoing pending friend requests for a user (Friendship structs).
    
    ## Options
    
    See `t:GameServer.Types.pagination_opts/0` for available options.
    
  """
  @spec list_outgoing_requests(
  integer() | GameServer.Accounts.User.t(),
  GameServer.Types.pagination_opts()
) :: [GameServer.Friends.Friendship.t()]
  def list_outgoing_requests(_user_id, _opts) do
    raise "GameServer.Friends.list_outgoing_requests/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Reject a friend request (only the target may reject). Returns {:ok, friendship}.
  """
  @spec reject_friend_request(integer(), GameServer.Accounts.User.t()) ::
  {:ok, GameServer.Friends.Friendship.t()} | {:error, term()}
  def reject_friend_request(_friendship_id, _user) do
    raise "GameServer.Friends.reject_friend_request/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Remove a friendship (either direction) - only participating users may call this.
  """
  @spec remove_friend(integer(), integer()) :: {:ok, GameServer.Friends.Friendship.t()} | {:error, term()}
  def remove_friend(_user_id, _friend_id) do
    raise "GameServer.Friends.remove_friend/2 is a stub - only available at runtime on GameServer"
  end


  @doc false
  def subscribe_user(_user_id) do
    raise "GameServer.Friends.subscribe_user/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Unblock a previously-blocked friendship (only the user who blocked may unblock). Returns {:ok, :unblocked} on success.
  """
  @spec unblock_friendship(integer(), GameServer.Accounts.User.t()) ::
  {:ok, :unblocked} | {:error, term()}
  def unblock_friendship(_friendship_id, _user) do
    raise "GameServer.Friends.unblock_friendship/2 is a stub - only available at runtime on GameServer"
  end


  @doc false
  def unsubscribe_user(_user_id) do
    raise "GameServer.Friends.unsubscribe_user/1 is a stub - only available at runtime on GameServer"
  end

end
