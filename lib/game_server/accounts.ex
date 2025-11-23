defmodule GameServer.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias GameServer.Repo

  alias GameServer.Accounts.{User, UserToken, UserNotifier}

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: String.downcase(email))
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: String.downcase(email))
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    # Normalize keys to strings to match form submissions
    attrs = Map.new(attrs, fn {k, v} -> {to_string(k), v} end)

    # Check if this is the first user and make them admin
    is_first_user = Repo.aggregate(User, :count, :id) == 0
    attrs = if is_first_user, do: Map.put(attrs, "is_admin", true), else: attrs

    %User{}
    |> User.email_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Confirms a user's email by setting confirmed_at timestamp.

  ## Examples

      iex> confirm_user(user)
      {:ok, %User{}}

  """
  def confirm_user(user) do
    user
    |> User.confirm_changeset()
    |> Repo.update()
  end

  @doc """
  Finds a user by Discord ID or creates a new user from OAuth data.

  ## Examples

      iex> find_or_create_from_discord(%{discord_id: "123", email: "user@example.com"})
      {:ok, %User{}}

  """
  def find_or_create_from_discord(attrs) do
    find_or_create_from_oauth(
      attrs,
      :discord_id,
      &User.discord_oauth_changeset/2
    )
  end

  @doc """
  Finds a user by Apple ID or creates a new user from OAuth data.

  ## Examples

      iex> find_or_create_from_apple(%{apple_id: "123", email: "user@example.com"})
      {:ok, %User{}}

  """
  def find_or_create_from_apple(attrs) do
    find_or_create_from_oauth(
      attrs,
      :apple_id,
      &User.apple_oauth_changeset/2
    )
  end

  @doc """
  Finds a user by Google ID or creates a new user from OAuth data.

  ## Examples

      iex> find_or_create_from_google(%{google_id: "123", email: "user@example.com"})
      {:ok, %User{}}

  """
  def find_or_create_from_google(attrs) do
    find_or_create_from_oauth(
      attrs,
      :google_id,
      &User.google_oauth_changeset/2
    )
  end

  @doc """
  Finds a user by Facebook ID or creates a new user from OAuth data.

  ## Examples

      iex> find_or_create_from_facebook(%{facebook_id: "123", email: "user@example.com"})
      {:ok, %User{}}

  """
  def find_or_create_from_facebook(attrs) do
    find_or_create_from_oauth(
      attrs,
      :facebook_id,
      &User.facebook_oauth_changeset/2
    )
  end

  # Generic OAuth find or create helper
  defp find_or_create_from_oauth(attrs, provider_id_field, changeset_fn) do
    provider_id = Map.get(attrs, provider_id_field)
    email = Map.get(attrs, :email)

    cond do
      # User exists with this provider ID - update their info
      user = Repo.get_by(User, [{provider_id_field, provider_id}]) ->
        attrs = scrub_attrs_for_update(user, attrs, provider_id_field)

        user
        |> changeset_fn.(attrs)
        |> Repo.update()

      # User exists with this email but no provider ID - link provider account
      email != nil ->
        case Repo.get_by(User, email: email) do
          nil ->
            # Check if this is the first user and make them admin
            is_first_user = Repo.aggregate(User, :count, :id) == 0
            attrs = if is_first_user, do: Map.put(attrs, :is_admin, true), else: attrs

            # Drop nil/empty email so the changeset's update_change won't crash
            attrs =
              if Map.get(attrs, :email) in [nil, ""], do: Map.delete(attrs, :email), else: attrs

            %User{}
            |> changeset_fn.(attrs)
            |> Repo.insert()

          user ->
            attrs = scrub_attrs_for_update(user, attrs, provider_id_field)

            user
            |> changeset_fn.(attrs)
            |> Repo.update()
        end

      # New user - create from provider data
      true ->
        # Check if this is the first user and make them admin
        is_first_user = Repo.aggregate(User, :count, :id) == 0
        attrs = if is_first_user, do: Map.put(attrs, :is_admin, true), else: attrs

        # For new user creation when provider didn't return an email, avoid
        # passing a nil email into the changeset (update_change will crash).
        attrs = if Map.get(attrs, :email) in [nil, ""], do: Map.delete(attrs, :email), else: attrs

        %User{}
        |> changeset_fn.(attrs)
        |> Repo.insert()
    end
  end

  # When updating an existing user from provider data we should avoid
  # destructive changes:
  # - Do not overwrite an existing, non-empty email (email is used for
  #   password-login accounts and should be preserved when present).
  # - Only set provider avatar if the user's avatar field for that provider
  #   is empty — prefer not to clobber user-set values.
  defp scrub_attrs_for_update(user, attrs, _provider_id_field) do
    attrs = Map.new(attrs)

    # Remove email if user already has one
    attrs =
      if user.email && user.email != "" do
        Map.delete(attrs, :email)
      else
        attrs
      end

    # Only set provider avatar if user doesn't already have one
    # Store provider profile images/URLs in the generic `profile_url` field.
    provider_avatar_key = :profile_url

    if Map.get(user, provider_avatar_key) && Map.get(user, provider_avatar_key) != "" do
      Map.delete(attrs, provider_avatar_key)
    else
      attrs
    end
  end

  @doc """
  Link an OAuth provider to an existing user account. Updates the user
  via the provider's oauth changeset while being careful not to overwrite
  existing email or avatars.

  Example: link_account(user, %{discord_id: "123", profile_url: "https://..."}, :discord_id, &User.discord_oauth_changeset/2)
  """
  def link_account(%User{} = user, attrs, provider_id_field, changeset_fn) do
    attrs = scrub_attrs_for_update(user, attrs, provider_id_field)

    changeset = changeset_fn.(user, attrs)

    case Repo.update(changeset) do
      {:ok, user} ->
        {:ok, user}

      {:error, changeset} ->
        # If the update failed due to the provider ID being already taken,
        # return a conflict with the existing account so the UI can guide
        # the user (e.g., delete the other account or sign into it).
        provider_value = Map.get(attrs, provider_id_field)

        if provider_value do
          case Repo.get_by(User, [{provider_id_field, provider_value}]) do
            %User{} = other_user when other_user.id != user.id ->
              {:error, {:conflict, other_user}}

            _ ->
              {:error, changeset}
          end
        else
          {:error, changeset}
        end
    end
  end

  @doc """
  Unlink an OAuth provider from a user's account.

  provider should be one of :discord, :apple, :google, :facebook.
  This will return {:ok, user} when successful or {:error, reason}.

  Guard: we only allow unlinking when the user will still have at least
  one other social provider remaining. This prevents users losing all
  social logins unexpectedly.
  """
  def unlink_provider(%User{} = user, provider)
      when provider in [:discord, :apple, :google, :facebook] do
    provider_field = provider_field(provider)

    # Count remaining linked providers (only non-empty, non-nil strings)
    providers = [:discord_id, :apple_id, :google_id, :facebook_id]

    present =
      Enum.count(providers, fn f ->
        case Map.get(user, f) do
          v when is_binary(v) -> String.trim(v) != ""
          _ -> false
        end
      end)

    if present <= 1 do
      {:error, :last_provider}
    else
      changes = %{provider_field => nil}

      # If unlinking discord and profile_url is a discord CDN URL, clear it
      changes =
        if provider == :discord && user.profile_url &&
             String.contains?(user.profile_url, "cdn.discordapp.com/avatars") do
          Map.put(changes, :profile_url, nil)
        else
          changes
        end

      user
      |> Ecto.Changeset.change(changes)
      |> Repo.update()
    end
  end

  defp provider_field(:discord), do: :discord_id
  defp provider_field(:apple), do: :apple_id
  defp provider_field(:google), do: :google_id
  defp provider_field(:facebook), do: :facebook_id

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `GameServer.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `GameServer.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
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
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  @doc """
  Deletes a user and associated resources.

  Returns `{:ok, user}` on success or `{:error, changeset}` on failure.
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end
end
