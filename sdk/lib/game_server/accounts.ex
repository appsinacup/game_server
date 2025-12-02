defmodule GameServer.Accounts do
  @moduledoc """
  The Accounts context.
  
  ## Usage
      # Lookup by id or email
      user = GameServer.Accounts.get_user(123)
      user = GameServer.Accounts.get_user_by_email("me@example.com")
  
      # Update a user
      {:ok, user} = GameServer.Accounts.update_user(user, %{display_name: "NewName"})
  
      # Search (paginated) and count
      users = GameServer.Accounts.search_users("bob", page: 1, page_size: 25)
      count = GameServer.Accounts.count_search_users("bob")
  
  

  **Note:** This is an SDK stub. Calling these functions will raise an error.
  The actual implementation runs on the GameServer.
  """

  @doc """
    Gets a single user by ID.
    
    Returns `nil` if the User does not exist.
    
    ## Examples
    
        iex> get_user(123)
        %User{}
    
        iex> get_user(456)
        nil
    
    
  """
  @spec get_user(integer()) :: GameServer.Accounts.User.t() | nil
  def get_user(_id) do
    raise "GameServer.Accounts.get_user/1 is a stub - only available at runtime on GameServer"
  end


  @doc """
    Gets a user by email.
    
    ## Examples
    
        iex> get_user_by_email("foo@example.com")
        %User{}
    
        iex> get_user_by_email("unknown@example.com")
        nil
    
    
  """
  @spec get_user_by_email(String.t()) :: GameServer.Accounts.User.t() | nil
  def get_user_by_email(_email) do
    raise "GameServer.Accounts.get_user_by_email/1 is a stub - only available at runtime on GameServer"
  end


  @doc """
    Search users by email or display name (case-insensitive, partial match).
    
    Returns a list of User structs.
    
    ## Options
    
    See `GameServer.Types.pagination_opts/0` for available options.
    
  """
  @spec search_users(String.t(), GameServer.Types.pagination_opts()) :: [GameServer.Accounts.User.t()]
  def search_users(_query, _opts) do
    raise "GameServer.Accounts.search_users/2 is a stub - only available at runtime on GameServer"
  end


  @doc """
    Updates a user with the given attributes.
    
    This function applies the `User.admin_changeset/2` then updates the user and
    broadcasts the update on success. It returns the same tuple shape as
    `Repo.update/1` so callers can pattern-match as before.
    
    ## Attributes
    
    See `GameServer.Types.user_update_attrs/0` for available fields.
    
    ## Examples
    
        iex> update_user(user, %{display_name: "NewName"})
        {:ok, %User{}}
    
        iex> update_user(user, %{metadata: %{level: 5}})
        {:ok, %User{}}
    
    
  """
  @spec update_user(GameServer.Accounts.User.t(), GameServer.Types.user_update_attrs()) ::
  {:ok, GameServer.Accounts.User.t()} | {:error, Ecto.Changeset.t()}
  def update_user(_user, _attrs) do
    raise "GameServer.Accounts.update_user/2 is a stub - only available at runtime on GameServer"
  end


  @doc """
    Registers a user.
    
    ## Attributes
    
    See `GameServer.Types.user_registration_attrs/0` for available fields.
    
    ## Examples
    
        iex> register_user(%{email: "user@example.com", password: "secret123"})
        {:ok, %User{}}
    
        iex> register_user(%{email: "invalid"})
        {:error, %Ecto.Changeset{}}
    
    
  """
  @spec register_user(GameServer.Types.user_registration_attrs()) ::
  {:ok, GameServer.Accounts.User.t()} | {:error, Ecto.Changeset.t()}
  def register_user(_attrs) do
    raise "GameServer.Accounts.register_user/1 is a stub - only available at runtime on GameServer"
  end

end
