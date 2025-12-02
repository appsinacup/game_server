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

- `GameServer.Accounts` - User account management
- `GameServer.Lobbies` - Lobby management
- `GameServer.Leaderboards` - Leaderboard operations
- `GameServer.Friends` - Friend relationships
- `GameServer.Hooks` - Hook behaviour for custom game logic

### Implementing Hooks

Create your hooks module implementing the `GameServer.Hooks` behaviour:

```elixir
defmodule MyGame.Hooks do
  @behaviour GameServer.Hooks

  @impl true
  def after_register(user) do
    # Custom logic after user registration
    user
  end

  @impl true
  def rpc("give_coins", %{"amount" => amount}, caller) do
    # Handle RPC from game client
    {:ok, %{coins: amount}}
  end

  # ... implement other callbacks
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
