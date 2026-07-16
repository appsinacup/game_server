defmodule ExampleHook.V1.HelloProtoRequest do
  @moduledoc false

  use Protobuf,
    full_name: "example_hook.v1.HelloProtoRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :name, 1, type: :string
  field :repeat, 2, type: :uint32
end

defmodule ExampleHook.V1.HelloProtoReply do
  @moduledoc false

  use Protobuf,
    full_name: "example_hook.v1.HelloProtoReply",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :greeting, 1, type: :string
  field :name_length, 2, type: :uint32, json_name: "nameLength"
end

defmodule ExampleHook.V1.ExampleLoadout do
  @moduledoc false

  use Protobuf,
    full_name: "example_hook.v1.ExampleLoadout",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :weapon_id, 1, type: :uint32, json_name: "weaponId"
  field :perk_ids, 2, repeated: true, type: :uint32, json_name: "perkIds"
end
