defmodule GameServer.Accounts.User do
  @moduledoc """
  The User schema and associated changeset functions used across the
  application (registration, OAuth, and admin changes).

  This module keeps Ecto changesets for common user interactions and
  validations so other domains can reuse them safely.
  """
  @typedoc "The public user struct used across the application."
  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | integer() | nil,
          email: String.t() | nil,
          hashed_password: String.t() | nil,
          confirmed_at: DateTime.t() | nil,
          display_name: String.t() | nil,
          metadata: map()
        }
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :email,
             :display_name,
             :profile_url,
             :metadata,
             :lobby_id,
             :inserted_at,
             :updated_at
           ]}

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true
    field :discord_id, :string
    field :profile_url, :string
    field :display_name, :string
    field :device_id, :string
    field :apple_id, :string
    field :steam_id, :string
    field :google_id, :string
    field :facebook_id, :string
    field :is_admin, :boolean, default: false
    field :metadata, :map, default: %{}

    # membership via users.lobby_id (each user can be in one lobby)
    belongs_to :lobby, GameServer.Lobbies.Lobby

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registering a new user.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> email_changeset(attrs, opts)
    |> password_changeset(attrs, opts)
  end

  @doc """
  A user changeset for registering or changing the email.

  It requires the email to change otherwise an error is added.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> update_change(:email, fn
      nil -> nil
      email -> String.downcase(email)
    end)
    |> validate_email(opts)
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:email, GameServer.Repo)
      |> unique_constraint(:email)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  @doc """
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
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  A user changeset for Discord OAuth registration.

  It accepts email and Discord fields.
  """
  def discord_oauth_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :discord_id, :profile_url, :is_admin, :display_name])
    |> update_change(:email, fn
      nil -> nil
      email -> String.downcase(email)
    end)
    |> validate_required([:discord_id])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, GameServer.Repo)
    |> unsafe_validate_unique(:discord_id, GameServer.Repo)
    |> unique_constraint(:email)
    |> unique_constraint(:discord_id)
    |> put_change(:confirmed_at, DateTime.utc_now(:second))
  end

  @doc """
  A user changeset for Steam OpenID registration.

  Expects steam_id and optional profile fields.
  """
  def steam_oauth_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :steam_id, :profile_url, :is_admin, :display_name])
    |> update_change(:email, fn
      nil -> nil
      email -> String.downcase(email)
    end)
    |> validate_required([:steam_id])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, GameServer.Repo)
    |> unsafe_validate_unique(:steam_id, GameServer.Repo)
    |> unique_constraint(:email)
    |> unique_constraint(:steam_id)
    |> put_change(:confirmed_at, DateTime.utc_now(:second))
  end

  @doc """
  A user changeset for Apple OAuth registration.

  It accepts email and Apple ID.
  """
  def apple_oauth_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :apple_id, :is_admin, :display_name])
    |> update_change(:email, fn
      nil -> nil
      email -> String.downcase(email)
    end)
    |> validate_required([:apple_id])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, GameServer.Repo)
    |> unsafe_validate_unique(:apple_id, GameServer.Repo)
    |> unique_constraint(:email)
    |> unique_constraint(:apple_id)
    |> put_change(:confirmed_at, DateTime.utc_now(:second))
  end

  @doc """
  A user changeset for Google OAuth registration.

  It accepts email and Google ID.
  """
  def google_oauth_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :google_id, :profile_url, :is_admin, :display_name])
    |> update_change(:email, fn
      nil -> nil
      email -> String.downcase(email)
    end)
    |> validate_required([:google_id])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, GameServer.Repo)
    |> unsafe_validate_unique(:google_id, GameServer.Repo)
    |> unique_constraint(:email)
    |> unique_constraint(:google_id)
    |> put_change(:confirmed_at, DateTime.utc_now(:second))
  end

  @doc """
  A user changeset for Facebook OAuth registration.

  It accepts email and Facebook ID.
  """
  def facebook_oauth_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :facebook_id, :profile_url, :is_admin, :display_name])
    |> update_change(:email, fn
      nil -> nil
      email -> String.downcase(email)
    end)
    |> validate_required([:facebook_id])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, GameServer.Repo)
    |> unsafe_validate_unique(:facebook_id, GameServer.Repo)
    |> unique_constraint(:email)
    |> unique_constraint(:facebook_id)
    |> put_change(:confirmed_at, DateTime.utc_now(:second))
  end

  @doc """
  A user changeset used for device-based logins where there is no email.

  Device users are created with optional display_name and metadata and are
  immediately confirmed so the SDK can receive tokens without email confirmation.
  """
  def device_changeset(user, attrs) do
    user
    |> cast(attrs, [:display_name, :metadata])
    |> validate_length(:display_name, min: 1, max: 80)
    |> put_change(:confirmed_at, DateTime.utc_now(:second))
  end

  @doc """
  Changeset used when a device_id is present (linking device_id to user).
  Ensures device_id is stored on user record and enforces uniqueness by DB
  constraint.
  """
  def attach_device_changeset(user, attrs) do
    user
    |> cast(attrs, [:device_id])
    |> validate_required([:device_id])
    |> unique_constraint(:device_id)
  end

  @doc """
  A user changeset for admin updates.
  """
  def admin_changeset(user, attrs) do
    user
    |> cast(attrs, [:is_admin, :metadata, :display_name])
    |> validate_required([:is_admin])
  end

  @doc """
  A simple changeset for updating a user's display name.
  """
  def display_name_changeset(user, attrs) do
    user
    |> cast(attrs, [:display_name])
    |> validate_required([:display_name])
    |> validate_length(:display_name, min: 1, max: 80)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%GameServer.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end
