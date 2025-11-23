defmodule GameServerWeb.Auth.AssignCurrentScope do
  @moduledoc """
  Plug to assign current_scope from Guardian's loaded user resource.

  This ensures compatibility with the existing scope-based authorization system.
  """

  import Plug.Conn

  alias GameServer.Accounts.Scope

  def init(opts), do: opts

  def call(conn, _opts) do
    case Guardian.Plug.current_resource(conn) do
      nil ->
        assign(conn, :current_scope, Scope.for_user(nil))

      user ->
        assign(conn, :current_scope, Scope.for_user(user))
    end
  end
end
