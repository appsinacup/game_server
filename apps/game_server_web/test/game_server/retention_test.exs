defmodule GameServer.RetentionTest do
  use GameServer.DataCase, async: false

  alias GameServer.AccountsFixtures
  alias GameServer.Repo
  alias GameServer.Retention

  defp backdate(schema, id, days) do
    cutoff = DateTime.add(DateTime.utc_now(:second), -days, :day)

    Repo.update_all(
      from(r in schema, where: r.id == ^id),
      set: [inserted_at: cutoff]
    )
  end

  setup do
    original = Application.get_env(:game_server_core, GameServer.Retention, [])

    on_exit(fn ->
      Application.put_env(:game_server_core, GameServer.Retention, original)
    end)

    :ok
  end

  test "prunes chat messages older than the configured retention" do
    Application.put_env(:game_server_core, GameServer.Retention, chat_messages_days: 30)

    a = AccountsFixtures.user_fixture()

    old =
      Repo.insert!(%GameServer.Chat.Message{
        sender_id: a.id,
        content: "old",
        chat_type: "lobby",
        chat_ref_id: Ecto.UUID.generate()
      })

    fresh =
      Repo.insert!(%GameServer.Chat.Message{
        sender_id: a.id,
        content: "fresh",
        chat_type: "lobby",
        chat_ref_id: Ecto.UUID.generate()
      })

    backdate(GameServer.Chat.Message, old.id, 31)

    results = Retention.prune_all()

    assert results.chat_messages == 1
    refute Repo.get(GameServer.Chat.Message, old.id)
    assert Repo.get(GameServer.Chat.Message, fresh.id)
  end

  test "retention of 0 keeps everything" do
    Application.put_env(:game_server_core, GameServer.Retention, chat_messages_days: 0)

    a = AccountsFixtures.user_fixture()

    old =
      Repo.insert!(%GameServer.Chat.Message{
        sender_id: a.id,
        content: "old",
        chat_type: "lobby",
        chat_ref_id: Ecto.UUID.generate()
      })

    backdate(GameServer.Chat.Message, old.id, 400)

    results = Retention.prune_all()

    assert results.chat_messages == 0
    assert Repo.get(GameServer.Chat.Message, old.id)
  end

  test "prunes expired ip bans but keeps permanent and future ones" do
    now = DateTime.utc_now(:second)

    expired =
      Repo.insert!(%GameServer.IpBans.IpBan{ip: "10.0.0.1", expires_at: DateTime.add(now, -60)})

    future =
      Repo.insert!(%GameServer.IpBans.IpBan{ip: "10.0.0.2", expires_at: DateTime.add(now, 3600)})

    permanent = Repo.insert!(%GameServer.IpBans.IpBan{ip: "10.0.0.3", expires_at: nil})

    results = Retention.prune_all()

    assert results.expired_ip_bans == 1
    refute Repo.get(GameServer.IpBans.IpBan, expired.id)
    assert Repo.get(GameServer.IpBans.IpBan, future.id)
    assert Repo.get(GameServer.IpBans.IpBan, permanent.id)
  end
end
