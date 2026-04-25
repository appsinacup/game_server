[
  import_deps: [:ecto, :ecto_sql, :phoenix],
  subdirectories: ["priv/*/migrations", "apps/*/priv/*/migrations"],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: [
    "*.{heex,ex,exs}",
    "config/**/*.{heex,ex,exs}",
    "lib/**/*.{heex,ex,exs}",
    "apps/*/{lib,test}/**/*.{heex,ex,exs}",
    "apps/*/priv/*/seeds.exs"
  ]
]
