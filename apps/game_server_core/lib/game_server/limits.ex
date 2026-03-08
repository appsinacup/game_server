defmodule GameServer.Limits do
  @moduledoc """
  Central module for configurable validation limits.

  All limits have sensible defaults and can be overridden at boot time via
  `config :game_server_core, GameServer.Limits, key: value` or at runtime
  via `Application.put_env(:game_server_core, GameServer.Limits, [...])`.

  ## Environment variables

  Each limit can be set via an environment variable. The env var name maps to
  the limit key with an uppercase `LIMIT_` prefix, e.g.:

      LIMIT_MAX_METADATA_SIZE=32768   -> :max_metadata_size
      LIMIT_MAX_PAGE_SIZE=100         -> :max_page_size

  Env vars are read once at boot in `config/runtime.exs`.

  ## Usage in schemas

      import GameServer.Limits, only: [get: 1, validate_metadata_size: 2]

      changeset
      |> validate_length(:title, max: GameServer.Limits.get(:max_group_title))
      |> validate_metadata_size(:metadata)

  ## Usage in controllers

      page_size = GameServer.Limits.clamp_page_size(params["page_size"])
  """

  @defaults %{
    # ── Global ──────────────────────────────────────────────
    max_metadata_size: 16_384,
    max_page_size: 100,

    # ── User ────────────────────────────────────────────────
    max_display_name: 80,
    max_email: 160,
    max_profile_url: 512,
    max_device_id: 256,

    # ── Groups ──────────────────────────────────────────────
    max_group_title: 80,
    max_group_description: 500,
    max_group_members: 10_000,
    max_groups_per_user: 50,
    max_groups_created_per_user: 20,
    max_group_pending_invites: 100,

    # ── Lobbies ─────────────────────────────────────────────
    max_lobby_title: 80,
    max_lobby_users: 128,
    max_lobby_password: 128,

    # ── Parties ─────────────────────────────────────────────
    max_party_size: 32,
    max_party_pending_invites: 20,

    # ── Chat ────────────────────────────────────────────────
    max_chat_content: 4_096,

    # ── Notifications ───────────────────────────────────────
    max_notification_title: 255,
    max_notification_content: 10_000,
    max_notifications_per_user: 500,

    # ── Friends ─────────────────────────────────────────────
    max_friends_per_user: 500,
    max_pending_friend_requests: 100,

    # ── Hooks ───────────────────────────────────────────────
    max_hook_args_size: 65_536,
    max_hook_args_count: 32,

    # ── KV ──────────────────────────────────────────────────
    max_kv_key: 512,
    max_kv_value_size: 65_536,
    max_kv_entries_per_user: 1_000,

    # ── Leaderboards ────────────────────────────────────────
    max_leaderboard_title: 255,
    max_leaderboard_description: 1_000,
    max_leaderboard_slug: 100
  }

  @doc """
  Returns a map of all limit keys and their current effective values.
  """
  @spec all() :: map()
  def all do
    overrides = Application.get_env(:game_server_core, __MODULE__, []) |> Map.new()
    Map.merge(@defaults, overrides)
  end

  @doc """
  Returns the current value for the given limit key.

  Reads from `Application.get_env(:game_server_core, GameServer.Limits)` first,
  falling back to the compiled default.
  """
  @spec get(atom()) :: integer() | any()
  def get(key) when is_atom(key) do
    overrides = Application.get_env(:game_server_core, __MODULE__, [])

    case Keyword.fetch(overrides, key) do
      {:ok, val} -> val
      :error -> Map.fetch!(@defaults, key)
    end
  end

  @doc """
  Returns the compiled defaults map. Useful for the admin UI to display
  defaults vs. overrides.
  """
  @spec defaults() :: map()
  def defaults, do: @defaults

  @doc """
  Clamps a raw page_size parameter to [1, max_page_size].
  Accepts nil, string, or integer. Returns integer.
  """
  @spec clamp_page_size(any(), integer()) :: integer()
  def clamp_page_size(raw, default \\ 25) do
    parsed =
      case raw do
        nil ->
          default

        val when is_integer(val) ->
          val

        val when is_binary(val) ->
          case Integer.parse(val) do
            {n, _} -> n
            :error -> default
          end

        _ ->
          default
      end

    max(1, min(parsed, get(:max_page_size)))
  end

  @doc """
  Clamps a raw page parameter to [1, ∞). Same parsing logic as page_size.
  """
  @spec clamp_page(any()) :: pos_integer()
  def clamp_page(raw) do
    parsed =
      case raw do
        nil ->
          1

        val when is_integer(val) ->
          val

        val when is_binary(val) ->
          case Integer.parse(val) do
            {n, _} -> n
            :error -> 1
          end

        _ ->
          1
      end

    max(1, parsed)
  end

  # ── Ecto Changeset Helpers ──────────────────────────────────

  @doc """
  Validates that a `:map` field, when serialized to JSON, does not exceed
  `max_metadata_size` bytes. Add this to any changeset that casts a metadata
  or arbitrary JSON map field.

      changeset
      |> validate_metadata_size(:metadata)
      |> validate_metadata_size(:value, :max_kv_value_size)
  """
  @spec validate_metadata_size(Ecto.Changeset.t(), atom(), atom()) :: Ecto.Changeset.t()
  def validate_metadata_size(changeset, field, limit_key \\ :max_metadata_size) do
    import Ecto.Changeset, only: [get_change: 2, add_error: 3]

    case get_change(changeset, field) do
      nil ->
        changeset

      value when is_map(value) ->
        max = get(limit_key)

        case Jason.encode(value) do
          {:ok, json} when byte_size(json) > max ->
            add_error(changeset, field, "is too large (max #{max} bytes)")

          _ ->
            changeset
        end

      _other ->
        changeset
    end
  end
end
