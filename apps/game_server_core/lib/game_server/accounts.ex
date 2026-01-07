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

  """

  import Ecto.Query, warn: false
  use Nebulex.Caching, cache: GameServer.Cache
  alias GameServer.Repo
  alias GameServer.Types

  alias GameServer.Accounts.{User, UserNotifier, UserToken}

  @stats_cache_ttl_ms 60_000
  @users_count_cache_ttl_ms 60_000

  defp users_stats_cache_version do
    GameServer.Cache.get({:accounts, :users_stats_version}) || 1
  end

  defp invalidate_users_stats_cache do
    GameServer.Async.run(fn ->
      _ = GameServer.Cache.incr({:accounts, :users_stats_version}, 1, default: 1)
      :ok
    end)

    :ok
  end

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  @spec get_user_by_email(String.t()) :: User.t() | nil
  def get_user_by_email(email) when is_binary(email) do
    normalized = email |> String.trim() |> String.downcase()

    if normalized == "" do
      nil
    else
      get_user_by_field(:email, normalized)
    end
  end

  @doc """
  Search users by email or display name (case-insensitive, partial match).

  Returns a list of User structs.

  ## Options

  See `t:GameServer.Types.pagination_opts/0` for available options.
  """
  @spec search_users(String.t()) :: [User.t()]
  @spec search_users(String.t(), Types.pagination_opts()) :: [User.t()]
  def search_users(query, opts \\ []) when is_binary(query) do
    q = String.trim(query)
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 25)

    if q == "" do
      []
    else
      # If query looks like an id, attempt a direct lookup first
      if Regex.match?(~r/^\d+$/, q) do
        id = String.to_integer(q)

        case get_user(id) do
          nil ->
            normalized_q = String.downcase(q)
            search_users_by_text(normalized_q, q, page, page_size)

          user ->
            [user]
        end
      else
        normalized_q = String.downcase(q)
        search_users_by_text(normalized_q, q, page, page_size)
      end
    end
  end

  defp search_users_by_text(normalized_q, q, page, page_size) do
    _ = q
    pattern = "#{normalized_q}%"
    offset = (page - 1) * page_size

    Repo.all(
      from u in User,
        where:
          like(u.email, ^pattern) or
            fragment("lower(?) LIKE ?", u.display_name, ^pattern),
        limit: ^page_size,
        offset: ^offset
    )
  end

  @doc """
  Count users matching a text query (email or display_name). Returns integer.
  """
  @spec count_search_users(String.t()) :: non_neg_integer()
  def count_search_users(query) when is_binary(query) do
    q = String.trim(query)

    if q == "" do
      0
    else
      if Regex.match?(~r/^\d+$/, q) do
        id = String.to_integer(q)

        case get_user(id) do
          nil ->
            normalized_q = String.downcase(q)
            count_search_users_by_text(normalized_q, q)

          _ ->
            1
        end
      else
        normalized_q = String.downcase(q)
        count_search_users_by_text(normalized_q, q)
      end
    end
  end

  defp count_search_users_by_text(normalized_q, q) do
    _ = q
    pattern = "#{normalized_q}%"

    Repo.one(
      from u in User,
        where:
          like(u.email, ^pattern) or
            fragment("lower(?) LIKE ?", u.display_name, ^pattern),
        select: count(u.id)
    ) || 0
  end

  @doc """
  Returns the total number of users.
  """
  @spec count_users() :: non_neg_integer()
  @decorate cacheable(key: {:accounts, :users_count}, opts: [ttl: @users_count_cache_ttl_ms])
  def count_users, do: Repo.aggregate(User, :count, :id)

  defp invalidate_users_count_cache do
    GameServer.Async.run(fn ->
      _ = GameServer.Cache.delete({:accounts, :users_count})
      :ok
    end)

    :ok
  end

  defp first_user? do
    Repo.aggregate(User, :count, :id) == 0
  end

  defp maybe_make_first_user_admin(changeset, true) do
    Ecto.Changeset.put_change(changeset, :is_admin, true)
  end

  defp maybe_make_first_user_admin(changeset, false), do: changeset

  @doc """
  Count users with non-empty provider id for a given provider field (e.g. :google_id)
  """
  @spec count_users_with_provider(atom()) :: non_neg_integer()
  def count_users_with_provider(provider_field) when is_atom(provider_field) do
    count_users_with_provider_cached(provider_field)
  end

  @decorate cacheable(
              key:
                {:accounts, :stats, users_stats_cache_version(), :users_with_provider,
                 provider_field},
              opts: [ttl: @stats_cache_ttl_ms]
            )
  defp count_users_with_provider_cached(provider_field) do
    Repo.one(
      from u in User,
        where: not is_nil(field(u, ^provider_field)) and field(u, ^provider_field) != "",
        select: count(u.id)
    ) || 0
  end

  @doc """
  Count users with a password set (hashed_password not nil/empty).
  """
  @spec count_users_with_password() :: non_neg_integer()
  def count_users_with_password do
    count_users_with_password_cached()
  end

  @decorate cacheable(
              key: {:accounts, :stats, users_stats_cache_version(), :users_with_password},
              opts: [ttl: @stats_cache_ttl_ms]
            )
  defp count_users_with_password_cached do
    Repo.one(
      from u in User,
        where: not is_nil(u.hashed_password) and u.hashed_password != "",
        select: count(u.id)
    ) || 0
  end

  @doc """
  Count users registered in the last N days.
  """
  @spec count_users_registered_since(integer()) :: non_neg_integer()
  def count_users_registered_since(days) when is_integer(days) do
    count_users_registered_since_cached(days)
  end

  @decorate cacheable(
              key:
                {:accounts, :stats, users_stats_cache_version(), :users_registered_since, days},
              opts: [ttl: @stats_cache_ttl_ms]
            )
  defp count_users_registered_since_cached(days) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days, :day)
    Repo.one(from u in User, where: u.inserted_at >= ^cutoff, select: count(u.id)) || 0
  end

  @doc """
  Count users active in the last N days.

  This metric is based on `users.updated_at` (any user record update,
  including registration/creation), so it reflects all users and not just
  session-token based authentication.
  """
  @spec count_users_active_since(integer()) :: non_neg_integer()
  def count_users_active_since(days) when is_integer(days) do
    count_users_active_since_cached(days)
  end

  @decorate cacheable(
              key: {:accounts, :stats, users_stats_cache_version(), :users_active_since, days},
              opts: [ttl: @stats_cache_ttl_ms]
            )
  defp count_users_active_since_cached(days) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days, :day)

    Repo.one(from u in User, where: u.updated_at >= ^cutoff, select: count(u.id)) || 0
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  @spec get_user_by_email_and_password(String.t(), String.t()) :: User.t() | nil
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = get_user_by_email(email)
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
  @spec get_user!(integer()) :: User.t()
  def get_user!(id) do
    case get_user(id) do
      %User{} = user ->
        user

      nil ->
        raise Ecto.NoResultsError, queryable: User
    end
  end

  @doc """
  Gets a single user by ID.

  Returns `nil` if the User does not exist.

  ## Examples

      iex> get_user(123)
      %User{}

      iex> get_user(456)
      nil

  """
  @spec get_user(integer()) :: User.t() | nil
  @decorate cacheable(key: {:accounts, :user, id}, match: &cache_match/1)
  def get_user(id), do: Repo.get(User, id)

  @decorate cacheable(
              key: {:accounts, :user_by, field, value},
              references: &(&1 && keyref({:accounts, :user, &1.id})),
              match: &cache_match/1
            )
  defp get_user_by_field(field, value) when is_atom(field) do
    Repo.get_by(User, [{field, value}])
  end

  @spec cache_match(term()) :: boolean()
  defp cache_match(nil), do: false
  defp cache_match(_), do: true

  @user_cache_fields [
    :email,
    :device_id,
    :steam_id,
    :google_id,
    :apple_id,
    :discord_id,
    :facebook_id
  ]

  defp user_index_keys(%User{} = user) do
    Enum.reduce(@user_cache_fields, [], fn field, acc ->
      value = Map.get(user, field)

      cond do
        is_binary(value) and String.trim(value) != "" and field == :email ->
          [{:accounts, :user_by, :email, String.downcase(value)} | acc]

        is_binary(value) and String.trim(value) != "" ->
          [{:accounts, :user_by, field, value} | acc]

        true ->
          acc
      end
    end)
  end

  defp invalidate_user_cache(%User{id: id} = user) do
    GameServer.Async.run(fn ->
      _ = GameServer.Cache.delete({:accounts, :user, id})

      user
      |> user_index_keys()
      |> Enum.each(fn key ->
        _ = GameServer.Cache.delete(key)
      end)

      :ok
    end)

    :ok
  end

  defp invalidate_user_cache_sync(%User{id: id} = user) do
    _ = GameServer.Cache.delete({:accounts, :user, id})

    user
    |> user_index_keys()
    |> Enum.each(fn key ->
      _ = GameServer.Cache.delete(key)
    end)

    :ok
  end

  ## User registration

  @doc """
  Registers a user.

  ## Attributes

  See `t:GameServer.Types.user_registration_attrs/0` for available fields.

  ## Examples

      iex> register_user(%{email: "user@example.com", password: "secret123"})
      {:ok, %User{}}

      iex> register_user(%{email: "invalid"})
      {:error, %Ecto.Changeset{}}

  """
  @spec register_user(Types.user_registration_attrs()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def register_user(attrs) do
    # Normalize keys to strings to match form submissions
    attrs = Map.new(attrs, fn {k, v} -> {to_string(k), v} end)

    # Check if this is the first user and make them admin
    is_first_user = first_user?()

    case %User{}
         |> User.email_changeset(attrs)
         |> maybe_attach_device(attrs)
         |> maybe_make_first_user_admin(is_first_user)
         |> Repo.insert() do
      {:ok, user} = ok ->
        invalidate_users_count_cache()

        GameServer.Async.run(fn ->
          GameServer.Hooks.internal_call(:after_user_register, [user])
        end)

        ok

      err ->
        err
    end
  end

  @doc """
  Register a user and send the confirmation email inside a DB transaction.

  The function accepts a `confirmation_url_fun` which must be a function of arity 1
  that receives the encoded token and returns the confirmation URL string.

  If sending the confirmation email fails the transaction is rolled back and
  `{:error, reason}` is returned. On success it returns `{:ok, user}`.
  """
  @spec register_user_and_deliver(Types.user_registration_attrs(), (String.t() -> String.t())) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t() | term()}
  @spec register_user_and_deliver(
          Types.user_registration_attrs(),
          (String.t() -> String.t()),
          module()
        ) :: {:ok, User.t()} | {:error, Ecto.Changeset.t() | term()}
  def register_user_and_deliver(
        attrs,
        confirmation_url_fun,
        notifier \\ GameServer.Accounts.UserNotifier
      )
      when is_function(confirmation_url_fun, 1) do
    # Normalize keys to strings to match form submissions
    attrs = Map.new(attrs, fn {k, v} -> {to_string(k), v} end)

    # Check if this is the first user and make them admin
    is_first_user = first_user?()

    transaction_fun = fn ->
      changeset =
        %User{}
        |> User.email_changeset(attrs)
        |> maybe_attach_device(attrs)
        |> maybe_make_first_user_admin(is_first_user)

      case Repo.insert(changeset) do
        {:ok, %User{} = user} ->
          case maybe_send_confirmation(user, is_first_user, notifier, confirmation_url_fun) do
            :ok -> user
            {:error, reason} -> Repo.rollback(reason)
          end

        {:error, %Ecto.Changeset{} = changeset} ->
          Repo.rollback(changeset)

        err ->
          Repo.rollback(err)
      end
    end

    case Repo.transaction(transaction_fun) do
      {:ok, %User{} = user} ->
        invalidate_users_count_cache()

        GameServer.Async.run(fn ->
          GameServer.Hooks.internal_call(:after_user_register, [user])
        end)

        {:ok, user}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_send_confirmation(_user, true, _notifier, _fun), do: :ok

  defp maybe_send_confirmation(user, false, notifier, confirmation_url_fun) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
    Repo.insert!(user_token)

    case notifier.deliver_confirmation_instructions(
           user,
           confirmation_url_fun.(encoded_token)
         ) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_attach_device(changeset, %{"device_id" => device_id}) when is_binary(device_id) do
    changeset
    |> Ecto.Changeset.put_change(:device_id, device_id)
  end

  defp maybe_attach_device(changeset, _), do: changeset

  @doc """
  Confirms a user's email by setting confirmed_at timestamp.

  ## Examples

      iex> confirm_user(user)
      {:ok, %User{}}

  """
  @spec confirm_user(User.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def confirm_user(user) do
    case user
         |> User.confirm_changeset()
         |> Repo.update() do
      {:ok, %User{} = updated} = ok ->
        invalidate_user_cache(user)
        invalidate_user_cache(updated)
        ok

      other ->
        other
    end
  end

  @doc """
  Confirm a user by an email confirmation token (context: "confirm").

  Returns {:ok, user} when the token is valid and user was confirmed.
  Returns {:error, :not_found} or {:error, :expired} when token is invalid/expired.
  """
  @spec confirm_user_by_token(String.t()) :: {:ok, User.t()} | {:error, :invalid | :not_found}
  def confirm_user_by_token(token) when is_binary(token) do
    with {:ok, decoded} <- Base.url_decode64(token, padding: false),
         hashed <- :crypto.hash(:sha256, decoded),
         {:ok, %User{} = user} <- fetch_user_for_confirm_token(hashed),
         {:ok, %User{} = confirmed_user} <- confirm_user_by_token_tx(user) do
      {:ok, get_user(confirmed_user.id)}
    else
      :error ->
        {:error, :invalid}

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, _} ->
        {:error, :not_found}
    end
  end

  defp fetch_user_for_confirm_token(hashed) do
    query =
      from t in UserToken,
        where: t.token == ^hashed and t.context == "confirm",
        where: t.inserted_at > ago(7, "day"),
        join: u in assoc(t, :user),
        select: {u, t}

    case Repo.one(query) do
      {%User{} = user, _token} -> {:ok, user}
      nil -> {:error, :not_found}
    end
  end

  defp confirm_user_by_token_tx(%User{} = user) do
    Repo.transaction(fn ->
      {:ok, confirmed_user} = confirm_user(user)

      Repo.delete_all(
        from(ut in UserToken, where: ut.user_id == ^confirmed_user.id and ut.context == "confirm")
      )

      confirmed_user
    end)
  end

  @doc """
  Finds a user by Discord ID or creates a new user from OAuth data.

  ## Examples

      iex> find_or_create_from_discord(%{discord_id: "123", email: "user@example.com"})
      {:ok, %User{}}

  """
  @spec find_or_create_from_discord(map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t() | term()}
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
  @spec find_or_create_from_apple(map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t() | term()}
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
  @spec find_or_create_from_google(map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t() | term()}
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
  @spec find_or_create_from_facebook(map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t() | term()}
  def find_or_create_from_facebook(attrs) do
    find_or_create_from_oauth(
      attrs,
      :facebook_id,
      &User.facebook_oauth_changeset/2
    )
  end

  @doc """
  Finds a user by Steam ID or creates a new user from Steam OpenID data.

  ## Examples

      iex> find_or_create_from_steam(%{steam_id: "12345", email: "user@example.com"})
      {:ok, %User{}}

  """
  @spec find_or_create_from_steam(map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t() | term()}
  def find_or_create_from_steam(attrs) do
    find_or_create_from_oauth(
      attrs,
      :steam_id,
      &User.steam_oauth_changeset/2
    )
  end

  @doc """
  Get a user by their Steam ID (steam_id).

  Returns `%User{}` or `nil`.
  """
  @spec get_user_by_steam_id(String.t()) :: User.t() | nil
  def get_user_by_steam_id(steam_id) when is_binary(steam_id) do
    get_user_by_field(:steam_id, steam_id)
  end

  @doc """
  Get a user by their Google ID.

  Returns `%User{}` or `nil`.
  """
  @spec get_user_by_google_id(String.t()) :: User.t() | nil
  def get_user_by_google_id(google_id) when is_binary(google_id) do
    get_user_by_field(:google_id, google_id)
  end

  @doc """
  Get a user by their Apple ID.

  Returns `%User{}` or `nil`.
  """
  @spec get_user_by_apple_id(String.t()) :: User.t() | nil
  def get_user_by_apple_id(apple_id) when is_binary(apple_id) do
    get_user_by_field(:apple_id, apple_id)
  end

  @doc """
  Get a user by their Discord ID.

  Returns `%User{}` or `nil`.
  """
  @spec get_user_by_discord_id(String.t()) :: User.t() | nil
  def get_user_by_discord_id(discord_id) when is_binary(discord_id) do
    get_user_by_field(:discord_id, discord_id)
  end

  @doc """
  Get a user by their Facebook ID.

  Returns `%User{}` or `nil`.
  """
  @spec get_user_by_facebook_id(String.t()) :: User.t() | nil
  def get_user_by_facebook_id(facebook_id) when is_binary(facebook_id) do
    get_user_by_field(:facebook_id, facebook_id)
  end

  defp get_user_by_device_id(device_id) when is_binary(device_id) do
    get_user_by_field(:device_id, device_id)
  end

  @doc """
  Finds or creates a user associated with the given device_id.

  If a user already exists with the device_id we return it. Otherwise we
  create an anonymous confirmed user and attach the device_id.
  """
  @spec find_or_create_from_device(String.t()) ::
          {:ok, User.t()} | {:error, :disabled | Ecto.Changeset.t() | term()}
  @spec find_or_create_from_device(String.t(), map()) ::
          {:ok, User.t()} | {:error, :disabled | Ecto.Changeset.t() | term()}
  def find_or_create_from_device(device_id, attrs \\ %{}) when is_binary(device_id) do
    unless device_auth_enabled?(), do: {:error, :disabled}

    case get_user_by_device_id(device_id) do
      %User{} = user ->
        {:ok, user}

      nil ->
        # Create a new anonymous user for the device. Allow callers to
        # specify optional display_name/metadata via attrs.
        attrs = Map.put_new(attrs, :display_name, nil)

        is_first_user = first_user?()

        case %User{}
             |> User.device_changeset(attrs)
             |> maybe_make_first_user_admin(is_first_user)
             |> User.attach_device_changeset(%{device_id: device_id})
             |> Repo.insert() do
          {:ok, user} = ok ->
            invalidate_users_count_cache()

            GameServer.Async.run(fn ->
              GameServer.Hooks.internal_call(:after_user_register, [user])
            end)

            ok

          err ->
            err
        end
    end
  end

  @doc """
  Attach a device_id to an existing user record. Returns {:ok, user} or
  {:error, changeset} if the device_id is already used.
  """
  @spec attach_device_to_user(User.t(), String.t()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def attach_device_to_user(%User{} = user, device_id) when is_binary(device_id) do
    case user
         |> User.attach_device_changeset(%{device_id: device_id})
         |> Repo.update() do
      {:ok, %User{} = updated} = ok ->
        invalidate_user_cache(user)
        invalidate_user_cache(updated)
        ok

      other ->
        other
    end
  end

  @doc """
  Returns true when device-based auth is enabled. This checks the
  application config `:game_server, :device_auth_enabled` and falls back
  to the environment variable `DEVICE_AUTH_ENABLED`. If neither
  is set, device auth is enabled by default.
  """
  @spec device_auth_enabled?() :: boolean()
  def device_auth_enabled? do
    case Application.get_env(:game_server_core, :device_auth_enabled) do
      nil ->
        case System.get_env("DEVICE_AUTH_ENABLED") do
          v when v in ["1", "true", "TRUE", "True"] -> true
          v when v in ["0", "false", "FALSE", "False"] -> false
          _ -> true
        end

      bool when is_boolean(bool) ->
        bool

      other ->
        # support string-like values in config
        case other do
          v when v in ["1", "true", "TRUE", "True"] -> true
          v when v in ["0", "false", "FALSE", "False"] -> false
          _ -> true
        end
    end
  end

  # Generic OAuth find or create helper
  defp find_or_create_from_oauth(attrs, provider_id_field, changeset_fn) do
    provider_id = Map.get(attrs, provider_id_field)
    email = Map.get(attrs, :email)

    cond do
      provider_id != nil ->
        handle_provider_id(provider_id, attrs, provider_id_field, changeset_fn)

      email != nil ->
        handle_by_email(email, attrs, provider_id_field, changeset_fn)

      true ->
        create_user_from_provider(attrs, changeset_fn)
    end
  end

  defp handle_provider_id(provider_id, attrs, provider_id_field, changeset_fn) do
    case get_user_by_field(provider_id_field, provider_id) do
      %User{} = user ->
        attrs = scrub_attrs_for_update(user, attrs, provider_id_field)

        case user
             |> changeset_fn.(attrs)
             |> Repo.update() do
          {:ok, %User{} = updated} = ok ->
            invalidate_user_cache(user)
            invalidate_user_cache(updated)
            ok

          other ->
            other
        end

      nil ->
        handle_provider_id_missing(attrs, provider_id_field, changeset_fn)
    end
  end

  defp handle_provider_id_missing(attrs, provider_id_field, changeset_fn) do
    email = Map.get(attrs, :email)

    if email do
      case get_user_by_email(email) do
        nil ->
          create_user_from_provider(attrs, changeset_fn)

        %User{} = user ->
          attrs = scrub_attrs_for_update(user, attrs, provider_id_field)

          case user
               |> changeset_fn.(attrs)
               |> Repo.update() do
            {:ok, %User{} = updated} = ok ->
              invalidate_user_cache(user)
              invalidate_user_cache(updated)
              ok

            other ->
              other
          end
      end
    else
      create_user_from_provider(attrs, changeset_fn)
    end
  end

  defp handle_by_email(email, attrs, provider_id_field, changeset_fn) do
    case get_user_by_email(email) do
      nil ->
        create_user_from_provider(attrs, changeset_fn)

      %User{} = user ->
        attrs = scrub_attrs_for_update(user, attrs, provider_id_field)

        case user |> changeset_fn.(attrs) |> Repo.update() do
          {:ok, %User{} = updated} = ok ->
            invalidate_user_cache(user)
            invalidate_user_cache(updated)
            ok

          other ->
            other
        end
    end
  end

  defp create_user_from_provider(attrs, changeset_fn) do
    # Check if this is the first user and make them admin
    is_first_user = first_user?()
    attrs = if is_first_user, do: Map.put(attrs, :is_admin, true), else: attrs

    # For new user creation when provider didn't return an email, avoid
    # passing a nil email into the changeset (update_change will crash).
    attrs = if Map.get(attrs, :email) in [nil, ""], do: Map.delete(attrs, :email), else: attrs

    case %User{} |> changeset_fn.(attrs) |> Repo.insert() do
      {:ok, user} = ok ->
        invalidate_users_count_cache()

        GameServer.Async.run(fn ->
          GameServer.Hooks.internal_call(:after_user_register, [user])
        end)

        ok

      err ->
        err
    end
  end

  # When updating an existing user from provider data we should avoid
  # destructive changes:
  # - Do not overwrite an existing, non-empty email (email is used for
  #   password-login accounts and should be preserved when present).
  # - Only set provider avatar if the user's avatar field for that provider
  #   is empty - prefer not to clobber user-set values.
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

    attrs =
      if Map.get(user, provider_avatar_key) && Map.get(user, provider_avatar_key) != "" do
        Map.delete(attrs, provider_avatar_key)
      else
        attrs
      end

    # Also avoid overwriting an existing explicit display_name set by the user.
    if Map.get(user, :display_name) && Map.get(user, :display_name) != "" do
      Map.delete(attrs, :display_name)
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
  @spec link_account(User.t(), map(), atom(), (User.t(), map() -> Ecto.Changeset.t())) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t() | {:conflict, User.t()}}
  def link_account(%User{} = user, attrs, provider_id_field, changeset_fn) do
    attrs = scrub_attrs_for_update(user, attrs, provider_id_field)

    changeset = changeset_fn.(user, attrs)

    case Repo.update(changeset) do
      {:ok, %User{} = updated_user} ->
        invalidate_user_cache(user)
        invalidate_user_cache(updated_user)
        invalidate_users_stats_cache()
        # Broadcast user update to user channel
        broadcast_user_update(updated_user)

        {:ok, updated_user}

      {:error, changeset} ->
        handle_link_error(user, attrs, provider_id_field, changeset)
    end
  end

  defp handle_link_error(user, attrs, provider_id_field, changeset) do
    # If the update failed due to the provider ID being already taken,
    # return a conflict with the existing account so the UI can guide
    # the user (e.g., delete the other account or sign into it).
    provider_value = Map.get(attrs, provider_id_field)

    if provider_value do
      case get_user_by_field(provider_id_field, provider_value) do
        %User{} = other_user when other_user.id != user.id ->
          {:error, {:conflict, other_user}}

        _ ->
          {:error, changeset}
      end
    else
      {:error, changeset}
    end
  end

  @doc """
  Link a device_id to an existing user account. This allows the user to
  authenticate using the device_id in addition to their OAuth providers.

  Returns {:ok, user} on success or {:error, changeset} if the device_id
  is already used by another account.
  """
  @spec link_device_id(User.t(), String.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def link_device_id(%User{} = user, device_id) when is_binary(device_id) do
    changeset = User.attach_device_changeset(user, %{device_id: device_id})

    case Repo.update(changeset) do
      {:ok, %User{} = updated_user} ->
        invalidate_user_cache(user)
        invalidate_user_cache(updated_user)
        invalidate_users_stats_cache()
        # Broadcast user update to user channel
        broadcast_user_update(updated_user)
        {:ok, updated_user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Unlink the device_id from a user's account.

  Returns {:ok, user} when successful or {:error, reason}.

  Guard: we only allow unlinking when the user will still have at least
  one authentication method remaining (OAuth provider or password).
  This prevents users losing all login methods unexpectedly.
  """
  @spec unlink_device_id(User.t()) ::
          {:ok, User.t()} | {:error, :last_auth_method | Ecto.Changeset.t()}
  def unlink_device_id(%User{} = user) do
    # If device_id is already nil, just return success
    if user.device_id in [nil, ""] do
      {:ok, user}
    else
      # Check if user has at least one OAuth provider or password
      providers = [:discord_id, :apple_id, :google_id, :facebook_id, :steam_id]

      has_provider =
        Enum.any?(providers, fn f ->
          case Map.get(user, f) do
            v when is_binary(v) -> String.trim(v) != ""
            _ -> false
          end
        end)

      has_password = has_password?(user)

      if has_provider or has_password do
        changes = %{device_id: nil}

        case user |> Ecto.Changeset.change(changes) |> Repo.update() do
          {:ok, %User{} = updated_user} ->
            invalidate_user_cache(user)
            invalidate_user_cache(updated_user)
            invalidate_users_stats_cache()
            # Broadcast user update to user channel
            broadcast_user_update(updated_user)
            {:ok, updated_user}

          {:error, changeset} ->
            {:error, changeset}
        end
      else
        {:error, :last_auth_method}
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
  @spec unlink_provider(User.t(), :discord | :apple | :google | :facebook | :steam) ::
          {:ok, User.t()} | {:error, :last_provider | Ecto.Changeset.t() | term()}
  def unlink_provider(%User{} = user, provider)
      when provider in [:discord, :apple, :google, :facebook, :steam] do
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

      case user
           |> Ecto.Changeset.change(changes)
           |> Repo.update() do
        {:ok, updated_user} ->
          invalidate_user_cache(user)
          invalidate_user_cache(updated_user)
          invalidate_users_stats_cache()
          # Broadcast user update to user channel
          broadcast_user_update(updated_user)
          {:ok, updated_user}

        error ->
          error
      end
    end
  end

  defp provider_field(:discord), do: :discord_id
  defp provider_field(:apple), do: :apple_id
  defp provider_field(:google), do: :google_id
  defp provider_field(:facebook), do: :facebook_id
  defp provider_field(:steam), do: :steam_id

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  @spec sudo_mode?(User.t()) :: boolean()
  @spec sudo_mode?(User.t(), integer()) :: boolean()
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
  @spec change_user_email(User.t()) :: Ecto.Changeset.t()
  @spec change_user_email(User.t(), map()) :: Ecto.Changeset.t()
  @spec change_user_email(User.t(), map(), keyword()) :: Ecto.Changeset.t()
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  @spec update_user_email(User.t(), String.t()) ::
          {:ok, User.t()} | {:error, :transaction_aborted}
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, updated_user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(
               from(UserToken, where: [user_id: ^updated_user.id, context: ^context])
             ) do
        invalidate_user_cache(user)
        invalidate_user_cache(updated_user)
        {:ok, updated_user}
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
  @spec change_user_password(User.t()) :: Ecto.Changeset.t()
  @spec change_user_password(User.t(), map()) :: Ecto.Changeset.t()
  @spec change_user_password(User.t(), map(), keyword()) :: Ecto.Changeset.t()
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
  @spec update_user_password(User.t(), map()) ::
          {:ok, {User.t(), [UserToken.t()]}} | {:error, Ecto.Changeset.t()}
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  @spec generate_user_session_token(User.t()) :: binary()
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  @spec get_user_by_session_token(binary()) :: {User.t(), DateTime.t()} | nil
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user with the given magic link token.
  """
  @spec get_user_by_magic_link_token(String.t()) :: User.t() | nil
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
  @spec login_user_by_magic_link(String.t()) ::
          {:ok, {User.t(), [UserToken.t()]}} | {:error, :not_found | Ecto.Changeset.t() | term()}
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when hash != nil ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%User{confirmed_at: nil} = user, _token} ->
        handle_unconfirmed_login(user)

      {user, token} ->
        Repo.delete!(token)
        GameServer.Async.run(fn -> GameServer.Hooks.internal_call(:after_user_login, [user]) end)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  defp handle_unconfirmed_login(user) do
    result =
      user
      |> User.confirm_changeset()
      |> update_user_and_delete_all_tokens()

    case result do
      {:ok, {user, _tokens}} = ok ->
        GameServer.Async.run(fn -> GameServer.Hooks.internal_call(:after_user_login, [user]) end)
        ok

      other ->
        other
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  @spec deliver_user_update_email_instructions(
          User.t(),
          String.t(),
          (String.t() -> String.t())
        ) :: {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given user.
  """
  @spec deliver_login_instructions(User.t(), (String.t() -> String.t())) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  @spec delete_user_session_token(binary()) :: :ok
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  @doc false
  @spec get_user_token(integer()) :: UserToken.t() | nil
  @decorate cacheable(
              key: {:accounts, :user_token, id},
              match: &cache_match/1,
              opts: [ttl: 60_000]
            )
  def get_user_token(id) when is_integer(id) do
    Repo.get(UserToken, id)
  end

  @doc false
  @spec get_user_token!(integer()) :: UserToken.t()
  def get_user_token!(id) when is_integer(id) do
    case get_user_token(id) do
      %UserToken{} = token -> token
      nil -> raise Ecto.NoResultsError, queryable: UserToken
    end
  end

  @doc false
  @spec delete_user_token(UserToken.t()) :: {:ok, UserToken.t()} | {:error, Ecto.Changeset.t()}
  def delete_user_token(%UserToken{} = token) do
    case Repo.delete(token) do
      {:ok, _} = ok ->
        _ = GameServer.Cache.delete({:accounts, :user_token, token.id})
        ok

      other ->
        other
    end
  end

  @doc """
  Deletes a user and associated resources.

  Returns `{:ok, user}` on success or `{:error, changeset}` on failure.
  """
  alias GameServer.Lobbies

  @spec delete_user(User.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def delete_user(%User{} = user) do
    # Best-effort: try to remove the user from any lobby they may belong to,
    # then delete the user regardless of hook checks (hooks for deletion were removed).
    try do
      _ = Lobbies.leave_lobby(user)
    rescue
      _ -> :ok
    end

    case Repo.delete(user) do
      {:ok, _user} = ok ->
        invalidate_users_count_cache()

        # Deleting cache entries asynchronously can cause a short-lived race where
        # a delete followed immediately by a device login sees a stale cached user
        # for the same device_id/email and skips the "create" code path.
        invalidate_user_cache_sync(user)
        ok

      err ->
        err
    end

    # end delete_user
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        invalidate_user_cache(user)
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end

  @doc """
  Broadcast that the given user has been updated.

  This helper is intentionally small and only broadcasts a compact payload
  intended for client consumption through the `user:<id>` topic.
  """
  @spec broadcast_user_update(User.t()) :: :ok
  def broadcast_user_update(%User{} = user) do
    payload = %{
      id: user.id,
      email: user.email || "",
      profile_url: user.profile_url || "",
      metadata: user.metadata || %{},
      display_name: user.display_name || "",
      lobby_id: user.lobby_id || -1,
      linked_providers: get_linked_providers(user),
      has_password: has_password?(user)
    }

    topic = "user:#{user.id}"

    Phoenix.PubSub.broadcast(
      GameServer.PubSub,
      topic,
      %Phoenix.Socket.Broadcast{topic: topic, event: "updated", payload: payload}
    )

    :ok
  end

  @doc """
  Returns a map of linked OAuth providers for the user.

  Each provider is a boolean indicating whether that provider is linked.
  """
  @spec get_linked_providers(User.t()) :: %{
          google: boolean(),
          facebook: boolean(),
          discord: boolean(),
          apple: boolean(),
          steam: boolean(),
          device: boolean()
        }
  def get_linked_providers(%User{} = user) do
    %{
      google: user.google_id != nil,
      facebook: user.facebook_id != nil,
      discord: user.discord_id != nil,
      apple: user.apple_id != nil,
      steam: user.steam_id != nil,
      device: user.device_id != nil
    }
  end

  @doc """
  Returns whether the user has a password set.
  """
  @spec has_password?(User.t()) :: boolean()
  def has_password?(%User{} = user) do
    user.hashed_password != nil
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user display_name.
  """
  @spec change_user_display_name(User.t()) :: Ecto.Changeset.t()
  @spec change_user_display_name(User.t(), map()) :: Ecto.Changeset.t()
  def change_user_display_name(user, attrs \\ %{}) do
    User.display_name_changeset(user, attrs)
  end

  @doc """
  Updates the user's display name and broadcasts the change.
  """
  @spec update_user_display_name(User.t(), map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user_display_name(%User{} = user, attrs) do
    case User.display_name_changeset(user, attrs) |> Repo.update() do
      {:ok, updated} = ok ->
        invalidate_user_cache(user)
        invalidate_user_cache(updated)
        broadcast_user_update(updated)
        ok

      err ->
        err
    end
  end

  @doc """
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
  @spec update_user(User.t(), Types.user_update_attrs()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user(%User{} = user, attrs) when is_map(attrs) do
    case User.admin_changeset(user, attrs) |> Repo.update() do
      {:ok, updated} = ok ->
        invalidate_user_cache(user)
        invalidate_user_cache(updated)
        invalidate_users_stats_cache()
        # Broadcast updates so realtime clients can react
        broadcast_user_update(updated)
        ok

      other ->
        other
    end
  end

  @spec change_user_registration(User.t()) :: Ecto.Changeset.t()
  @spec change_user_registration(User.t(), map()) :: Ecto.Changeset.t()
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, [])
  end

  @spec deliver_user_confirmation_instructions(User.t(), (String.t() -> String.t())) ::
          {:ok, Swoosh.Email.t()} | {:error, :already_confirmed | term()}
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)

      UserNotifier.deliver_confirmation_instructions(
        user,
        confirmation_url_fun.(encoded_token)
      )
    end
  end
end
