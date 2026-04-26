seed_path = Application.app_dir(:game_server_core, "priv/repo/seeds.exs")

if File.exists?(seed_path) do
  Code.require_file(seed_path)
else
  IO.warn("No core seeds file found at: #{seed_path}")
end
