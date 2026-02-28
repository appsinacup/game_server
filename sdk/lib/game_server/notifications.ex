defmodule GameServer.Notifications do
  @moduledoc ~S"""
  Notifications context – create, list, and delete persisted user-to-user
  notifications.
  
  Notifications can only be sent to accepted friends. They are stored in the
  database so that recipients receive them even when offline. On WebSocket
  connect the client gets all undeleted notifications (ordered by timestamp).
  New notifications are also pushed in real-time via PubSub.
  
  ## PubSub Events
  
  This module broadcasts to the `"notifications:user:<user_id>"` topic:
  
  - `{:new_notification, notification}` – a new notification was created
  
  ## Usage
  
      # Send a notification to a friend
      {:ok, notification} = Notifications.send_notification(sender_id, %{
        "user_id" => recipient_id,
        "title" => "Game invite",
        "content" => "Join my lobby!",
        "metadata" => %{"lobby_id" => 42}
      })
  
      # List all notifications for a user (ordered oldest-first)
      notifications = Notifications.list_notifications(user_id)
  
      # Delete notifications by IDs (only owner can delete)
      {deleted_count, nil} = Notifications.delete_notifications(user_id, [1, 2, 3])
  
      # Count notifications for a user
      count = Notifications.count_notifications(user_id)
  

  **Note:** This is an SDK stub. Calling these functions will raise an error.
  The actual implementation runs on the GameServer.
  """

  @type user_id() :: integer()

  @doc ~S"""
    Admin: create a notification from any sender to any recipient (no friendship check).
    
  """
  @spec admin_create_notification(user_id(), user_id(), map()) ::
  {:ok, GameServer.Notifications.Notification.t()} | {:error, Ecto.Changeset.t() | atom()}
  def admin_create_notification(_sender_id, _recipient_id, _attrs) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.Notifications.admin_create_notification/3 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Admin: delete a single notification by ID (no ownership check).
  """
  @spec admin_delete_notification(integer()) ::
  {:ok, GameServer.Notifications.Notification.t()} | {:error, term()}
  def admin_delete_notification(_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.Notifications.admin_delete_notification/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Count all notifications matching the given filters (admin).
  """
  @spec count_all_notifications(map()) :: non_neg_integer()
  def count_all_notifications(_filters) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        0

      _ ->
        raise "GameServer.Notifications.count_all_notifications/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Count total notifications for a user.
  """
  @spec count_notifications(user_id()) :: non_neg_integer()
  def count_notifications(_user_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        0

      _ ->
        raise "GameServer.Notifications.count_notifications/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Delete notifications by IDs, scoped to the recipient (owner).
    
    Only notifications belonging to `user_id` will be deleted.
    Returns `{deleted_count, nil}`.
    
  """
  @spec delete_notifications(user_id(), [integer()]) :: {non_neg_integer(), nil}
  def delete_notifications(_user_id, _ids) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        0

      _ ->
        raise "GameServer.Notifications.delete_notifications/2 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Get a single notification by ID.
  """
  @spec get_notification(integer()) :: GameServer.Notifications.Notification.t() | nil
  def get_notification(_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        nil

      _ ->
        raise "GameServer.Notifications.get_notification/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Get a single notification by ID (raises if not found).
  """
  @spec get_notification!(integer()) :: GameServer.Notifications.Notification.t()
  def get_notification!(_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        nil

      _ ->
        raise "GameServer.Notifications.get_notification!/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    List all notifications (admin), with optional filters.
    
    ## Filters (map with string keys)
    
    - `"recipient_id"` / `"user_id"` – filter by recipient user ID
    - `"sender_id"` – filter by sender user ID
    - `"title"` – partial (LIKE) match on title
    
    ## Options
    
    - `:page` – page number (default 1)
    - `:page_size` – results per page (default 25)
    
  """
  @spec list_all_notifications(
  map(),
  keyword()
) :: [GameServer.Notifications.Notification.t()]
  def list_all_notifications(_filters, _opts) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        []

      _ ->
        raise "GameServer.Notifications.list_all_notifications/2 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    List all notifications for a user, ordered oldest-first so the client
    receives them in chronological order.
    
    Supports pagination via `:page` and `:page_size` options.
    
  """
  @spec list_notifications(
  user_id(),
  keyword()
) :: [GameServer.Notifications.Notification.t()]
  def list_notifications(_user_id, _opts) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        []

      _ ->
        raise "GameServer.Notifications.list_notifications/2 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Send a notification to a friend.
    
    `sender_id` is the authenticated user. `attrs` must include:
    - `"user_id"` or `"recipient_id"` – the target friend's user ID
    - `"title"` – required
    - `"content"` – optional
    - `"metadata"` – optional map
    
    Returns `{:error, :not_friends}` when the target is not an accepted friend.
    
  """
  @spec send_notification(user_id(), map()) ::
  {:ok, GameServer.Notifications.Notification.t()} | {:error, Ecto.Changeset.t() | atom()}
  def send_notification(_sender_id, _attrs) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.Notifications.send_notification/2 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Subscribe to notification events for a specific user.
  """
  @spec subscribe(user_id()) :: :ok | {:error, term()}
  def subscribe(_user_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        :ok

      _ ->
        raise "GameServer.Notifications.subscribe/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Unsubscribe from notification events for a specific user.
  """
  @spec unsubscribe(user_id()) :: :ok
  def unsubscribe(_user_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        :ok

      _ ->
        raise "GameServer.Notifications.unsubscribe/1 is a stub - only available at runtime on GameServer"
    end
  end

end
