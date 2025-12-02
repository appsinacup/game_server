defmodule GameServer.Types do
  @moduledoc """
  Shared types used across GameServer contexts.

  These types provide self-documenting function signatures for common
  patterns like pagination options and entity attributes.
  """

  # ---------------------------------------------------------------------------
  # Pagination
  # ---------------------------------------------------------------------------

  @typedoc """
  Pagination options for list queries.

  ## Options

    * `:page` - The page number (1-indexed). Defaults to `1`.
    * `:page_size` - Number of items per page. Defaults to `25`.

  ## Example

      # Get the first page with default size
      list_users([])

      # Get page 2 with 50 items per page
      list_users(page: 2, page_size: 50)

  """
  @type pagination_opts :: [page: pos_integer(), page_size: pos_integer()]

  @typedoc """
  Lobby listing options for filtering and pagination.

  ## Options

    * `:page` - The page number (1-indexed). Defaults to `nil` (returns all).
    * `:page_size` - Number of items per page. Defaults to `25`.
    * `:include_hidden` - Include hidden lobbies in results. Defaults to `false`.

  ## Example

      # List all visible lobbies
      list_lobbies([])

      # List page 1 including hidden lobbies
      list_lobbies(page: 1, include_hidden: true)

  """
  @type lobby_list_opts :: [
          page: pos_integer() | nil,
          page_size: pos_integer(),
          include_hidden: boolean()
        ]

  # ---------------------------------------------------------------------------
  # User Attributes
  # ---------------------------------------------------------------------------

  @typedoc """
  Attributes for registering a new user.

  ## Fields

    * `:email` - User's email address (required for email registration)
    * `:password` - User's password (required for email registration, min 8 chars)
    * `:display_name` - Optional display name
    * `:device_id` - Optional device ID for anonymous auth

  ## Example

      register_user(%{
        email: "user@example.com",
        password: "secret123",
        display_name: "Player One"
      })

  """
  @type user_registration_attrs :: %{
          optional(:email) => String.t(),
          optional(:password) => String.t(),
          optional(:display_name) => String.t(),
          optional(:device_id) => String.t()
        }

  @typedoc """
  Attributes for updating an existing user.

  ## Fields

    * `:display_name` - User's display name
    * `:metadata` - Arbitrary key-value data stored with the user
    * `:is_admin` - Whether the user has admin privileges

  ## Example

      update_user(user, %{
        display_name: "New Name",
        metadata: %{level: 5, xp: 1200}
      })

  """
  @type user_update_attrs :: %{
          optional(:display_name) => String.t() | nil,
          optional(:metadata) => map(),
          optional(:is_admin) => boolean()
        }

  # ---------------------------------------------------------------------------
  # Leaderboard Attributes
  # ---------------------------------------------------------------------------

  @typedoc """
  Attributes for creating a new leaderboard.

  ## Fields

    * `:id` - Unique string identifier (required, 1-100 chars)
    * `:title` - Display title (required, 1-255 chars)
    * `:description` - Optional description
    * `:sort_order` - `:desc` (higher is better) or `:asc` (lower is better). Default: `:desc`
    * `:operator` - How scores are combined:
      * `:set` - Always replace with new score
      * `:best` - Only update if new score is better (default)
      * `:incr` - Add to existing score
      * `:decr` - Subtract from existing score
    * `:starts_at` - Optional start time (UTC)
    * `:ends_at` - Optional end time (UTC)
    * `:metadata` - Arbitrary key-value data

  ## Example

      create_leaderboard(%{
        id: "weekly_kills_w49",
        title: "Weekly Kills - Week 49",
        sort_order: :desc,
        operator: :incr,
        ends_at: ~U[2024-12-08 00:00:00Z]
      })

  """
  @type leaderboard_create_attrs :: %{
          required(:id) => String.t(),
          required(:title) => String.t(),
          optional(:description) => String.t(),
          optional(:sort_order) => :desc | :asc,
          optional(:operator) => :set | :best | :incr | :decr,
          optional(:starts_at) => DateTime.t(),
          optional(:ends_at) => DateTime.t(),
          optional(:metadata) => map()
        }

  @typedoc """
  Attributes for updating an existing leaderboard.

  Note: `id`, `sort_order`, and `operator` cannot be changed after creation.

  ## Fields

    * `:title` - Display title (1-255 chars)
    * `:description` - Description text
    * `:starts_at` - Start time (UTC)
    * `:ends_at` - End time (UTC)
    * `:metadata` - Arbitrary key-value data

  ## Example

      update_leaderboard(leaderboard, %{
        title: "Updated Title",
        ends_at: ~U[2024-12-15 00:00:00Z]
      })

  """
  @type leaderboard_update_attrs :: %{
          optional(:title) => String.t(),
          optional(:description) => String.t(),
          optional(:starts_at) => DateTime.t(),
          optional(:ends_at) => DateTime.t(),
          optional(:metadata) => map()
        }

  # ---------------------------------------------------------------------------
  # Lobby Attributes
  # ---------------------------------------------------------------------------

  @typedoc """
  Attributes for creating a new lobby.

  ## Fields

    * `:name` - Unique identifier/slug (required)
    * `:title` - Display title (required)
    * `:max_users` - Maximum number of users allowed (default: 10)
    * `:is_hidden` - Whether lobby is hidden from public lists (default: false)
    * `:is_locked` - Whether lobby is locked from new joins (default: false)
    * `:password` - Optional password for protected lobbies
    * `:hostless` - Whether lobby can exist without a host (default: false)
    * `:metadata` - Arbitrary key-value data

  ## Example

      create_lobby(user, %{
        name: "my-game-room",
        title: "My Game Room",
        max_users: 4,
        password: "secret"
      })

  """
  @type lobby_create_attrs :: %{
          required(:name) => String.t(),
          required(:title) => String.t(),
          optional(:max_users) => pos_integer(),
          optional(:is_hidden) => boolean(),
          optional(:is_locked) => boolean(),
          optional(:password) => String.t(),
          optional(:hostless) => boolean(),
          optional(:metadata) => map()
        }

  @typedoc """
  Attributes for updating an existing lobby.

  ## Fields

    * `:title` - Display title
    * `:max_users` - Maximum number of users allowed
    * `:is_hidden` - Whether lobby is hidden from public lists
    * `:is_locked` - Whether lobby is locked from new joins
    * `:password` - Password for protected lobbies (set to nil to remove)
    * `:metadata` - Arbitrary key-value data

  ## Example

      update_lobby(lobby, user, %{
        title: "New Title",
        is_locked: true
      })

  """
  @type lobby_update_attrs :: %{
          optional(:title) => String.t(),
          optional(:max_users) => pos_integer(),
          optional(:is_hidden) => boolean(),
          optional(:is_locked) => boolean(),
          optional(:password) => String.t() | nil,
          optional(:metadata) => map()
        }
end
