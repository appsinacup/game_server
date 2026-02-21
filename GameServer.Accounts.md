# `GameServer.Accounts`

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

# `attach_device_to_user`

```elixir
@spec attach_device_to_user(GameServer.Accounts.User.t(), String.t()) ::
  {:ok, GameServer.Accounts.User.t()} | {:error, Ecto.Changeset.t()}
```

Attach a device_id to an existing user record. Returns {:ok, user} or
{:error, changeset} if the device_id is already used.

# `broadcast_user_update`

```elixir
@spec broadcast_user_update(GameServer.Accounts.User.t()) :: :ok
```

Broadcast that the given user has been updated.

This helper is intentionally small and only broadcasts a compact payload
intended for client consumption through the `user:<id>` topic.

# `change_user_display_name`

```elixir
@spec change_user_display_name(GameServer.Accounts.User.t(), map()) ::
  Ecto.Changeset.t()
```

Returns an `%Ecto.Changeset{}` for changing the user display_name.

# `change_user_email`

```elixir
@spec change_user_email(GameServer.Accounts.User.t(), map(), keyword()) ::
  Ecto.Changeset.t()
```

Returns an `%Ecto.Changeset{}` for changing the user email.

See `GameServer.Accounts.User.email_changeset/3` for a list of supported options.

## Examples

    iex> change_user_email(user)
    %Ecto.Changeset{data: %User{}}

# `change_user_password`

```elixir
@spec change_user_password(GameServer.Accounts.User.t(), map(), keyword()) ::
  Ecto.Changeset.t()
```

Returns an `%Ecto.Changeset{}` for changing the user password.

See `GameServer.Accounts.User.password_changeset/3` for a list of supported options.

## Examples

    iex> change_user_password(user)
    %Ecto.Changeset{data: %User{}}

# `change_user_registration`

```elixir
@spec change_user_registration(GameServer.Accounts.User.t(), map()) ::
  Ecto.Changeset.t()
```

# `confirm_user`

```elixir
@spec confirm_user(GameServer.Accounts.User.t()) ::
  {:ok, GameServer.Accounts.User.t()} | {:error, Ecto.Changeset.t()}
```

Confirms a user's email by setting confirmed_at timestamp.

## Examples

    iex> confirm_user(user)
    {:ok, %User{}}

# `confirm_user_by_token`

```elixir
@spec confirm_user_by_token(String.t()) ::
  {:ok, GameServer.Accounts.User.t()} | {:error, :invalid | :not_found}
```

Confirm a user by an email confirmation token (context: "confirm").

Returns {:ok, user} when the token is valid and user was confirmed.
Returns {:error, :not_found} or {:error, :expired} when token is invalid/expired.

# `count_search_users`

```elixir
@spec count_search_users(String.t()) :: non_neg_integer()
```

Count users matching a text query (email or display_name). Returns integer.

# `count_users`

```elixir
@spec count_users() :: non_neg_integer()
```

Returns the total number of users.

# `count_users_active_since`

```elixir
@spec count_users_active_since(integer()) :: non_neg_integer()
```

Count users active in the last N days.

This metric is based on `users.updated_at` (any user record update,
including registration/creation), so it reflects all users and not just
session-token based authentication.

# `count_users_registered_since`

```elixir
@spec count_users_registered_since(integer()) :: non_neg_integer()
```

Count users registered in the last N days.

# `count_users_with_password`

```elixir
@spec count_users_with_password() :: non_neg_integer()
```

Count users with a password set (hashed_password not nil/empty).

# `count_users_with_provider`

```elixir
@spec count_users_with_provider(atom()) :: non_neg_integer()
```

Count users with non-empty provider id for a given provider field (e.g. :google_id)

# `delete_user`

```elixir
@spec delete_user(GameServer.Accounts.User.t()) ::
  {:ok, GameServer.Accounts.User.t()} | {:error, Ecto.Changeset.t()}
```

Deletes a user and associated resources.

Returns `{:ok, user}` on success or `{:error, changeset}` on failure.

# `delete_user_session_token`

```elixir
@spec delete_user_session_token(binary()) :: :ok
```

Deletes the signed token with the given context.

# `deliver_login_instructions`

```elixir
@spec deliver_login_instructions(GameServer.Accounts.User.t(), (String.t() -&gt;
                                                            String.t())) ::
  {:ok, Swoosh.Email.t()} | {:error, term()}
```

Delivers the magic link login instructions to the given user.

# `deliver_user_confirmation_instructions`

```elixir
@spec deliver_user_confirmation_instructions(
  GameServer.Accounts.User.t(),
  (String.t() -&gt; String.t())
) ::
  {:ok, Swoosh.Email.t()} | {:error, :already_confirmed | term()}
```

# `deliver_user_update_email_instructions`

```elixir
@spec deliver_user_update_email_instructions(
  GameServer.Accounts.User.t(),
  String.t(),
  (String.t() -&gt; String.t())
) :: {:ok, Swoosh.Email.t()} | {:error, term()}
```

Delivers the update email instructions to the given user.

## Examples

    iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
    {:ok, %{to: ..., body: ...}}

# `device_auth_enabled?`

```elixir
@spec device_auth_enabled?() :: boolean()
```

Returns true when device-based auth is enabled. This checks the
application config `:game_server, :device_auth_enabled` and falls back
to the environment variable `DEVICE_AUTH_ENABLED`. If neither
is set, device auth is enabled by default.

# `find_or_create_from_apple`

```elixir
@spec find_or_create_from_apple(map()) ::
  {:ok, GameServer.Accounts.User.t()} | {:error, Ecto.Changeset.t() | term()}
```

Finds a user by Apple ID or creates a new user from OAuth data.

## Examples

    iex> find_or_create_from_apple(%{apple_id: "123", email: "user@example.com"})
    {:ok, %User{}}

# `find_or_create_from_device`

```elixir
@spec find_or_create_from_device(String.t(), map()) ::
  {:ok, GameServer.Accounts.User.t()}
  | {:error, :disabled | Ecto.Changeset.t() | term()}
```

Finds or creates a user associated with the given device_id.

If a user already exists with the device_id we return it. Otherwise we
create an anonymous confirmed user and attach the device_id.

# `find_or_create_from_discord`

```elixir
@spec find_or_create_from_discord(map()) ::
  {:ok, GameServer.Accounts.User.t()} | {:error, Ecto.Changeset.t() | term()}
```

Finds a user by Discord ID or creates a new user from OAuth data.

## Examples

    iex> find_or_create_from_discord(%{discord_id: "123", email: "user@example.com"})
    {:ok, %User{}}

# `find_or_create_from_facebook`

```elixir
@spec find_or_create_from_facebook(map()) ::
  {:ok, GameServer.Accounts.User.t()} | {:error, Ecto.Changeset.t() | term()}
```

Finds a user by Facebook ID or creates a new user from OAuth data.

## Examples

    iex> find_or_create_from_facebook(%{facebook_id: "123", email: "user@example.com"})
    {:ok, %User{}}

# `find_or_create_from_google`

```elixir
@spec find_or_create_from_google(map()) ::
  {:ok, GameServer.Accounts.User.t()} | {:error, Ecto.Changeset.t() | term()}
```

Finds a user by Google ID or creates a new user from OAuth data.

## Examples

    iex> find_or_create_from_google(%{google_id: "123", email: "user@example.com"})
    {:ok, %User{}}

# `find_or_create_from_steam`

```elixir
@spec find_or_create_from_steam(map()) ::
  {:ok, GameServer.Accounts.User.t()} | {:error, Ecto.Changeset.t() | term()}
```

Finds a user by Steam ID or creates a new user from Steam OpenID data.

## Examples

    iex> find_or_create_from_steam(%{steam_id: "12345", email: "user@example.com"})
    {:ok, %User{}}

# `generate_user_session_token`

```elixir
@spec generate_user_session_token(GameServer.Accounts.User.t()) :: binary()
```

Generates a session token.

# `get_linked_providers`

```elixir
@spec get_linked_providers(GameServer.Accounts.User.t()) :: %{
  google: boolean(),
  facebook: boolean(),
  discord: boolean(),
  apple: boolean(),
  steam: boolean(),
  device: boolean()
}
```

Returns a map of linked OAuth providers for the user.

Each provider is a boolean indicating whether that provider is linked.

# `get_user`

```elixir
@spec get_user(integer()) :: GameServer.Accounts.User.t() | nil
```

Gets a single user by ID.

Returns `nil` if the User does not exist.

## Examples

    iex> get_user(123)
    %User{}

    iex> get_user(456)
    nil

# `get_user!`

```elixir
@spec get_user!(integer()) :: GameServer.Accounts.User.t()
```

Gets a single user.

Raises `Ecto.NoResultsError` if the User does not exist.

## Examples

    iex> get_user!(123)
    %User{}

    iex> get_user!(456)
    ** (Ecto.NoResultsError)

# `get_user_by_apple_id`

```elixir
@spec get_user_by_apple_id(String.t()) :: GameServer.Accounts.User.t() | nil
```

Get a user by their Apple ID.

Returns `%User{}` or `nil`.

# `get_user_by_discord_id`

```elixir
@spec get_user_by_discord_id(String.t()) :: GameServer.Accounts.User.t() | nil
```

Get a user by their Discord ID.

Returns `%User{}` or `nil`.

# `get_user_by_email`

```elixir
@spec get_user_by_email(String.t()) :: GameServer.Accounts.User.t() | nil
```

Gets a user by email.

## Examples

    iex> get_user_by_email("foo@example.com")
    %User{}

    iex> get_user_by_email("unknown@example.com")
    nil

# `get_user_by_email_and_password`

```elixir
@spec get_user_by_email_and_password(String.t(), String.t()) ::
  GameServer.Accounts.User.t() | nil
```

Gets a user by email and password.

## Examples

    iex> get_user_by_email_and_password("foo@example.com", "correct_password")
    %User{}

    iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
    nil

# `get_user_by_facebook_id`

```elixir
@spec get_user_by_facebook_id(String.t()) :: GameServer.Accounts.User.t() | nil
```

Get a user by their Facebook ID.

Returns `%User{}` or `nil`.

# `get_user_by_google_id`

```elixir
@spec get_user_by_google_id(String.t()) :: GameServer.Accounts.User.t() | nil
```

Get a user by their Google ID.

Returns `%User{}` or `nil`.

# `get_user_by_magic_link_token`

```elixir
@spec get_user_by_magic_link_token(String.t()) :: GameServer.Accounts.User.t() | nil
```

Gets the user with the given magic link token.

# `get_user_by_session_token`

```elixir
@spec get_user_by_session_token(binary()) ::
  {GameServer.Accounts.User.t(), DateTime.t()} | nil
```

Gets the user with the given signed token.

If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.

# `get_user_by_steam_id`

```elixir
@spec get_user_by_steam_id(String.t()) :: GameServer.Accounts.User.t() | nil
```

Get a user by their Steam ID (steam_id).

Returns `%User{}` or `nil`.

# `has_password?`

```elixir
@spec has_password?(GameServer.Accounts.User.t()) :: boolean()
```

Returns whether the user has a password set.

# `link_account`

```elixir
@spec link_account(
  GameServer.Accounts.User.t(),
  map(),
  atom(),
  (GameServer.Accounts.User.t(), map() -&gt;
     Ecto.Changeset.t())
) ::
  {:ok, GameServer.Accounts.User.t()}
  | {:error, Ecto.Changeset.t() | {:conflict, GameServer.Accounts.User.t()}}
```

Link an OAuth provider to an existing user account. Updates the user
via the provider's oauth changeset while being careful not to overwrite
existing email or avatars.

Example: link_account(user, %{discord_id: "123", profile_url: "https://..."}, :discord_id, &User.discord_oauth_changeset/2)

# `link_device_id`

```elixir
@spec link_device_id(GameServer.Accounts.User.t(), String.t()) ::
  {:ok, GameServer.Accounts.User.t()} | {:error, Ecto.Changeset.t()}
```

Link a device_id to an existing user account. This allows the user to
authenticate using the device_id in addition to their OAuth providers.

Returns {:ok, user} on success or {:error, changeset} if the device_id
is already used by another account.

# `login_user_by_magic_link`

```elixir
@spec login_user_by_magic_link(String.t()) ::
  {:ok, {GameServer.Accounts.User.t(), [GameServer.Accounts.UserToken.t()]}}
  | {:error, :not_found | Ecto.Changeset.t() | term()}
```

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

# `register_user`

```elixir
@spec register_user(GameServer.Types.user_registration_attrs()) ::
  {:ok, GameServer.Accounts.User.t()} | {:error, Ecto.Changeset.t()}
```

Registers a user.

## Attributes

See `t:GameServer.Types.user_registration_attrs/0` for available fields.

## Examples

    iex> register_user(%{email: "user@example.com", password: "secret123"})
    {:ok, %User{}}

    iex> register_user(%{email: "invalid"})
    {:error, %Ecto.Changeset{}}

# `register_user_and_deliver`

```elixir
@spec register_user_and_deliver(
  GameServer.Types.user_registration_attrs(),
  (String.t() -&gt; String.t()),
  module()
) :: {:ok, GameServer.Accounts.User.t()} | {:error, Ecto.Changeset.t() | term()}
```

Register a user and send the confirmation email inside a DB transaction.

The function accepts a `confirmation_url_fun` which must be a function of arity 1
that receives the encoded token and returns the confirmation URL string.

If sending the confirmation email fails the transaction is rolled back and
`{:error, reason}` is returned. On success it returns `{:ok, user}`.

# `search_users`

```elixir
@spec search_users(String.t(), GameServer.Types.pagination_opts()) :: [
  GameServer.Accounts.User.t()
]
```

Search users by email or display name (case-insensitive, partial match).

Returns a list of User structs.

## Options

See `t:GameServer.Types.pagination_opts/0` for available options.

# `serialize_user_payload`

```elixir
@spec serialize_user_payload(GameServer.Accounts.User.t()) :: map()
```

Serialize a user into the compact payload used by realtime updates.

# `set_user_offline`

```elixir
@spec set_user_offline(GameServer.Accounts.User.t() | integer()) ::
  {:ok, GameServer.Accounts.User.t()} | {:error, term()}
```

Mark a user as offline and update last_seen_at.
Returns {:ok, user} on success.

# `set_user_online`

```elixir
@spec set_user_online(GameServer.Accounts.User.t() | integer()) ::
  {:ok, GameServer.Accounts.User.t()} | {:error, term()}
```

Mark a user as online and update last_seen_at.
Returns {:ok, user} on success.

# `sudo_mode?`

```elixir
@spec sudo_mode?(GameServer.Accounts.User.t(), integer()) :: boolean()
```

Checks whether the user is in sudo mode.

The user is in sudo mode when the last authentication was done no further
than 20 minutes ago. The limit can be given as second argument in minutes.

# `unlink_device_id`

```elixir
@spec unlink_device_id(GameServer.Accounts.User.t()) ::
  {:ok, GameServer.Accounts.User.t()}
  | {:error, :last_auth_method | Ecto.Changeset.t()}
```

Unlink the device_id from a user's account.

Returns {:ok, user} when successful or {:error, reason}.

Guard: we only allow unlinking when the user will still have at least
one authentication method remaining (OAuth provider or password).
This prevents users losing all login methods unexpectedly.

# `unlink_provider`

```elixir
@spec unlink_provider(
  GameServer.Accounts.User.t(),
  :discord | :apple | :google | :facebook | :steam
) ::
  {:ok, GameServer.Accounts.User.t()}
  | {:error, :last_provider | Ecto.Changeset.t() | term()}
```

Unlink an OAuth provider from a user's account.

provider should be one of :discord, :apple, :google, :facebook.
This will return {:ok, user} when successful or {:error, reason}.

Guard: we only allow unlinking when the user will still have at least
one other social provider remaining. This prevents users losing all
social logins unexpectedly.

# `update_user`

```elixir
@spec update_user(GameServer.Accounts.User.t(), GameServer.Types.user_update_attrs()) ::
  {:ok, GameServer.Accounts.User.t()} | {:error, Ecto.Changeset.t()}
```

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

# `update_user_display_name`

```elixir
@spec update_user_display_name(GameServer.Accounts.User.t(), map()) ::
  {:ok, GameServer.Accounts.User.t()} | {:error, Ecto.Changeset.t()}
```

Updates the user's display name and broadcasts the change.

# `update_user_email`

```elixir
@spec update_user_email(GameServer.Accounts.User.t(), String.t()) ::
  {:ok, GameServer.Accounts.User.t()} | {:error, :transaction_aborted}
```

Updates the user email using the given token.

If the token matches, the user email is updated and the token is deleted.

# `update_user_password`

```elixir
@spec update_user_password(GameServer.Accounts.User.t(), map()) ::
  {:ok, {GameServer.Accounts.User.t(), [GameServer.Accounts.UserToken.t()]}}
  | {:error, Ecto.Changeset.t()}
```

Updates the user password.

Returns a tuple with the updated user, as well as a list of expired tokens.

## Examples

    iex> update_user_password(user, %{password: ...})
    {:ok, {%User{}, [...]}}

    iex> update_user_password(user, %{password: "too short"})
    {:error, %Ecto.Changeset{}}

---

*Consult [api-reference.md](api-reference.md) for complete listing*
