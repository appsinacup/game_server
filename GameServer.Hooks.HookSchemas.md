# `GameServer.Hooks.HookSchemas`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/hooks/hook_schemas.ex#L1)

Registry of game-defined protobuf schemas for typed hooks, plus the
argument/result conversion that makes typed hooks callable from every
transport and payload format.

Registration is convention-based, like `GameServer.Hooks.MetadataSchemas`:
when a plugin loads, its modules are scanned for protobuf message pairs
named `<FnName>Request` / `<FnName>Reply` — e.g. `HelloProtoRequest` and
`HelloProtoReply` register the schema for the `hello_proto` hook. The
plugin function then receives the decoded request struct as its single
argument and returns a reply struct:

    def hello_proto(%MyGame.V1.HelloProtoRequest{} = req) do
      %MyGame.V1.HelloProtoReply{greeting: "Hello, " <> req.name}
    end

Because the server converts at the boundary, the same hook is callable
with binary protobuf (`args_raw` on protobuf DataChannels) and with plain
JSON objects (WebSocket `call_hook`, JSON DataChannels, admin tester) —
clients can switch formats at runtime without changing call sites.

Hooks without a registered schema are dynamic: JSON args are passed as an
argument list and the result must be JSON-encodable. Binary calls
(`args_raw`) require a registered schema — there is no opaque relay, so a
protobuf caller always has a contract on both ends.

# `all`

```elixir
@spec all() :: %{
  required({String.t(), String.t()}) =&gt; %{request: module(), reply: module()}
}
```

Returns the full {plugin, fn} -> schema registry (for the admin overview).

# `call`

```elixir
@spec call(
  String.t(),
  String.t(),
  {:raw, binary()} | {:list, list()},
  :binary | :map,
  keyword()
) :: {:ok, {:raw, binary()} | term()} | {:error, term()}
```

Calls a hook with transport-level arguments, converting through the
registered schema when one exists.

`args_input` is `{:raw, binary}` (protobuf-encoded request bytes) or
`{:list, args}` (JSON argument list; for typed hooks a single object —
or no argument — that decodes into the request message).

`wire` selects the result encoding: `:binary` returns `{:ok, {:raw, bytes}}`
(protobuf-encoded reply), `:map` returns `{:ok, json_encodable}`.

# `lookup`

```elixir
@spec lookup(String.t(), String.t()) :: %{request: module(), reply: module()} | nil
```

Returns the registered schema for a hook, or nil.

# `refresh`

```elixir
@spec refresh([struct()]) :: :ok
```

Rebuilds the registry from the loaded plugin list.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
