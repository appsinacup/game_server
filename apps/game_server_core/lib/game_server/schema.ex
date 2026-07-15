defmodule GameServer.Schema do
  @moduledoc """
  Shared schema base: `use GameServer.Schema` instead of `use Ecto.Schema`.

  Sets UUIDv7 primary and foreign keys (see `GameServer.UUIDv7`) so ids are
  time-ordered but not enumerable.
  """

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema

      @primary_key {:id, GameServer.UUIDv7, autogenerate: true}
      @foreign_key_type GameServer.UUIDv7
    end
  end
end
