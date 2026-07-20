defmodule GameServer.Repo.Migrations.RenameNotificationTypes do
  @moduledoc """
  Rewrites persisted `notifications.metadata->>'type'` codes to the unified
  vocabulary (see the July 2026 event-naming pass):

    group_join_approved  -> group_join_request_approved
    group_join_declined  -> group_join_request_rejected
    friend_declined      -> friend_rejected

  Data-only. `metadata` is a `:map` — jsonb on Postgres, JSON text on SQLite —
  so the rewrite is adapter-specific.
  """
  use Ecto.Migration

  @renames [
    {"group_join_approved", "group_join_request_approved"},
    {"group_join_declined", "group_join_request_rejected"},
    {"friend_declined", "friend_rejected"}
  ]

  def up, do: Enum.each(@renames, fn {old, new} -> rewrite_type(old, new) end)

  # Reversible: map each new code back. group_join_declined and the realtime
  # negative both collapsed to *_rejected, but the reverse target here is the
  # notification-type original, which is unambiguous.
  def down, do: Enum.each(@renames, fn {old, new} -> rewrite_type(new, old) end)

  defp rewrite_type(from, to) do
    if postgres?() do
      execute(
        "UPDATE notifications SET metadata = jsonb_set(metadata, '{type}', '\"#{to}\"') " <>
          "WHERE metadata->>'type' = '#{from}'"
      )
    else
      execute(
        "UPDATE notifications SET metadata = json_set(metadata, '$.type', '#{to}') " <>
          "WHERE json_extract(metadata, '$.type') = '#{from}'"
      )
    end
  end

  defp postgres?, do: repo().__adapter__() == Ecto.Adapters.Postgres
end
