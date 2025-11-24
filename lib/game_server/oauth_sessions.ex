defmodule GameServer.OAuthSessions do
  @moduledoc """
  Helpers for creating and retrieving short-lived OAuth sessions.
  """

  import Ecto.Query, warn: false
  alias GameServer.Repo
  alias GameServer.OAuthSession

  @spec create_session(String.t(), map()) ::
          {:ok, OAuthSession.t()} | {:error, Ecto.Changeset.t()}
  def create_session(session_id, attrs \\ %{}) do
    attrs = Map.merge(%{session_id: session_id}, attrs)

    %OAuthSession{}
    |> OAuthSession.changeset(attrs)
    |> Repo.insert(on_conflict: :replace_all, conflict_target: :session_id)
  end

  @spec get_session(String.t()) :: OAuthSession.t() | nil
  def get_session(session_id) do
    Repo.get_by(OAuthSession, session_id: session_id)
  end

  @spec update_session(String.t(), map()) ::
          {:ok, OAuthSession.t()} | {:error, Ecto.Changeset.t()} | :not_found
  def update_session(session_id, attrs) do
    case get_session(session_id) do
      nil ->
        :not_found

      session ->
        session
        |> OAuthSession.changeset(attrs)
        |> Repo.update()
    end
  end
end
