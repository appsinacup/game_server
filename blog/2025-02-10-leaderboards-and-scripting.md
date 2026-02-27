# Leaderboards and Server Scripting

We've added two major features to Gamend: server-authoritative leaderboards and server scripting with Elixir hooks.

## Leaderboards

Leaderboards support:

- Multiple scoring modes
- Time-based seasons
- Real-time ranking updates
- Configurable metadata per entry

## Server Scripting

Write custom server logic using Elixir scripts that run inside the server process. Hooks let you react to events like user joins, lobby creation, and more.

| Hook Event | Description |
|------------|-------------|
| `on_join` | Triggered when a user joins a lobby |
| `on_leave` | Triggered when a user leaves a lobby |
| `on_create` | Triggered when a lobby is created |

## What's Next

We're working on party matchmaking and improved group management. Stay tuned!
