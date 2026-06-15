[
  # Ecto.Multi.new/0 currently expands to a MapSet-backed struct Dialyzer reports
  # as incompatible with Ecto.Multi's own specs on OTP 29 / Elixir 1.20.
  {"lib/game_server/groups.ex", "Type mismatch in call without opaque term in insert."},
  {"lib/game_server/groups.ex", "Type mismatch in call without opaque term in run."},
  {"lib/game_server/lobbies.ex", "Type mismatch in call without opaque term in run."},
  # `use Mix.Task` emits this false positive in the generated task module.
  {"lib/mix/tasks/gen.sdk.ex", "The pattern can never match the type true."}
]
