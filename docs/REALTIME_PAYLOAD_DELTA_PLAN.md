# Realtime Payload Delta Plan

## Goal

Reduce realtime payload size for channel updates.

Current channel updates resend whole user/lobby/group/party payloads. This is wasteful when large nested fields, especially `metadata`, change only a few values.

## Scope

Optimize Phoenix channel events first:

- `user:*` `"updated"`
- `lobby:*` `"updated"`
- `lobbies` `"lobby_updated"`
- `party:*` `"updated"`
- `group:*` `"updated"`
- `groups` `"group_updated"`
- `member_updated` on lobby, party, and group channels

Leave these unchanged for first pass:

- chat messages
- notifications
- achievements
- REST responses
- domain PubSub event shapes
- database schema

## Protocol

Initial state remains full snapshot:

```json
{
  "id": "0198c0de-...",
  "metadata": {
    "game_state": "playing",
    "boat_adventure": {
      "hp": 10,
      "coins_collected": 0
    }
  }
}
```

Update after baseline sends identity fields plus generic payload delta:

```json
{
  "id": "0198c0de-...",
  "u": {
    "player_count": 3,
    "metadata": {
      "boat_adventure": {
        "hp": 8,
        "coins_collected": 2
      }
    }
  },
  "r": {
    "metadata": {
      "game_ends_at": true
    }
  }
}
```

Keys:

- `u` = changed or added values
- `r` = removed keys
- `true` in `r` = delete this key

`metadata` is not special. It is diffed like any other map field:

```elixir
%{id: 123, u: %{metadata: %{"map" => "desert"}}}
%{id: 123, r: %{metadata: %{"old_key" => true}}}
```

No JSON Patch operations. No path arrays. No aliases inside game data.

## Diff Rules

- map vs map: recurse by key
- scalar changed: put new scalar in `u`
- list changed: replace full list in `u`
- key added: put value in `u`
- key removed: put `true` in matching `r` tree
- no changes: omit event
- empty `u` or `r`: omit branch

Example:

```elixir
old = %{
  "boat_adventure" => %{
    "hp" => 10,
    "stopped_until" => 1200,
    "level_layout" => %{
      "enemy_ships" => [%{"id" => "a", "hp" => 3}]
    }
  }
}

new = %{
  "boat_adventure" => %{
    "hp" => 8,
    "level_layout" => %{
      "enemy_ships" => [%{"id" => "a", "hp" => 2}]
    }
  }
}
```

Delta:

```elixir
%{
  u: %{
    "boat_adventure" => %{
      "hp" => 8,
      "level_layout" => %{
        "enemy_ships" => [%{"id" => "a", "hp" => 2}]
      }
    }
  },
  r: %{
    "boat_adventure" => %{
      "stopped_until" => true
    }
  }
}
```

## Server Changes

Add `GameServerWeb.PayloadDelta`.

Public function:

```elixir
payload_delta(old_payload, new_payload) :: nil | map()
```

Channel baseline state:

- per-user channel: `last_user_payload`
- per-lobby channel: `last_lobby_payload`
- per-party channel: `last_party_payload`
- per-group channel: `last_group_payload`
- global lobbies channel: `last_lobby_payloads` map by lobby id
- global groups channel: `last_group_payloads` map by group id
- member updates: `last_member_payloads` map by user id

Channel send flow:

1. Build current full payload using existing serializers.
2. If no baseline exists, push full payload and store baseline.
3. If baseline exists, compute generic recursive payload delta.
4. Send `%{id: id, u: updates, r: removes}`. Other identity keys such as `user_id` are preserved when present.
5. Store new full payload as baseline.
6. If no delta exists, suppress push.

Domain PubSub remains unchanged. LiveViews/admin screens still receive current full tuples such as `{:lobby_updated, lobby}`.

## Client Apply

Client keeps full local state from initial snapshot. On delta:

```js
function applyDelta(state, delta) {
  if (delta.u) merge(state, delta.u)
  if (delta.r) remove(state, delta.r)
  return state
}
```

`merge` recurses maps and replaces scalars/lists. `remove` recurses maps and deletes keys whose remove leaf is `true`.

## LiveView Impact

LiveView does not need this channel delta protocol.

Phoenix LiveView already sends rendered diffs to the browser, not raw full assigns. Current LiveViews subscribe to domain PubSub and usually reload data on update:

- lobby list reloads on `{:lobby_updated, _}`
- groups list reloads on `{:group_updated, _}`
- admin lobbies/groups/parties reload tables on update

This means:

- Browser LiveView transport is already diffed at rendered HTML level.
- Server still receives full PubSub structs and may reload DB rows.
- If a LiveView renders a large metadata JSON blob, changed blob text can still be large in the LiveView diff.
- Public LiveViews mostly reload/list summaries; admin edit/detail screens can render full metadata textareas/previews.

Conclusion: channel payload delta optimizes game clients. LiveView optimization is separate and lower priority.

Possible LiveView follow-up:

- avoid rendering large metadata in tables
- show metadata preview only
- lazy-load full metadata when opening edit/detail modal
- ignore metadata-only update events in pages that do not display metadata

Do not change domain PubSub to deltas for LiveView. That would complicate admin/public UI and break existing handlers.

## Tests

Unit tests for `PayloadDelta`:

- nested update
- nested delete
- add key
- list replacement
- no-op returns `nil`
- test-side delta apply reconstructs payload
- `metadata` diffed as normal nested payload field

Channel tests:

- join sends full snapshot
- first update after snapshot sends generic payload delta
- no-op update suppresses push
- lobby global channel tracks baselines per lobby id
- member update tracks baselines per user id
- party/group update uses same delta format

## Notes

This is intentionally not backward compatible for channel update payloads. Existing event names stay same, but update payload shape changes after initial snapshot.
