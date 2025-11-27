defmodule GameServer.OAuthSessionsTest do
  use GameServer.DataCase, async: true

  alias GameServer.OAuthSessions

  test "create, get and update session" do
    session_id = "sess_#{System.unique_integer([:positive])}"

    {:ok, session} = OAuthSessions.create_session(session_id, %{status: "started", data: %{a: 1}})
    assert session.session_id == session_id
    assert session.status == "started"

    fetched = OAuthSessions.get_session(session_id)
    assert fetched.id == session.id

    {:ok, updated} = OAuthSessions.update_session(session_id, %{status: "completed", data: %{a: 2}})
    assert updated.status == "completed"

    assert :not_found == OAuthSessions.update_session("nope", %{status: "x"})
  end
end
