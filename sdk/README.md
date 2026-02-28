# GameServer SDK

SDK for GameServer hooks development. This package provides type specs, documentation,
and IDE autocomplete for GameServer modules without requiring the full server.

## Installation

Add `game_server_sdk` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:game_server_sdk, "~> 0.1.0"}
  ]
end
```

## Usage

This SDK provides stub modules that match the GameServer API:

### Core Modules

- `GameServer.Accounts` - User account management (registration, login, profile updates, metadata)
- `GameServer.Lobbies` - Lobby management (create, join, leave, kick, host transfer)
- `GameServer.Groups` - Group management (create, join, leave, invite, promote/demote, join requests)
- `GameServer.Parties` - Ephemeral party management (create, join by code, lobby integration)
- `GameServer.Leaderboards` - Leaderboard operations (submit scores, rankings, seasonal resets)
- `GameServer.Friends` - Friend relationships and blocking (send/accept/decline requests, block/unblock)
- `GameServer.Notifications` - In-app notification delivery (friend requests, group invites, system alerts)
- `GameServer.KV` - Generic key/value storage (server-side persistent storage for game data)
- `GameServer.Schedule` - Dynamic cron-like job scheduling for hooks

### Behaviour & Types

- `GameServer.Hooks` - Hook behaviour for custom game logic (lifecycle callbacks, RPC functions)
- `GameServer.Types` - Shared types used across GameServer contexts

### Implementing Hooks

Create your hooks module using `use GameServer.Hooks` to get default implementations
for all callbacks, then override only the ones you need:

```elixir
defmodule MyGame.Hooks do
  use GameServer.Hooks

  @impl true
  def after_user_register(user) do
    # Give new users starting coins
    GameServer.Accounts.update_user(user, %{
      metadata: Map.put(user.metadata || %{}, "coins", 100)
    })
  end

  @impl true
  def before_group_create(user, attrs) do
    # Check if user has enough coins to create a group
    coins = get_in(user.metadata, ["coins"]) || 0
    if coins >= 50, do: {:ok, attrs}, else: {:error, :not_enough_coins}
  end

  @impl true
  def before_lobby_join(user, lobby, opts) do
    # Check level requirements
    {:ok, {user, lobby, opts}}
  end

  # Custom RPC - callable from game clients
  def give_coins(amount, _opts) do
    caller = GameServer.Hooks.caller_user()
    coins = get_in(caller.metadata, ["coins"]) || 0
    GameServer.Accounts.update_user(caller, %{
      metadata: Map.put(caller.metadata, "coins", coins + amount)
    })
  end
end
```

### Module APIs

The SDK modules provide the same API as the real GameServer:

```elixir
# Get user by ID (returns nil if not found)
user = GameServer.Accounts.get_user(user_id)

# Update user metadata
{:ok, user} = GameServer.Accounts.update_user(user, %{metadata: %{level: 5}})

# Submit leaderboard score
{:ok, record} = GameServer.Leaderboards.submit_score(leaderboard_id, user_id, 1000)

# Get lobby members
members = GameServer.Lobbies.get_lobby_members(lobby)
```

## Note

This SDK only provides type specifications and documentation for IDE support.
The actual implementations run on the GameServer - these stubs will raise
`RuntimeError` if called directly.
