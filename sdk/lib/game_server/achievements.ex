defmodule GameServer.Achievements do
  @moduledoc ~S"""
  The Achievements context.
  
  Manages achievement definitions and user progress/unlocks.
  
  ## Usage
  
      # Create an achievement (admin)
      {:ok, ach} = Achievements.create_achievement(%{
        slug: "first_lobby",
        title: "Welcome!",
        description: "Join your first lobby",
        progress_target: 1
      })
  
      # Unlock a one-shot achievement
      {:ok, ua} = Achievements.unlock_achievement(user_id, "first_lobby")
  
      # Increment progress on a multi-step achievement
      {:ok, ua} = Achievements.increment_progress(user_id, "chat_100", 1)
      # auto-unlocks when progress >= progress_target
  
      # List achievements (with user progress if user_id provided)
      achievements = Achievements.list_achievements(user_id: user_id, page: 1, page_size: 25)
  

  **Note:** This is an SDK stub. Calling these functions will raise an error.
  The actual implementation runs on the GameServer.
  """



  @doc ~S"""
    Returns a changeset for tracking achievement changes (used by forms).
  """
  @spec change_achievement(GameServer.Achievements.Achievement.t()) :: Ecto.Changeset.t()
  def change_achievement(_achievement) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        nil

      _ ->
        raise "GameServer.Achievements.change_achievement/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Returns a changeset for tracking achievement changes (used by forms).
  """
  @spec change_achievement(GameServer.Achievements.Achievement.t(), map()) :: Ecto.Changeset.t()
  def change_achievement(_achievement, _attrs) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        nil

      _ ->
        raise "GameServer.Achievements.change_achievement/2 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Count achievements (for pagination). Supports `:include_hidden`, `:filter`, and `:user_id`.
  """
  @spec count_achievements() :: non_neg_integer()
  def count_achievements() do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        0

      _ ->
        raise "GameServer.Achievements.count_achievements/0 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Count achievements (for pagination). Supports `:include_hidden`, `:filter`, and `:user_id`.
  """
  @spec count_achievements(keyword()) :: non_neg_integer()
  def count_achievements(_opts) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        0

      _ ->
        raise "GameServer.Achievements.count_achievements/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Count all achievements (including hidden), for admin dashboard.
  """
  @spec count_all_achievements() :: non_neg_integer()
  def count_all_achievements() do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        0

      _ ->
        raise "GameServer.Achievements.count_all_achievements/0 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Count all user achievement unlock records.
  """
  @spec count_all_unlocks() :: non_neg_integer()
  def count_all_unlocks() do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        0

      _ ->
        raise "GameServer.Achievements.count_all_unlocks/0 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Count hidden achievements.
  """
  @spec count_hidden_achievements() :: non_neg_integer()
  def count_hidden_achievements() do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        0

      _ ->
        raise "GameServer.Achievements.count_hidden_achievements/0 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Count unlocked achievements for a user.
  """
  @spec count_user_achievements(integer()) :: non_neg_integer()
  def count_user_achievements(_user_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        0

      _ ->
        raise "GameServer.Achievements.count_user_achievements/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Count distinct users who have unlocked at least one achievement.
  """
  @spec count_users_with_unlocks() :: non_neg_integer()
  def count_users_with_unlocks() do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        0

      _ ->
        raise "GameServer.Achievements.count_users_with_unlocks/0 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Creates a new achievement definition.
  """
  @spec create_achievement(map()) ::
  {:ok, GameServer.Achievements.Achievement.t()} | {:error, Ecto.Changeset.t()}
  def create_achievement(_attrs) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.Achievements.create_achievement/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Returns achievement statistics for the admin dashboard.
    
    Returns a map with:
    - `hidden` — number of hidden achievements
    - `users_with_unlocks` — users who unlocked at least one
    - `avg_unlocks_per_user` — average unlocks per user (among users who have any)
    - `most_unlocked` — `{slug, title, count}` of the most-unlocked achievement
    - `least_unlocked` — `{slug, title, count}` of the least-unlocked achievement (with at least 1 unlock)
    
  """
  @spec dashboard_stats() :: map()
  def dashboard_stats() do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        %{}

      _ ->
        raise "GameServer.Achievements.dashboard_stats/0 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Deletes an achievement and all related user progress.
  """
  @spec delete_achievement(GameServer.Achievements.Achievement.t()) ::
  {:ok, GameServer.Achievements.Achievement.t()} | {:error, Ecto.Changeset.t()}
  def delete_achievement(_achievement) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.Achievements.delete_achievement/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Get an achievement by ID.
  """
  @spec get_achievement(integer()) :: GameServer.Achievements.Achievement.t() | nil
  def get_achievement(_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        nil

      _ ->
        raise "GameServer.Achievements.get_achievement/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Get an achievement by slug.
  """
  @spec get_achievement_by_slug(String.t()) :: GameServer.Achievements.Achievement.t() | nil
  def get_achievement_by_slug(_slug) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        nil

      _ ->
        raise "GameServer.Achievements.get_achievement_by_slug/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Get a user's progress on a specific achievement.
  """
  @spec get_user_achievement(integer(), integer()) :: GameServer.Achievements.UserAchievement.t() | nil
  def get_user_achievement(_user_id, _achievement_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        nil

      _ ->
        raise "GameServer.Achievements.get_user_achievement/2 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Grant achievement to user by slug (admin convenience, calls unlock_achievement).
  """
  @spec grant_achievement(integer(), String.t()) ::
  {:ok, GameServer.Achievements.UserAchievement.t()} | {:error, atom()}
  def grant_achievement(_user_id, _slug) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.Achievements.grant_achievement/2 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Increment progress on an achievement for a user. Automatically unlocks
    when progress reaches the target.
    
    Returns `{:ok, user_achievement}`.
    
  """
  @spec increment_progress(integer(), String.t()) ::
  {:ok, GameServer.Achievements.UserAchievement.t()} | {:error, atom()}
  def increment_progress(_user_id, _slug) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.Achievements.increment_progress/2 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Increment progress on an achievement for a user. Automatically unlocks
    when progress reaches the target.
    
    Returns `{:ok, user_achievement}`.
    
  """
  @spec increment_progress(integer(), String.t(), pos_integer()) ::
  {:ok, GameServer.Achievements.UserAchievement.t()} | {:error, atom()}
  def increment_progress(_user_id, _slug, _amount) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.Achievements.increment_progress/3 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Lists all achievements, optionally with user progress.
    
    ## Options
    - `:user_id` — if provided, includes user progress/unlock status
    - `:page` — page number (default: 1)
    - `:page_size` — items per page (default: 25)
    - `:include_hidden` — if true, include hidden achievements (default: false)
    
  """
  @spec list_achievements() :: [map()]
  def list_achievements() do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        %{}

      _ ->
        raise "GameServer.Achievements.list_achievements/0 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Lists all achievements, optionally with user progress.
    
    ## Options
    - `:user_id` — if provided, includes user progress/unlock status
    - `:page` — page number (default: 1)
    - `:page_size` — items per page (default: 25)
    - `:include_hidden` — if true, include hidden achievements (default: false)
    
  """
  @spec list_achievements(keyword()) :: [map()]
  def list_achievements(_opts) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        %{}

      _ ->
        raise "GameServer.Achievements.list_achievements/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Lists all achievements unlocked by a user.
  """
  @spec list_user_achievements(integer()) :: [GameServer.Achievements.UserAchievement.t()]
  def list_user_achievements(_user_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        []

      _ ->
        raise "GameServer.Achievements.list_user_achievements/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Lists all achievements unlocked by a user.
  """
  @spec list_user_achievements(
  integer(),
  keyword()
) :: [GameServer.Achievements.UserAchievement.t()]
  def list_user_achievements(_user_id, _opts) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        []

      _ ->
        raise "GameServer.Achievements.list_user_achievements/2 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Reset a user's progress on a specific achievement (admin use).
  """
  @spec reset_user_achievement(integer(), integer()) ::
  {:ok, GameServer.Achievements.UserAchievement.t() | :not_found} | {:error, Ecto.Changeset.t()}
  def reset_user_achievement(_user_id, _achievement_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.Achievements.reset_user_achievement/2 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Revoke an achievement from a user. Deletes the user_achievement record entirely.
    
  """
  @spec revoke_achievement(integer(), integer()) ::
  {:ok, GameServer.Achievements.UserAchievement.t()} | {:error, atom()}
  def revoke_achievement(_user_id, _achievement_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.Achievements.revoke_achievement/2 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Subscribe to global achievement events (new definitions, updates, unlocks).
  """
  @spec subscribe_achievements() :: :ok | {:error, term()}
  def subscribe_achievements() do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        :ok

      _ ->
        raise "GameServer.Achievements.subscribe_achievements/0 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Unlock an achievement for a user by slug. If it's a progress-based achievement,
    sets progress to the target and marks it as unlocked.
    
    Returns `{:ok, user_achievement}` or `{:error, reason}`.
    
  """
  @spec unlock_achievement(integer(), String.t() | integer()) ::
  {:ok, GameServer.Achievements.UserAchievement.t()} | {:error, atom()}
  def unlock_achievement(_user_id, _slug) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.Achievements.unlock_achievement/2 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Get unlock percentage for an achievement (0.0 to 100.0).
  """
  @spec unlock_percentage(integer()) :: float()
  def unlock_percentage(_achievement_id) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        nil

      _ ->
        raise "GameServer.Achievements.unlock_percentage/1 is a stub - only available at runtime on GameServer"
    end
  end


  @doc ~S"""
    Updates an achievement definition.
  """
  @spec update_achievement(GameServer.Achievements.Achievement.t(), map()) ::
  {:ok, GameServer.Achievements.Achievement.t()} | {:error, Ecto.Changeset.t()}
  def update_achievement(_achievement, _attrs) do
    case Application.get_env(:game_server_sdk, :stub_mode, :raise) do
      :placeholder ->
        {:ok, nil}

      _ ->
        raise "GameServer.Achievements.update_achievement/2 is a stub - only available at runtime on GameServer"
    end
  end

end
