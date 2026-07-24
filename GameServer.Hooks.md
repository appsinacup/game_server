# `GameServer.Hooks`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/hooks.ex#L1)

Behaviour for application-level hooks / callbacks.

Implement this behaviour to receive lifecycle events from core flows
(registration, login, provider linking, deletion) and run custom logic.

A module implementing this behaviour can be configured with

    config :game_server_core, :hooks_module, MyApp.HooksImpl

The default implementation is a no-op.

# `after_startup`

```elixir
@callback after_startup() :: any()
```

# `before_stop`

```elixir
@callback before_stop() :: any()
```

# `on_custom_hook`

```elixir
@callback on_custom_hook(String.t(), list()) :: any()
```

Handle a dynamically-exported RPC function.

This callback is used for function names that were registered at runtime (eg.
via a plugin's `after_startup/0` return value) and therefore may not exist as
exported Elixir functions on the hooks module.

Receives the function name and the argument list.

# `after_user_deleted`

```elixir
@callback after_user_deleted(GameServer.Accounts.User.t()) :: any()
```

# `after_user_logged_in`

```elixir
@callback after_user_logged_in(GameServer.Accounts.User.t()) :: any()
```

# `after_user_offline`

```elixir
@callback after_user_offline(GameServer.Accounts.User.t()) :: any()
```

# `after_user_online`

```elixir
@callback after_user_online(GameServer.Accounts.User.t()) :: any()
```

# `after_user_register`

```elixir
@callback after_user_register(GameServer.Accounts.User.t()) :: any()
```

# `after_user_updated`

```elixir
@callback after_user_updated(GameServer.Accounts.User.t()) :: any()
```

# `before_user_register`

```elixir
@callback before_user_register(
  GameServer.Accounts.User.t(),
  GameServer.Types.user_registration_hook_attrs()
) :: hook_result(GameServer.Types.user_registration_hook_attrs())
```

Called before a new user row is inserted, on every registration path:
email, device, and all OAuth providers (which register mid-login).

Receives the tentative user (not yet inserted, `id` is `nil`) and the
registration attrs (string keys), which already contain the generated
`"username"`. Return `{:ok, attrs}` — possibly with a different username
or other changes — or `{:error, reason}` to abort the registration.

Core re-validates after all hooks ran: format and uniqueness are not
overridable. A hook-supplied username that is invalid or already taken is
replaced with a generated one (a plugin bug must never lock a player out
of login). For strict policy on player-initiated changes — profanity or
reserved names — use `c:before_user_update/2`, where errors are returned
to the player:

    def before_user_update(_user, %{"username" => name} = attrs) do
      if MyGame.Profanity.allowed?(name),
        do: {:ok, attrs},
        else: {:error, :invalid_username}
    end

    def before_user_update(_user, attrs), do: {:ok, attrs}

# `before_user_update`

```elixir
@callback before_user_update(GameServer.Accounts.User.t(), map()) :: hook_result(map())
```

# `after_lobby_create`

```elixir
@callback after_lobby_create(GameServer.Lobbies.Lobby.t()) :: any()
```

# `after_lobby_deleted`

```elixir
@callback after_lobby_deleted(GameServer.Lobbies.Lobby.t()) :: any()
```

# `after_lobby_host_change`

```elixir
@callback after_lobby_host_change(GameServer.Lobbies.Lobby.t(), String.t()) :: any()
```

# `after_lobby_join`

```elixir
@callback after_lobby_join(GameServer.Accounts.User.t(), GameServer.Lobbies.Lobby.t()) ::
  any()
```

# `after_lobby_kick`

```elixir
@callback after_lobby_kick(
  GameServer.Accounts.User.t(),
  GameServer.Accounts.User.t(),
  GameServer.Lobbies.Lobby.t()
) :: any()
```

# `after_lobby_leave`

```elixir
@callback after_lobby_leave(GameServer.Accounts.User.t(), GameServer.Lobbies.Lobby.t()) ::
  any()
```

# `after_lobby_updated`

```elixir
@callback after_lobby_updated(GameServer.Lobbies.Lobby.t()) :: any()
```

# `before_lobby_create`

```elixir
@callback before_lobby_create(map()) :: hook_result(map())
```

# `before_lobby_delete`

```elixir
@callback before_lobby_delete(GameServer.Lobbies.Lobby.t()) ::
  hook_result(GameServer.Lobbies.Lobby.t())
```

# `before_lobby_join`

```elixir
@callback before_lobby_join(
  GameServer.Accounts.User.t(),
  GameServer.Lobbies.Lobby.t(),
  keyword()
) ::
  hook_result(
    {GameServer.Accounts.User.t(), GameServer.Lobbies.Lobby.t(), keyword()}
  )
```

# `before_lobby_kick`

```elixir
@callback before_lobby_kick(
  GameServer.Accounts.User.t(),
  GameServer.Accounts.User.t(),
  GameServer.Lobbies.Lobby.t()
) ::
  hook_result(
    {GameServer.Accounts.User.t(), GameServer.Accounts.User.t(),
     GameServer.Lobbies.Lobby.t()}
  )
```

# `before_lobby_leave`
*optional* 

```elixir
@callback before_lobby_leave(GameServer.Accounts.User.t(), GameServer.Lobbies.Lobby.t()) ::
  any()
```

# `before_lobby_update`

```elixir
@callback before_lobby_update(GameServer.Lobbies.Lobby.t(), map()) :: hook_result(map())
```

# `after_group_create`

```elixir
@callback after_group_create(GameServer.Groups.Group.t()) :: any()
```

# `after_group_deleted`

```elixir
@callback after_group_deleted(GameServer.Groups.Group.t()) :: any()
```

# `after_group_join`

```elixir
@callback after_group_join(String.t(), GameServer.Groups.Group.t()) :: any()
```

# `after_group_kick`

```elixir
@callback after_group_kick(String.t(), String.t(), String.t()) :: any()
```

# `after_group_leave`

```elixir
@callback after_group_leave(String.t(), String.t()) :: any()
```

# `after_group_updated`

```elixir
@callback after_group_updated(GameServer.Groups.Group.t()) :: any()
```

# `before_group_create`

```elixir
@callback before_group_create(GameServer.Accounts.User.t(), map()) :: hook_result(map())
```

# `before_group_delete`

```elixir
@callback before_group_delete(GameServer.Groups.Group.t()) ::
  hook_result(GameServer.Groups.Group.t())
```

# `before_group_join`

```elixir
@callback before_group_join(
  GameServer.Accounts.User.t(),
  GameServer.Groups.Group.t(),
  map()
) ::
  hook_result(
    {GameServer.Accounts.User.t(), GameServer.Groups.Group.t(), map()}
  )
```

# `before_group_kick`

```elixir
@callback before_group_kick(String.t(), String.t(), String.t()) ::
  hook_result({String.t(), String.t(), String.t()})
```

# `before_group_update`

```elixir
@callback before_group_update(GameServer.Groups.Group.t(), map()) :: hook_result(map())
```

# `after_party_create`

```elixir
@callback after_party_create(GameServer.Parties.Party.t()) :: any()
```

# `after_party_disband`

```elixir
@callback after_party_disband(GameServer.Parties.Party.t()) :: any()
```

# `after_party_join`

```elixir
@callback after_party_join(GameServer.Accounts.User.t(), GameServer.Parties.Party.t()) ::
  any()
```

# `after_party_kick`

```elixir
@callback after_party_kick(
  GameServer.Accounts.User.t(),
  GameServer.Accounts.User.t(),
  GameServer.Parties.Party.t()
) :: any()
```

# `after_party_leave`

```elixir
@callback after_party_leave(GameServer.Accounts.User.t(), String.t()) :: any()
```

# `after_party_updated`

```elixir
@callback after_party_updated(GameServer.Parties.Party.t()) :: any()
```

# `before_party_create`

```elixir
@callback before_party_create(GameServer.Accounts.User.t(), map()) :: hook_result(map())
```

# `before_party_join`

```elixir
@callback before_party_join(GameServer.Accounts.User.t(), GameServer.Parties.Party.t()) ::
  hook_result({GameServer.Accounts.User.t(), GameServer.Parties.Party.t()})
```

# `before_party_kick`

```elixir
@callback before_party_kick(
  GameServer.Accounts.User.t(),
  GameServer.Accounts.User.t(),
  GameServer.Parties.Party.t()
) ::
  hook_result(
    {GameServer.Accounts.User.t(), GameServer.Accounts.User.t(),
     GameServer.Parties.Party.t()}
  )
```

# `before_party_update`

```elixir
@callback before_party_update(GameServer.Parties.Party.t(), map()) :: hook_result(map())
```

# `after_chat_message`

```elixir
@callback after_chat_message(GameServer.Chat.Message.t()) :: any()
```

# `before_chat_message`

```elixir
@callback before_chat_message(GameServer.Accounts.User.t(), map()) :: hook_result(map())
```

# `after_achievement_unlocked`

```elixir
@callback after_achievement_unlocked(String.t(), GameServer.Achievements.Achievement.t()) ::
  any()
```

# `after_score_submitted`

```elixir
@callback after_score_submitted(GameServer.Leaderboards.Record.t()) :: any()
```

# `after_tournament_finished`
*optional* 

```elixir
@callback after_tournament_finished(GameServer.Tournaments.Tournament.t(), map()) :: any()
```

# `after_tournament_match_resolved`
*optional* 

```elixir
@callback after_tournament_match_resolved(GameServer.Tournaments.Match.t()) :: any()
```

# `after_tournament_register`
*optional* 

```elixir
@callback after_tournament_register(
  GameServer.Accounts.User.t(),
  GameServer.Tournaments.Tournament.t()
) ::
  any()
```

# `before_tournament_leave`
*optional* 

```elixir
@callback before_tournament_leave(
  GameServer.Accounts.User.t(),
  GameServer.Tournaments.Tournament.t()
) ::
  hook_result(term())
```

# `before_tournament_register`
*optional* 

```elixir
@callback before_tournament_register(
  GameServer.Accounts.User.t(),
  GameServer.Tournaments.Tournament.t()
) ::
  hook_result(term())
```

# `before_tournament_result`
*optional* 

```elixir
@callback before_tournament_result(GameServer.Tournaments.Match.t(), term()) ::
  hook_result(term())
```

# `tournament_match_expired`
*optional* 

```elixir
@callback tournament_match_expired(GameServer.Tournaments.Match.t()) :: any()
```

# `tournament_match_ready`
*optional* 

```elixir
@callback tournament_match_ready(GameServer.Tournaments.Match.t()) :: any()
```

# `after_matchmaking_cancel`
*optional* 

```elixir
@callback after_matchmaking_cancel(Ecto.UUID.t(), non_neg_integer()) :: any()
```

# `after_matchmaking_join`
*optional* 

```elixir
@callback after_matchmaking_join(
  GameServer.Accounts.User.t(),
  GameServer.Matchmaking.Ticket.t()
) :: any()
```

# `after_matchmaking_matched`
*optional* 

```elixir
@callback after_matchmaking_matched([GameServer.Matchmaking.Ticket.t()], Ecto.UUID.t()) ::
  any()
```

# `before_matchmaking_join`
*optional* 

```elixir
@callback before_matchmaking_join(GameServer.Accounts.User.t(), map()) ::
  hook_result(map())
```

# `matchmaking_form_matches`
*optional* 

```elixir
@callback matchmaking_form_matches(map(), [GameServer.Matchmaking.Ticket.t()]) ::
  [[GameServer.Matchmaking.Ticket.t()]] | :default
```

# `after_entitlement_changed`
*optional* 

```elixir
@callback after_entitlement_changed(GameServer.Payments.Entitlement.t()) :: any()
```

# `after_purchase_fulfilled`
*optional* 

```elixir
@callback after_purchase_fulfilled(GameServer.Payments.Purchase.t()) :: any()
```

# `after_purchase_revoked`
*optional* 

```elixir
@callback after_purchase_revoked(GameServer.Payments.Purchase.t()) :: any()
```

# `after_inventory_changed`
*optional* 

```elixir
@callback after_inventory_changed(map()) :: any()
```

# `after_wallet_changed`
*optional* 

```elixir
@callback after_wallet_changed(map()) :: any()
```

# `before_kv_get`

```elixir
@callback before_kv_get(String.t(), kv_opts()) :: kv_access_result()
```

Called before a KV `get/2` is performed. Implementations should return
one of these client KV API access decisions:

- `:public` — any authenticated client can read.
- `:owner_only` — only the caller matching the requested `user_id` can read.
- `:lobby_members_only` — only callers in the requested `lobby_id` can read.
- `:owner_or_lobby_member` — caller may match either requested `user_id` or `lobby_id`.
- `:admin_only` — only admins can read through the client KV API.
- `:server_only` — no client KV reads.

Server-side `GameServer.KV.get/2` calls are unaffected.

Receives the `key` and an `opts` map/keyword (see `t:kv_opts/0`). Return
either the bare atom (e.g. `:public`) or `{:ok, :public}`; return `{:error, reason}`
to block the read.

# `hook_result`

```elixir
@type hook_result(attrs_or_user) :: {:ok, attrs_or_user} | {:error, term()}
```

# `kv_access`

```elixir
@type kv_access() ::
  :public
  | :owner_only
  | :lobby_members_only
  | :owner_or_lobby_member
  | :admin_only
  | :server_only
```

# `kv_access_result`

```elixir
@type kv_access_result() :: kv_access() | {:ok, kv_access()} | {:error, term()}
```

# `kv_opts`

```elixir
@type kv_opts() :: map() | keyword()
```

Options passed to hooks that accept an options map/keyword list.

Common keys include `:user_id`, `:lobby_id`, and other domain-specific options.
Hooks may accept either a map or keyword list for convenience.

# `call`

Call an arbitrary function exported by the configured hooks module.

This is a safe wrapper that checks function existence, enforces an allow-list
if configured and runs the call inside a short Task with a configurable
timeout to avoid long-running user code.

Returns {:ok, result} | {:error, reason}

# `caller`

```elixir
@spec caller() :: any() | nil
```

When a hooks function is executed via `call/3` or `internal_call/3`, an
optional `:caller` can be provided in the options. The caller will be
injected into the spawned task's process dictionary and is accessible via
`GameServer.Hooks.caller/0` (the raw value) or `caller_id/0` (the numeric id
when the value is a user struct or map containing `:id`).

# `caller_id`

```elixir
@spec caller_id() :: String.t() | nil
```

# `caller_user`

```elixir
@spec caller_user() :: GameServer.Accounts.User.t() | nil
```

Return the user struct for the current caller when available. This will
  attempt to resolve the caller via GameServer.Accounts.get_user!/1 when the
  caller is a user id or a map containing an `:id` key. Returns nil when
  no caller or user is found.

# `exported_functions`

Return a list of exported functions on the currently registered hooks module.

The result is a list of maps like: [%{name: "start_game", arities: [2,3]}, ...]
This is useful for tooling and admin UI to display what RPCs are available.

# `internal_call`

Call an internal lifecycle callback. When a callback is missing this
  returns a sensible default (eg. {:ok, attrs} for before callbacks) so
  domain code doesn't need to handle missing hooks specially in most cases.

# `internal_hooks`

```elixir
@spec internal_hooks() :: MapSet.t(atom())
```

Returns the set of internal lifecycle hook names that are not callable
  through the public RPC interface.

# `invoke`

Invoke a dynamic hook function by name.

This is used by `GameServer.Schedule` to call scheduled job callbacks.
Unlike `internal_call/3`, this is designed for user-defined functions
that are not part of the core lifecycle callbacks.

Returns `:ok` on success, `{:error, reason}` on failure or if the
function doesn't exist.

# `module`

Return the configured module that implements the hooks behaviour.

# `pipeline_hook?`

True when the hook transforms its input (a `before_*` pipeline hook) rather
than fanning out notifications. Exposed for the admin runtime page.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
