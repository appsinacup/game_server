# `GameServer.Accounts.User`

The User schema and associated changeset functions used across the
application (registration, OAuth, and admin changes).

This module keeps Ecto changesets for common user interactions and
validations so other domains can reuse them safely.

# `t`

```elixir
@type t() :: %GameServer.Accounts.User{
  __meta__: term(),
  apple_id: term(),
  authenticated_at: term(),
  confirmed_at: DateTime.t() | nil,
  device_id: term(),
  discord_id: term(),
  display_name: String.t() | nil,
  email: String.t() | nil,
  facebook_id: term(),
  google_id: term(),
  hashed_password: String.t() | nil,
  id: Ecto.UUID.t() | integer() | nil,
  inserted_at: term(),
  is_admin: term(),
  is_online: boolean(),
  last_seen_at: DateTime.t() | nil,
  lobby: term(),
  lobby_id: integer() | nil,
  metadata: map(),
  password: term(),
  profile_url: term(),
  steam_id: term(),
  updated_at: term()
}
```

The public user struct used across the application.

# `admin_changeset`

A user changeset for admin updates.

# `apple_oauth_changeset`

A user changeset for Apple OAuth registration.

It accepts email and Apple ID.

# `attach_device_changeset`

Changeset used when a device_id is present (linking device_id to user).
Ensures device_id is stored on user record and enforces uniqueness by DB
constraint.

# `confirm_changeset`

Confirms the account by setting `confirmed_at`.

# `device_changeset`

A user changeset used for device-based logins where there is no email.

Device users are created with optional display_name and metadata and are
immediately confirmed so the SDK can receive tokens without email confirmation.

# `discord_oauth_changeset`

A user changeset for Discord OAuth registration.

It accepts email and Discord fields.

# `display_name_changeset`

A simple changeset for updating a user's display name.

Allows empty string so users can set an empty display name if desired.

# `email_changeset`

A user changeset for registering or changing the email.

It requires the email to change otherwise an error is added.

## Options

  * `:validate_unique` - Set to false if you don't want to validate the
    uniqueness of the email, useful when displaying live validations.
    Defaults to `true`.

# `facebook_oauth_changeset`

A user changeset for Facebook OAuth registration.

It accepts email and Facebook ID.

# `google_oauth_changeset`

A user changeset for Google OAuth registration.

It accepts email and Google ID.

# `last_seen_at_or_fallback`

```elixir
@spec last_seen_at_or_fallback(t()) :: DateTime.t()
```

Returns `last_seen_at` when present, otherwise a stable fallback timestamp.

# `password_changeset`

A user changeset for changing the password.

It is important to validate the length of the password, as long passwords may
be very expensive to hash for certain algorithms.

## Options

  * `:hash_password` - Hashes the password so it can be stored securely
    in the database and ensures the password field is cleared to prevent
    leaks in the logs. If password hashing is not needed and clearing the
    password field is not desired (like when using this changeset for
    validations on a LiveView form), this option can be set to `false`.
    Defaults to `true`.

# `registration_changeset`

A user changeset for registering a new user.

# `steam_oauth_changeset`

A user changeset for Steam OpenID registration.

Expects steam_id and optional profile fields.

# `valid_password?`

Verifies the password.

If there is no user or the user doesn't have a password, we call
`Bcrypt.no_user_verify/0` to avoid timing attacks.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
