defmodule GameServerWeb.TestSupport.NoopHooks do
  @moduledoc """
  Test helper for hook modules that override only callbacks under test.
  """

  defmacro __using__(_opts) do
    quote do
      @behaviour GameServer.Hooks

      @impl true
      def after_startup, do: :ok

      @impl true
      def before_stop, do: :ok

      @impl true
      def after_user_register(_user), do: :ok

      @impl true
      def after_user_login(_user), do: :ok

      @impl true
      def after_user_updated(_user), do: :ok

      @impl true
      def after_user_online(_user), do: :ok

      @impl true
      def after_user_offline(_user), do: :ok

      @impl true
      def before_user_update(_user, attrs), do: {:ok, attrs}

      @impl true
      def on_custom_hook(_hook, _args), do: {:error, :not_implemented}

      @impl true
      def before_lobby_create(attrs), do: {:ok, attrs}

      @impl true
      def after_lobby_create(_lobby), do: :ok

      @impl true
      def before_lobby_join(user, lobby, opts), do: {:ok, {user, lobby, opts}}

      @impl true
      def after_lobby_join(_user, _lobby), do: :ok

      @impl true
      def before_lobby_leave(user, lobby), do: {:ok, {user, lobby}}

      @impl true
      def after_lobby_leave(_user, _lobby), do: :ok

      @impl true
      def before_lobby_update(_lobby, attrs), do: {:ok, attrs}

      @impl true
      def after_lobby_update(_lobby), do: :ok

      @impl true
      def before_lobby_delete(lobby), do: {:ok, lobby}

      @impl true
      def after_lobby_delete(_lobby), do: :ok

      @impl true
      def before_user_kicked(host, target, lobby), do: {:ok, {host, target, lobby}}

      @impl true
      def after_user_kicked(_host, _target, _lobby), do: :ok

      @impl true
      def after_lobby_host_change(_lobby, _new_host_id), do: :ok

      @impl true
      def before_group_create(_user, attrs), do: {:ok, attrs}

      @impl true
      def after_group_create(_group), do: :ok

      @impl true
      def before_group_join(user, group, opts), do: {:ok, {user, group, opts}}

      @impl true
      def before_group_update(_group, attrs), do: {:ok, attrs}

      @impl true
      def after_group_update(_group), do: :ok

      @impl true
      def after_group_join(_user_id, _group), do: :ok

      @impl true
      def after_group_leave(_user_id, _group_id), do: :ok

      @impl true
      def after_group_delete(_group), do: :ok

      @impl true
      def after_group_kick(_admin_id, _target_id, _group_id), do: :ok

      @impl true
      def before_party_create(_user, attrs), do: {:ok, attrs}

      @impl true
      def after_party_create(_party), do: :ok

      @impl true
      def before_party_update(_party, attrs), do: {:ok, attrs}

      @impl true
      def after_party_update(_party), do: :ok

      @impl true
      def after_party_join(_user, _party), do: :ok

      @impl true
      def after_party_leave(_user, _party_id), do: :ok

      @impl true
      def after_party_kick(_target, _leader, _party), do: :ok

      @impl true
      def after_party_disband(_party), do: :ok

      @impl true
      def before_chat_message(_user, attrs), do: {:ok, attrs}

      @impl true
      def after_chat_message(_message), do: :ok

      @impl true
      def before_kv_get(_key, _opts), do: :public

      @impl true
      def after_achievement_unlocked(_user_id, _achievement), do: :ok

      defoverridable after_startup: 0,
                     before_stop: 0,
                     after_user_register: 1,
                     after_user_login: 1,
                     after_user_updated: 1,
                     after_user_online: 1,
                     after_user_offline: 1,
                     before_user_update: 2,
                     on_custom_hook: 2,
                     before_lobby_create: 1,
                     after_lobby_create: 1,
                     before_lobby_join: 3,
                     after_lobby_join: 2,
                     before_lobby_leave: 2,
                     after_lobby_leave: 2,
                     before_lobby_update: 2,
                     after_lobby_update: 1,
                     before_lobby_delete: 1,
                     after_lobby_delete: 1,
                     before_user_kicked: 3,
                     after_user_kicked: 3,
                     after_lobby_host_change: 2,
                     before_group_create: 2,
                     after_group_create: 1,
                     before_group_join: 3,
                     before_group_update: 2,
                     after_group_update: 1,
                     after_group_join: 2,
                     after_group_leave: 2,
                     after_group_delete: 1,
                     after_group_kick: 3,
                     before_party_create: 2,
                     after_party_create: 1,
                     before_party_update: 2,
                     after_party_update: 1,
                     after_party_join: 2,
                     after_party_leave: 2,
                     after_party_kick: 3,
                     after_party_disband: 1,
                     before_chat_message: 2,
                     after_chat_message: 1,
                     before_kv_get: 2,
                     after_achievement_unlocked: 2
    end
  end
end
