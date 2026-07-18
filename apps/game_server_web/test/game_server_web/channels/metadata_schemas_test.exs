defmodule GameServerWeb.MetadataSchemasTest do
  use ExUnit.Case, async: false

  alias Gamend.Realtime.V1, as: PB
  alias GameServer.Hooks.HookSchemas
  alias GameServer.Hooks.KvSchemas
  alias GameServer.Hooks.MetadataSchemas
  alias GameServerWeb.EventCodec

  # Stand-in for a game plugin's generated metadata schema.
  defmodule UserMeta do
    use Protobuf, syntax: :proto3

    field :rank, 1, type: :uint32
    field :clan, 2, type: :string
    field :badge_ids, 3, repeated: true, type: :uint32
  end

  defmodule LobbyMeta do
    use Protobuf, syntax: :proto3

    field :map_name, 1, type: :string
    field :ranked, 2, type: :bool
  end

  defmodule HelloThingRequest do
    use Protobuf, syntax: :proto3

    field :name, 1, type: :string
  end

  defmodule HelloThingReply do
    use Protobuf, syntax: :proto3

    field :greeting, 1, type: :string
  end

  defmodule FakeHooks do
    def metadata_schemas, do: %{party: GameServerWeb.MetadataSchemasTest.LobbyMeta}
  end

  defp plugin(attrs) do
    Map.merge(
      %{name: "test_game", status: :ok, hooks_module: nil, modules: []},
      Map.new(attrs)
    )
  end

  setup do
    on_exit(fn ->
      MetadataSchemas.refresh([])
      KvSchemas.refresh([])
    end)

    :ok
  end

  test "registers conventional module names per entity" do
    MetadataSchemas.refresh([plugin(modules: [UserMeta, LobbyMeta])])

    assert MetadataSchemas.module_for(:user) == UserMeta
    assert MetadataSchemas.module_for(:lobby) == LobbyMeta
    assert MetadataSchemas.module_for(:group) == nil
  end

  defmodule OtherMeta do
    use Protobuf, syntax: :proto3

    field :level, 1, type: :uint32
  end

  defmodule DisablingHooks do
    def metadata_schemas, do: %{user: nil}
  end

  defmodule Alt do
    defmodule UserMeta do
      use Protobuf, syntax: :proto3

      field :level, 1, type: :uint32
    end
  end

  test "metadata conflicts resolve deterministically: explicit > convention, then plugin name order" do
    # Two conventional UserMeta modules -> first plugin in name order wins.
    MetadataSchemas.refresh([
      plugin(name: "b_game", modules: [Alt.UserMeta]),
      plugin(name: "a_game", modules: [UserMeta])
    ])

    assert MetadataSchemas.module_for(:user) == UserMeta

    # Explicit beats convention regardless of plugin name order.
    MetadataSchemas.refresh([
      plugin(name: "a_game", modules: [UserMeta]),
      plugin(name: "z_game", hooks_module: __MODULE__.ExplicitOther)
    ])

    assert MetadataSchemas.module_for(:user) == OtherMeta
  end

  defmodule ExplicitOther do
    def metadata_schemas, do: %{user: GameServerWeb.MetadataSchemasTest.OtherMeta}
  end

  test "explicit nil disables an entity globally (sticky)" do
    MetadataSchemas.refresh([
      plugin(name: "a_disabler", hooks_module: DisablingHooks),
      plugin(name: "z_game", modules: [UserMeta])
    ])

    assert MetadataSchemas.module_for(:user) == nil
  end

  test "kv pattern conflicts: first plugin in name order wins" do
    alias GameServer.Hooks.KvSchemas

    KvSchemas.refresh([
      plugin(name: "a_game", hooks_module: __MODULE__.KvHooks),
      plugin(name: "z_game", hooks_module: __MODULE__.KvHooksZ)
    ])

    # a_game registered "loadout" first; z_game's duplicate is ignored.
    assert KvSchemas.module_for("loadout") == LobbyMeta
    KvSchemas.refresh([])
  end

  defmodule KvHooksZ do
    def kv_schemas, do: %{"loadout" => GameServerWeb.MetadataSchemasTest.UserMeta}
  end

  test "explicit metadata_schemas/0 overrides and disables" do
    MetadataSchemas.refresh([
      plugin(modules: [UserMeta, LobbyMeta], hooks_module: FakeHooks)
    ])

    # Explicit mapping registered on top of conventions.
    assert MetadataSchemas.module_for(:party) == LobbyMeta
    assert MetadataSchemas.module_for(:user) == UserMeta
  end

  test "matching metadata encodes as metadata_pb" do
    MetadataSchemas.refresh([plugin(modules: [UserMeta])])

    payload = %{id: "u1", metadata: %{"rank" => 12, "clan" => "red", "badge_ids" => [1, 4]}}
    {:ok, bin} = EventCodec.encode("user:x", "updated", payload)
    decoded = PB.User.decode(IO.iodata_to_binary(bin))

    assert decoded.metadata_json == nil
    meta = UserMeta.decode(decoded.metadata_pb)
    assert meta.rank == 12
    assert meta.clan == "red"
    assert meta.badge_ids == [1, 4]
  end

  test "mismatching metadata falls back to JSON without dropping data" do
    MetadataSchemas.refresh([plugin(modules: [UserMeta])])

    payload = %{id: "u1", metadata: %{"rank" => 12, "not_in_schema" => "keep me"}}
    {:ok, bin} = EventCodec.encode("user:x", "updated", payload)
    decoded = PB.User.decode(IO.iodata_to_binary(bin))

    assert decoded.metadata_pb == nil
    assert Jason.decode!(decoded.metadata_json) == %{"rank" => 12, "not_in_schema" => "keep me"}
  end

  test "lobby metadata uses the lobby schema; absent metadata stays absent" do
    MetadataSchemas.refresh([plugin(modules: [LobbyMeta])])

    {:ok, bin} =
      EventCodec.encode("lobby:x", "updated", %{
        is_locked: true,
        metadata: %{"map_name" => "dust", "ranked" => true}
      })

    decoded = PB.Lobby.decode(IO.iodata_to_binary(bin))
    assert LobbyMeta.decode(decoded.metadata_pb).map_name == "dust"

    {:ok, bin} = EventCodec.encode("lobby:x", "updated", %{is_locked: false})
    decoded = PB.Lobby.decode(IO.iodata_to_binary(bin))
    assert decoded.metadata_pb == nil
    assert decoded.metadata_json == nil
  end

  defmodule KvHooks do
    def kv_schemas do
      %{
        "loadout" => GameServerWeb.MetadataSchemasTest.LobbyMeta,
        "match:*" => GameServerWeb.MetadataSchemasTest.UserMeta
      }
    end
  end

  test "kv schemas match exact keys and prefixes, encode data_pb with JSON fallback" do
    alias GameServer.Hooks.KvSchemas
    KvSchemas.refresh([plugin(hooks_module: KvHooks)])

    assert KvSchemas.module_for("loadout") == LobbyMeta
    assert KvSchemas.module_for("match:42") == UserMeta
    assert KvSchemas.module_for("other") == nil

    # Matching data -> data_pb (schema for "match:*" is UserMeta).
    payload = %{key: "match:42", user_id: "u1", data: %{"rank" => 3, "clan" => "red"}}
    {:ok, bin} = EventCodec.encode("user:x", "kv_updated", payload)
    decoded = PB.KvEntry.decode(IO.iodata_to_binary(bin))
    assert decoded.data_json == nil
    assert UserMeta.decode(decoded.data_pb).rank == 3

    # Non-matching data (unknown key in map) -> JSON, never dropped.
    payload = %{key: "match:42", data: %{"rank" => 3, "oops" => true}}
    {:ok, bin} = EventCodec.encode("user:x", "kv_updated", payload)
    decoded = PB.KvEntry.decode(IO.iodata_to_binary(bin))
    assert decoded.data_pb == nil
    assert Jason.decode!(decoded.data_json) == %{"rank" => 3, "oops" => true}

    # Non-map data with a registered schema -> JSON.
    payload = %{key: "loadout", data: [1, 2, 3]}
    {:ok, bin} = EventCodec.encode("user:x", "kv_updated", payload)
    decoded = PB.KvEntry.decode(IO.iodata_to_binary(bin))
    assert decoded.data_pb == nil
    assert Jason.decode!(decoded.data_json) == [1, 2, 3]

    # Unregistered key -> JSON as before.
    {:ok, bin} = EventCodec.encode("user:x", "kv_updated", %{key: "other", data: %{"a" => 1}})
    decoded = PB.KvEntry.decode(IO.iodata_to_binary(bin))
    assert decoded.data_pb == nil
    assert Jason.decode!(decoded.data_json) == %{"a" => 1}
  end

  test "hook schemas register <FnName>Request/<FnName>Reply pairs by convention" do
    HookSchemas.refresh([
      plugin(modules: [HelloThingRequest, HelloThingReply, UserMeta])
    ])

    assert %{request: HelloThingRequest, reply: HelloThingReply} =
             HookSchemas.lookup("test_game", "hello_thing")

    # UserMeta has no Reply pair and Request-less names never register.
    assert HookSchemas.lookup("test_game", "user_meta") == nil
    HookSchemas.refresh([])
  end

  test "without a registered schema metadata stays JSON" do
    payload = %{id: "u1", metadata: %{"rank" => 12}}
    {:ok, bin} = EventCodec.encode("user:x", "updated", payload)
    decoded = PB.User.decode(IO.iodata_to_binary(bin))

    assert decoded.metadata_pb == nil
    assert Jason.decode!(decoded.metadata_json) == %{"rank" => 12}
  end
end
