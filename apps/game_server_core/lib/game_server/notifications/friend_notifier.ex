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
    requester_name = user_display_name(friendship.requester_id)

    Notifications.admin_create_notification(
      friendship.requester_id,
      friendship.target_id,
      %{
        "title" => "#{requester_name} sent you a friend request",
        "content" => "",
        "metadata" => %{"type" => "friend_request", "friendship_id" => friendship.id}
      }
    )

    {:noreply, state}
  end

  @impl true
  def handle_info({:friend_accepted, friendship}, state) do
    target_name = user_display_name(friendship.target_id)

    Notifications.admin_create_notification(
      friendship.target_id,
      friendship.requester_id,
      %{
        "title" => "#{target_name} accepted your friend request",
        "content" => "",
        "metadata" => %{"type" => "friend_accepted", "friendship_id" => friendship.id}
      }
    )

    {:noreply, state}
  end

  @impl true
  def handle_info({:request_cancelled, friendship}, state) do
    requester_name = user_display_name(friendship.requester_id)

    Notifications.delete_notification_by(
      friendship.requester_id,
      friendship.target_id,
      "#{requester_name} sent you a friend request"
    )

    {:noreply, state}
  end

  @impl true
  def handle_info({:friend_rejected, friendship}, state) do
    requester_name = user_display_name(friendship.requester_id)
    target_name = user_display_name(friendship.target_id)

    Notifications.delete_notification_by(
      friendship.requester_id,
      friendship.target_id,
      "#{requester_name} sent you a friend request"
    )

    Notifications.admin_create_notification(
      friendship.target_id,
      friendship.requester_id,
      %{
        "title" => "#{target_name} declined your friend request",
        "content" => "",
        "metadata" => %{"type" => "friend_declined", "friendship_id" => friendship.id}
      }
    )

    {:noreply, state}
  end

  # Ignore other friend events (blocked, removed, etc.)
  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp user_display_name(user_id) do
    case GameServer.Accounts.get_user(user_id) do
      %{display_name: name} when is_binary(name) and name != "" -> name
      _ -> "User ##{user_id}"
    end
  end
end
