repo_config = Application.get_env(:game_server_core, GameServer.Repo, [])

if repo_config[:adapter] == Ecto.Adapters.SQLite3 do
  ExUnit.configure(max_cases: 1)
end

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(GameServer.Repo, :manual)

# Some auth controller flows require these env vars at runtime.
# Keep them stable across async tests to avoid cross-test races.
System.put_env("APPLE_WEB_CLIENT_ID", System.get_env("APPLE_WEB_CLIENT_ID") || "com.example.web")
System.put_env("APPLE_IOS_CLIENT_ID", System.get_env("APPLE_IOS_CLIENT_ID") || "com.example.ios")
