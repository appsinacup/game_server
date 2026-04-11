defmodule Mix.Tasks.Plugin.Bundle do
  use Mix.Task

  @shortdoc "Builds a plugin bundle into ./ebin, ./priv, and deps/*/{ebin,priv}"

  @moduledoc """
  Builds a plugin bundle directory in the project root.

  This task:
  - runs `mix compile`
  - recreates `./ebin/`
  - copies app `./priv/` when present
  - copies compiled BEAMs and the `.app` file from the build output
  - copies compiled *runtime* dependency BEAMs into `./deps/<dep>/ebin/`
  - copies runtime dependency `priv/` directories into `./deps/<dep>/priv/`

  The result is suitable for dropping the plugin directory into the server's
  plugin directory (e.g. `modules/plugins/<plugin_name>`), where the server will
  load:

  - `<plugin>/ebin`
  - `<plugin>/priv` (for NIFs and runtime assets)
  - `<plugin>/deps/*/ebin`
  - `<plugin>/deps/*/priv`

  Options:

    * `--no-clean` - do not delete the existing `./ebin` (and `deps/*/ebin`) first
    * `--verbose` - print detailed dep resolution and priv file listing

  Notes:

  - Only dependencies with `runtime: true` (the default) are bundled.
  - Dependencies marked `runtime: false` are assumed to be compile-time only.
  """

  @impl true
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args, strict: [no_clean: :boolean, verbose: :boolean])

    no_clean? = Keyword.get(opts, :no_clean, false)
    verbose? = Keyword.get(opts, :verbose, false)

    Mix.Task.run("compile", [])

    app_name = Mix.Project.config()[:app]
    dest_ebin = Path.expand("ebin")

    build_app_path = Mix.Project.app_path()
    build_ebin = Path.join(build_app_path, "ebin")
    build_priv = Path.join(build_app_path, "priv")
    build_lib_dir = Path.dirname(build_app_path)

    unless File.dir?(build_ebin) do
      Mix.raise("Expected compiled ebin dir at #{build_ebin}, but it does not exist")
    end

    if File.dir?(dest_ebin) and not no_clean? do
      File.rm_rf!(dest_ebin)
    end

    File.mkdir_p!(dest_ebin)

    copy_dir_contents!(build_ebin, dest_ebin)

    app_has_priv? = copy_optional_dir!(build_priv, Path.expand("priv"), no_clean?)
    info(verbose?, "App #{app_name}: ebin ✓, priv #{if app_has_priv?, do: "✓", else: "—"}")

    all_deps = Mix.Dep.load_and_cache()

    deps_to_bundle = runtime_dep_apps(all_deps, app_name)

    info(verbose?, "Build lib dir: #{build_lib_dir}")

    info(
      verbose?,
      "All deps (#{length(all_deps)}): #{all_deps |> Enum.map(& &1.app) |> Enum.sort() |> Enum.join(", ")}"
    )

    info(verbose?, "Runtime deps to bundle (#{length(deps_to_bundle)}): #{Enum.join(deps_to_bundle, ", ")}")

    priv_summary =
      Enum.map(deps_to_bundle, fn dep_app ->
        dep_name = Atom.to_string(dep_app)
        src_dep_ebin = Path.join([build_lib_dir, dep_name, "ebin"])
        src_dep_priv = Path.join([build_lib_dir, dep_name, "priv"])
        dest_dep_ebin = Path.expand(Path.join(["deps", dep_name, "ebin"]))
        dest_dep_priv = Path.expand(Path.join(["deps", dep_name, "priv"]))

        has_ebin? = File.dir?(src_dep_ebin)

        if has_ebin? do
          if File.dir?(dest_dep_ebin) and not no_clean? do
            File.rm_rf!(dest_dep_ebin)
          end

          File.mkdir_p!(dest_dep_ebin)
          copy_dir_contents!(src_dep_ebin, dest_dep_ebin)
        end

        has_priv? = copy_optional_dir!(src_dep_priv, dest_dep_priv, no_clean?)

        if verbose? do
          priv_files =
            if has_priv? do
              src_dep_priv
              |> list_files_recursive()
              |> Enum.join(", ")
            else
              ""
            end

          info(
            true,
            "  #{dep_name}: ebin #{if has_ebin?, do: "✓", else: "✗"}, priv #{if has_priv?, do: "✓ (#{priv_files})", else: "—"}"
          )
        end

        {dep_name, has_priv?}
      end)

    priv_deps = for {name, true} <- priv_summary, do: name

    Mix.shell().info(
      "Bundled plugin #{app_name}: ebin + #{length(deps_to_bundle)} deps" <>
        if(priv_deps != [], do: " (priv: #{Enum.join(priv_deps, ", ")})", else: "")
    )
  end

  defp copy_optional_dir!(src_dir, dest_dir, no_clean?) do
    if File.dir?(src_dir) do
      if File.dir?(dest_dir) and not no_clean? do
        File.rm_rf!(dest_dir)
      end

      File.mkdir_p!(dest_dir)
      copy_dir_contents!(src_dir, dest_dir)
      true
    else
      false
    end
  end

  defp runtime_dep_apps(deps, root_app) when is_list(deps) do
    deps
    |> collect_runtime_dep_apps(root_app, MapSet.new())
    |> MapSet.to_list()
    |> Enum.sort()
  end

  defp collect_runtime_dep_apps([], _root_app, acc), do: acc

  defp collect_runtime_dep_apps([dep | rest], root_app, acc) do
    acc = collect_runtime_dep_app(dep, root_app, acc)
    collect_runtime_dep_apps(rest, root_app, acc)
  end

  defp collect_runtime_dep_app(%{app: app, opts: opts, deps: deps}, root_app, acc) do
    cond do
      app == root_app ->
        collect_runtime_dep_apps(deps || [], root_app, acc)

      opts[:runtime] == false ->
        collect_runtime_dep_apps(deps || [], root_app, acc)

      true ->
        acc = MapSet.put(acc, app)
        collect_runtime_dep_apps(deps || [], root_app, acc)
    end
  end

  defp collect_runtime_dep_app(_dep, _root_app, acc), do: acc

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

  defp list_files_recursive(dir) do
    dir
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.reject(&File.dir?/1)
    |> Enum.map(&Path.relative_to(&1, dir))
  end

  defp info(true, msg), do: Mix.shell().info(msg)
  defp info(false, _msg), do: :ok
end
