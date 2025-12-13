defmodule GameServer.Accounts do
  @moduledoc ~S"""
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

  @doc ~S"""
    Attach a device_id to an existing user record. Returns {:ok, user} or
    {:error, changeset} if the device_id is already used.
    
  """
  def attach_device_to_user(_user, _device_id) do
    raise "GameServer.Accounts.attach_device_to_user/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Broadcast that the given user has been updated.
    
    This helper is intentionally small and only broadcasts a compact payload
    intended for client consumption through the `user:<id>` topic.
    
  """
  def broadcast_user_update(_user) do
    raise "GameServer.Accounts.broadcast_user_update/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Returns an `%Ecto.Changeset{}` for changing the user display_name.
    
  """
  def change_user_display_name(_user) do
    raise "GameServer.Accounts.change_user_display_name/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Returns an `%Ecto.Changeset{}` for changing the user display_name.
    
  """
  def change_user_display_name(_user, _attrs) do
    raise "GameServer.Accounts.change_user_display_name/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Returns an `%Ecto.Changeset{}` for changing the user email.
    
    See `GameServer.Accounts.User.email_changeset/3` for a list of supported options.
    
    ## Examples
    
        iex> change_user_email(user)
        %Ecto.Changeset{data: %User{}}
    
    
  """
  def change_user_email(_user) do
    raise "GameServer.Accounts.change_user_email/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Returns an `%Ecto.Changeset{}` for changing the user email.
    
    See `GameServer.Accounts.User.email_changeset/3` for a list of supported options.
    
    ## Examples
    
        iex> change_user_email(user)
        %Ecto.Changeset{data: %User{}}
    
    
  """
  def change_user_email(_user, _attrs) do
    raise "GameServer.Accounts.change_user_email/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Returns an `%Ecto.Changeset{}` for changing the user email.
    
    See `GameServer.Accounts.User.email_changeset/3` for a list of supported options.
    
    ## Examples
    
        iex> change_user_email(user)
        %Ecto.Changeset{data: %User{}}
    
    
  """
  def change_user_email(_user, _attrs, _opts) do
    raise "GameServer.Accounts.change_user_email/3 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Returns an `%Ecto.Changeset{}` for changing the user password.
    
    See `GameServer.Accounts.User.password_changeset/3` for a list of supported options.
    
    ## Examples
    
        iex> change_user_password(user)
        %Ecto.Changeset{data: %User{}}
    
    
  """
  def change_user_password(_user) do
    raise "GameServer.Accounts.change_user_password/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Returns an `%Ecto.Changeset{}` for changing the user password.
    
    See `GameServer.Accounts.User.password_changeset/3` for a list of supported options.
    
    ## Examples
    
        iex> change_user_password(user)
        %Ecto.Changeset{data: %User{}}
    
    
  """
  def change_user_password(_user, _attrs) do
    raise "GameServer.Accounts.change_user_password/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Returns an `%Ecto.Changeset{}` for changing the user password.
    
    See `GameServer.Accounts.User.password_changeset/3` for a list of supported options.
    
    ## Examples
    
        iex> change_user_password(user)
        %Ecto.Changeset{data: %User{}}
    
    
  """
  def change_user_password(_user, _attrs, _opts) do
    raise "GameServer.Accounts.change_user_password/3 is a stub - only available at runtime on GameServer"
  end


  @doc false
  def change_user_registration(_user) do
    raise "GameServer.Accounts.change_user_registration/1 is a stub - only available at runtime on GameServer"
  end


  @doc false
  def change_user_registration(_user, _attrs) do
    raise "GameServer.Accounts.change_user_registration/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Confirms a user's email by setting confirmed_at timestamp.
    
    ## Examples
    
        iex> confirm_user(user)
        {:ok, %User{}}
    
    
  """
  def confirm_user(_user) do
    raise "GameServer.Accounts.confirm_user/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Confirm a user by an email confirmation token (context: "confirm").
    
    Returns {:ok, user} when the token is valid and user was confirmed.
    Returns {:error, :not_found} or {:error, :expired} when token is invalid/expired.
    
  """
  def confirm_user_by_token(_token) do
    raise "GameServer.Accounts.confirm_user_by_token/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Count users matching a text query (email or display_name). Returns integer.
    
  """
  def count_search_users(_query) do
    raise "GameServer.Accounts.count_search_users/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Returns the total number of users.
    
  """
  @spec count_users() :: non_neg_integer()
  def count_users() do
    raise "GameServer.Accounts.count_users/0 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Count users active (authenticated_at updated) in the last N days.
    Uses UserToken inserted_at to track recent authentications.
    
  """
  @spec count_users_active_since(integer()) :: non_neg_integer()
  def count_users_active_since(_days) do
    raise "GameServer.Accounts.count_users_active_since/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Count users registered in the last N days.
    
  """
  @spec count_users_registered_since(integer()) :: non_neg_integer()
  def count_users_registered_since(_days) do
    raise "GameServer.Accounts.count_users_registered_since/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Count users with a password set (hashed_password not nil/empty).
    
  """
  @spec count_users_with_password() :: non_neg_integer()
  def count_users_with_password() do
    raise "GameServer.Accounts.count_users_with_password/0 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Count users with non-empty provider id for a given provider field (e.g. :google_id)
    
  """
  @spec count_users_with_provider(atom()) :: non_neg_integer()
  def count_users_with_provider(_provider_field) do
    raise "GameServer.Accounts.count_users_with_provider/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Deletes a user and associated resources.
    
    Returns `{:ok, user}` on success or `{:error, changeset}` on failure.
    
  """
  def delete_user(_user) do
    raise "GameServer.Accounts.delete_user/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Deletes the signed token with the given context.
    
  """
  def delete_user_session_token(_token) do
    raise "GameServer.Accounts.delete_user_session_token/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Delivers the magic link login instructions to the given user.
    
  """
  def deliver_login_instructions(_user, _magic_link_url_fun) do
    raise "GameServer.Accounts.deliver_login_instructions/2 is a stub - only available at runtime on GameServer"
  end


  @doc false
  def deliver_user_confirmation_instructions(_user, _confirmation_url_fun) do
    raise "GameServer.Accounts.deliver_user_confirmation_instructions/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Delivers the update email instructions to the given user.
    
    ## Examples
    
        iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
        {:ok, %{to: ..., body: ...}}
    
    
  """
  def deliver_user_update_email_instructions(_user, _current_email, _update_email_url_fun) do
    raise "GameServer.Accounts.deliver_user_update_email_instructions/3 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Returns true when device-based auth is enabled. This checks the
    application config `:game_server, :device_auth_enabled` and falls back
    to the environment variable `DEVICE_AUTH_ENABLED`. If neither
    is set, device auth is enabled by default.
    
  """
  def device_auth_enabled?() do
    raise "GameServer.Accounts.device_auth_enabled?/0 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Finds a user by Apple ID or creates a new user from OAuth data.
    
    ## Examples
    
        iex> find_or_create_from_apple(%{apple_id: "123", email: "user@example.com"})
        {:ok, %User{}}
    
    
  """
  def find_or_create_from_apple(_attrs) do
    raise "GameServer.Accounts.find_or_create_from_apple/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Finds or creates a user associated with the given device_id.
    
    If a user already exists with the device_id we return it. Otherwise we
    create an anonymous confirmed user and attach the device_id.
    
  """
  def find_or_create_from_device(_device_id) do
    raise "GameServer.Accounts.find_or_create_from_device/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Finds or creates a user associated with the given device_id.
    
    If a user already exists with the device_id we return it. Otherwise we
    create an anonymous confirmed user and attach the device_id.
    
  """
  def find_or_create_from_device(_device_id, _attrs) do
    raise "GameServer.Accounts.find_or_create_from_device/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Finds a user by Discord ID or creates a new user from OAuth data.
    
    ## Examples
    
        iex> find_or_create_from_discord(%{discord_id: "123", email: "user@example.com"})
        {:ok, %User{}}
    
    
  """
  def find_or_create_from_discord(_attrs) do
    raise "GameServer.Accounts.find_or_create_from_discord/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Finds a user by Facebook ID or creates a new user from OAuth data.
    
    ## Examples
    
        iex> find_or_create_from_facebook(%{facebook_id: "123", email: "user@example.com"})
        {:ok, %User{}}
    
    
  """
  def find_or_create_from_facebook(_attrs) do
    raise "GameServer.Accounts.find_or_create_from_facebook/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Finds a user by Google ID or creates a new user from OAuth data.
    
    ## Examples
    
        iex> find_or_create_from_google(%{google_id: "123", email: "user@example.com"})
        {:ok, %User{}}
    
    
  """
  def find_or_create_from_google(_attrs) do
    raise "GameServer.Accounts.find_or_create_from_google/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Finds a user by Steam ID or creates a new user from Steam OpenID data.
    
    ## Examples
    
        iex> find_or_create_from_steam(%{steam_id: "12345", email: "user@example.com"})
        {:ok, %User{}}
    
    
  """
  def find_or_create_from_steam(_attrs) do
    raise "GameServer.Accounts.find_or_create_from_steam/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Generates a session token.
    
  """
  def generate_user_session_token(_user) do
    raise "GameServer.Accounts.generate_user_session_token/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Returns a map of linked OAuth providers for the user.
    
    Each provider is a boolean indicating whether that provider is linked.
    
  """
  def get_linked_providers(_user) do
    raise "GameServer.Accounts.get_linked_providers/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
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


  @doc ~S"""
    Gets a single user.
    
    Raises `Ecto.NoResultsError` if the User does not exist.
    
    ## Examples
    
        iex> get_user!(123)
        %User{}
    
        iex> get_user!(456)
        ** (Ecto.NoResultsError)
    
    
  """
  @spec get_user!(integer()) :: GameServer.Accounts.User.t()
  def get_user!(_id) do
    raise "GameServer.Accounts.get_user!/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Get a user by their Apple ID.
    
    Returns `%User{}` or `nil`.
    
  """
  def get_user_by_apple_id(_apple_id) do
    raise "GameServer.Accounts.get_user_by_apple_id/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Get a user by their Discord ID.
    
    Returns `%User{}` or `nil`.
    
  """
  def get_user_by_discord_id(_discord_id) do
    raise "GameServer.Accounts.get_user_by_discord_id/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
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


  @doc ~S"""
    Gets a user by email and password.
    
    ## Examples
    
        iex> get_user_by_email_and_password("foo@example.com", "correct_password")
        %User{}
    
        iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
        nil
    
    
  """
  def get_user_by_email_and_password(_email, _password) do
    raise "GameServer.Accounts.get_user_by_email_and_password/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Get a user by their Facebook ID.
    
    Returns `%User{}` or `nil`.
    
  """
  def get_user_by_facebook_id(_facebook_id) do
    raise "GameServer.Accounts.get_user_by_facebook_id/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Get a user by their Google ID.
    
    Returns `%User{}` or `nil`.
    
  """
  def get_user_by_google_id(_google_id) do
    raise "GameServer.Accounts.get_user_by_google_id/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Gets the user with the given magic link token.
    
  """
  def get_user_by_magic_link_token(_token) do
    raise "GameServer.Accounts.get_user_by_magic_link_token/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Gets the user with the given signed token.
    
    If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
    
  """
  def get_user_by_session_token(_token) do
    raise "GameServer.Accounts.get_user_by_session_token/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Get a user by their Steam ID (steam_id).
    
    Returns `%User{}` or `nil`.
    
  """
  def get_user_by_steam_id(_steam_id) do
    raise "GameServer.Accounts.get_user_by_steam_id/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Returns whether the user has a password set.
    
  """
  def has_password?(_user) do
    raise "GameServer.Accounts.has_password?/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Link an OAuth provider to an existing user account. Updates the user
    via the provider's oauth changeset while being careful not to overwrite
    existing email or avatars.
    
    Example: link_account(user, %{discord_id: "123", profile_url: "https://..."}, :discord_id, &User.discord_oauth_changeset/2)
    
  """
  def link_account(_user, _attrs, _provider_id_field, _changeset_fn) do
    raise "GameServer.Accounts.link_account/4 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Link a device_id to an existing user account. This allows the user to
    authenticate using the device_id in addition to their OAuth providers.
    
    Returns {:ok, user} on success or {:error, changeset} if the device_id
    is already used by another account.
    
  """
  def link_device_id(_user, _device_id) do
    raise "GameServer.Accounts.link_device_id/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Logs the user in by magic link.
    
    There are three cases to consider:
    
    1. The user has already confirmed their email. They are logged in
       and the magic link is expired.
    
    2. The user has not confirmed their email and no password is set.
       In this case, the user gets confirmed, logged in, and all tokens -
       including session ones - are expired. In theory, no other tokens
       exist but we delete all of them for best security practices.
    
    3. The user has not confirmed their email but a password is set.
       This cannot happen in the default implementation but may be the
       source of security pitfalls. See the "Mixing magic link and password registration" section of
       `mix help phx.gen.auth`.
    
  """
  def login_user_by_magic_link(_token) do
    raise "GameServer.Accounts.login_user_by_magic_link/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Registers a user.
    
    ## Attributes
    
    See `t:GameServer.Types.user_registration_attrs/0` for available fields.
    
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


  @doc ~S"""
    Register a user and send the confirmation email inside a DB transaction.
    
    The function accepts a `confirmation_url_fun` which must be a function of arity 1
    that receives the encoded token and returns the confirmation URL string.
    
    If sending the confirmation email fails the transaction is rolled back and
    `{:error, reason}` is returned. On success it returns `{:ok, user}`.
    
  """
  def register_user_and_deliver(_attrs, _confirmation_url_fun) do
    raise "GameServer.Accounts.register_user_and_deliver/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Register a user and send the confirmation email inside a DB transaction.
    
    The function accepts a `confirmation_url_fun` which must be a function of arity 1
    that receives the encoded token and returns the confirmation URL string.
    
    If sending the confirmation email fails the transaction is rolled back and
    `{:error, reason}` is returned. On success it returns `{:ok, user}`.
    
  """
  def register_user_and_deliver(_attrs, _confirmation_url_fun, _notifier) do
    raise "GameServer.Accounts.register_user_and_deliver/3 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Search users by email or display name (case-insensitive, partial match).
    
    Returns a list of User structs.
    
    ## Options
    
    See `t:GameServer.Types.pagination_opts/0` for available options.
    
  """
  def search_users(_query) do
    raise "GameServer.Accounts.search_users/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Search users by email or display name (case-insensitive, partial match).
    
    Returns a list of User structs.
    
    ## Options
    
    See `t:GameServer.Types.pagination_opts/0` for available options.
    
  """
  @spec search_users(String.t(), GameServer.Types.pagination_opts()) :: [GameServer.Accounts.User.t()]
  def search_users(_query, _opts) do
    raise "GameServer.Accounts.search_users/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Checks whether the user is in sudo mode.
    
    The user is in sudo mode when the last authentication was done no further
    than 20 minutes ago. The limit can be given as second argument in minutes.
    
  """
  def sudo_mode?(_user) do
    raise "GameServer.Accounts.sudo_mode?/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Checks whether the user is in sudo mode.
    
    The user is in sudo mode when the last authentication was done no further
    than 20 minutes ago. The limit can be given as second argument in minutes.
    
  """
  def sudo_mode?(_user, _minutes) do
    raise "GameServer.Accounts.sudo_mode?/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Unlink the device_id from a user's account.
    
    Returns {:ok, user} when successful or {:error, reason}.
    
    Guard: we only allow unlinking when the user will still have at least
    one authentication method remaining (OAuth provider or password).
    This prevents users losing all login methods unexpectedly.
    
  """
  def unlink_device_id(_user) do
    raise "GameServer.Accounts.unlink_device_id/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Unlink an OAuth provider from a user's account.
    
    provider should be one of :discord, :apple, :google, :facebook.
    This will return {:ok, user} when successful or {:error, reason}.
    
    Guard: we only allow unlinking when the user will still have at least
    one other social provider remaining. This prevents users losing all
    social logins unexpectedly.
    
  """
  def unlink_provider(_user, _provider) do
    raise "GameServer.Accounts.unlink_provider/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Updates a user with the given attributes.
    
    This function applies the `User.admin_changeset/2` then updates the user and
    broadcasts the update on success. It returns the same tuple shape as
    `Repo.update/1` so callers can pattern-match as before.
    
    ## Attributes
    
    See `t:GameServer.Types.user_update_attrs/0` for available fields.
    
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


  @doc ~S"""
    Updates the user's display name and broadcasts the change.
    
  """
  def update_user_display_name(_user, _attrs) do
    raise "GameServer.Accounts.update_user_display_name/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Updates the user email using the given token.
    
    If the token matches, the user email is updated and the token is deleted.
    
  """
  def update_user_email(_user, _token) do
    raise "GameServer.Accounts.update_user_email/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Updates the user password.
    
    Returns a tuple with the updated user, as well as a list of expired tokens.
    
    ## Examples
    
        iex> update_user_password(user, %{password: ...})
        {:ok, {%User{}, [...]}}
    
        iex> update_user_password(user, %{password: "too short"})
        {:error, %Ecto.Changeset{}}
    
    
  """
  def update_user_password(_user, _attrs) do
    raise "GameServer.Accounts.update_user_password/2 is a stub - only available at runtime on GameServer"
  end

end
