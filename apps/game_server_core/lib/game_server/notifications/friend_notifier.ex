defmodule GameServer.Notifications.FriendNotifier do
  @moduledoc """
  Subscribes to the global `"friends"` PubSub topic and automatically creates
  notifications for key friend events:

  - **Incoming friend request** → notifies the target user
  - **Friend request accepted** → notifies the requester

  This GenServer runs as part of the supervision tree and creates persistent
  notifications via `Notifications.admin_create_notification/3` so they are
  delivered even when the recipient is offline.
  """

  use GenServer

  alias GameServer.Notifications

  # ── Public API ──────────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # ── GenServer callbacks ─────────────────────────────────────────────────────

  # In test environment, we skip the FriendNotifier to avoid Ecto sandbox
  # ownership issues. Friend notifications are tested via the Notifications
  # context directly.
  @skip_in_test Application.compile_env(:game_server_core, GameServer.Repo)[:pool] ==
                  Ecto.Adapters.SQL.Sandbox

  @impl true
  def init(_opts) do
    if @skip_in_test do
      :ignore
    else
      Phoenix.PubSub.subscribe(GameServer.PubSub, "friends")
      {:ok, %{}}
    end
  end

  @impl true
  def handle_info({:friend_created, friendship}, state) do
    # A new friend request was created: notify the target
    Notifications.admin_create_notification(
      friendship.requester_id,
      friendship.target_id,
      %{
        "title" => "Friend request",
        "content" => "You have a new friend request.",
        "metadata" => %{"type" => "friend_request", "friendship_id" => friendship.id}
      }
    )

    {:noreply, state}
  end

  @impl true
  def handle_info({:friend_accepted, friendship}, state) do
    # Friend request was accepted: notify the requester
    Notifications.admin_create_notification(
      friendship.target_id,
      friendship.requester_id,
      %{
        "title" => "Friend request accepted",
        "content" => "Your friend request has been accepted.",
        "metadata" => %{"type" => "friend_accepted", "friendship_id" => friendship.id}
      }
    )

    {:noreply, state}
  end

  # Ignore other friend events (rejected, blocked, removed, etc.)
  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
