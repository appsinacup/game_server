defmodule Mix.Tasks.Plugin.Bundle do
  use Mix.Task

  @shortdoc "Builds a plugin bundle into ./ebin (and deps/*/ebin)"

  @moduledoc """
  Builds a plugin bundle directory in the project root.

  This task:
  - runs `mix compile`
  - recreates `./ebin/`
  - copies compiled BEAMs and the `.app` file from the build output
  - copies compiled *runtime* dependency BEAMs into `./deps/<dep>/ebin/`

  The result is suitable for dropping the plugin directory into the server's
  plugin directory (e.g. `modules/plugins/<plugin_name>`), where the server will
  load:

  - `<plugin>/ebin`
  - `<plugin>/deps/*/ebin`

  Options:

    * `--no-clean` - do not delete the existing `./ebin` (and `deps/*/ebin`) first

  Notes:

  - Only dependencies with `runtime: true` (the default) are bundled.
  - Dependencies marked `runtime: false` are assumed to be compile-time only.
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

    copy_dir_contents!(build_ebin, dest_ebin)

    deps_to_bundle =
      Mix.Dep.load_and_cache()
      |> Enum.filter(fn dep ->
        dep_app = dep.app
        dep_app != Mix.Project.config()[:app] and dep.opts[:runtime] != false
      end)
      |> Enum.map(& &1.app)
      |> Enum.uniq()

    Enum.each(deps_to_bundle, fn dep_app ->
      dep_name = Atom.to_string(dep_app)
      src_dep_ebin = Path.join([build_lib_dir, dep_name, "ebin"])
      dest_dep_ebin = Path.expand(Path.join(["deps", dep_name, "ebin"]))

      if File.dir?(src_dep_ebin) do
        if File.dir?(dest_dep_ebin) and not no_clean? do
          File.rm_rf!(dest_dep_ebin)
        end

        File.mkdir_p!(dest_dep_ebin)
        copy_dir_contents!(src_dep_ebin, dest_dep_ebin)
      end
    end)

    Mix.shell().info("Bundled plugin ebin to #{dest_ebin}")
  end

  defp copy_dir_contents!(src_dir, dest_dir) do
    src_dir
    |> File.ls!()
    |> Enum.each(fn entry ->
      src = Path.join(src_dir, entry)
      dest = Path.join(dest_dir, entry)

      if File.dir?(src) do
        File.cp_r!(src, dest)
      else
        File.cp!(src, dest)
      end
    end)
  end
end
