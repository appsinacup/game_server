defmodule GameServer.OAuthSessions do
  @moduledoc """
  Helpers for creating and retrieving short-lived OAuth sessions.
  """

  use Nebulex.Caching, cache: GameServer.Cache
  alias GameServer.OAuthSession
  alias GameServer.Repo

  @oauth_sessions_cache_ttl_ms 30_000

  defp invalidate_oauth_session_cache(session_id) when is_binary(session_id) do
    _ = GameServer.Cache.delete({:oauth_sessions, :session, session_id})
    :ok
  end

  @spec create_session(String.t(), map()) ::
          {:ok, OAuthSession.t()} | {:error, Ecto.Changeset.t()}
  def create_session(session_id, attrs \\ %{}) do
    attrs = Map.merge(%{session_id: session_id}, attrs)

    %OAuthSession{}
    |> OAuthSession.changeset(attrs)
    |> Repo.insert(on_conflict: :replace_all, conflict_target: :session_id)
    |> case do
      {:ok, _session} = ok ->
        _ = invalidate_oauth_session_cache(session_id)
        ok

      other ->
        other
    end
  end

  @spec get_session(String.t()) :: OAuthSession.t() | nil
  def get_session(session_id) do
    get_session_cached(session_id)
  end

  @decorate cacheable(
              key: {:oauth_sessions, :session, session_id},
              opts: [ttl: @oauth_sessions_cache_ttl_ms]
            )
  defp get_session_cached(session_id) when is_binary(session_id) do
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
        |> case do
          {:ok, _session} = ok ->
            _ = invalidate_oauth_session_cache(session_id)
            ok

          other ->
            other
        end
    end
  end
end
