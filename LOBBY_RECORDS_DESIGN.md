# Lobby Records & Replay Design

Separate from the tournament system (TOURNAMENT_DESIGN.md) but adjacent: a
tournament match played in a lobby references that lobby in `match.metadata`,
so "re-watch that match" resolves here. Useful for every lobby game —
history screens, debugging, and replays — regardless of tournaments.

Not part of the tournament system, but adjacent (re-watching a tournament
match resolves to it): a tournament match played in a lobby references that
lobby in `match.metadata`; "what happened there" is a lobby-domain feature in
two layers:

1. **`lobby_records`** — one persistent row per lobby written at lobby end
   (title, host, members, started/ended, final metadata snapshot) plus a
   game-supplied result map (`Lobbies.record_result(lobby_id, map)` from a
   hook before the lobby closes). Enables history lists and debugging.
2. **Opt-in event journal** — lobbies created with `record: true` get an
   append-only `lobby_events` stream (lobby_id, seq, at, kind, payload) of
   everything the server broadcasts in lobby scope: `updated` deltas,
   member join/leave, `kv_updated` deltas. KV storage itself needs no
   history — the journal captures the updates as they streamed, which is what
   a replay re-applies. Chat is already persisted and joins by timestamp.
   Games add their own gameplay events via `Lobbies.append_event/3`
   (required for WebRTC P2P gameplay, which the server never sees).
   Pruned by the existing retention job.

## Open questions

- Journal size limits per lobby (event count / bytes cap) and what happens on
  overflow — stop recording vs. drop oldest.
- Replay access control: participants only, or public for public lobbies?
- Client SDK replay helper (re-apply journal over time) in scope, or leave
  playback entirely to games?
