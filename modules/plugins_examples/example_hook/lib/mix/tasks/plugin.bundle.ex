defmodule Mix.Tasks.Plugin.Bundle do
  use Mix.Task

  @shortdoc "Builds a plugin bundle into ./ebin"

  @moduledoc """
  Builds a plugin bundle directory in the project root.

  This task:
  - runs `mix compile`
  - recreates `./ebin/`
  - copies compiled BEAMs and the `.app` file from the build output
  - copies compiled dependency BEAMs into `./deps/<dep>/ebin/`

  The result is an `ebin/` directory suitable for dropping into the server's
  plugin directory (e.g. `modules/plugins/example_hook/ebin`).

  Options:

    * `--no-clean` - do not delete the existing `./ebin` directory first

  Note: if your plugin depends on other OTP apps not available in the server
  release, you must also ship those dependencies' `ebin/` directories under
  `deps/<dep>/ebin` (see `docs/hooks-otp-plugins-plan.md` in the main repo).
  """

  @impl true
  def run(args) do
    {opts, _rest, _invalid} = OptionParser.parse(args, strict: [no_clean: :boolean])
    no_clean? = Keyword.get(opts, :no_clean, false)

    Mix.Task.run("compile", [])

    dest_ebin = Path.expand("ebin")

    build_app_path = Mix.Project.app_path()
    build_ebin = Path.join(build_app_path, "ebin")
    build_lib_dir = Path.dirname(build_app_path)

    unless File.dir?(build_ebin) do
      Mix.raise("Expected compiled ebin dir at #{build_ebin}, but it does not exist")
    end

    if File.dir?(dest_ebin) and not no_clean? do
      File.rm_rf!(dest_ebin)
    end

    File.mkdir_p!(dest_ebin)

    build_ebin
    |> File.ls!()
    |> Enum.each(fn entry ->
      src = Path.join(build_ebin, entry)
      dest = Path.join(dest_ebin, entry)

      cond do
        File.dir?(src) ->
          File.cp_r!(src, dest)

        true ->
          File.cp!(src, dest)
      end
    end)

    # Also bundle compiled dependency BEAMs.
    # These are loaded by the server from `deps/*/ebin` under the plugin directory.
    deps_to_bundle =
      Mix.Dep.load_and_cache()
      |> Enum.map(& &1.app)
      |> Enum.uniq()
      |> Enum.reject(&(&1 in [:example_hook, :game_server_sdk]))

    Enum.each(deps_to_bundle, fn dep_app ->
      dep_name = Atom.to_string(dep_app)
      src_dep_ebin = Path.join([build_lib_dir, dep_name, "ebin"])
      dest_dep_ebin = Path.expand(Path.join(["deps", dep_name, "ebin"]))

      if File.dir?(src_dep_ebin) do
        if File.dir?(dest_dep_ebin) and not no_clean? do
          File.rm_rf!(dest_dep_ebin)
        end

        File.mkdir_p!(dest_dep_ebin)

        src_dep_ebin
        |> File.ls!()
        |> Enum.each(fn entry ->
          src = Path.join(src_dep_ebin, entry)
          dest = Path.join(dest_dep_ebin, entry)

          cond do
            File.dir?(src) ->
              File.cp_r!(src, dest)

            true ->
              File.cp!(src, dest)
          end
        end)
      end
    end)

    Mix.shell().info("Bundled plugin ebin to #{dest_ebin}")
  end
end
