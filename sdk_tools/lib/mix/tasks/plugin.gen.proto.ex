defmodule Mix.Tasks.Plugin.Gen.Proto do
  use Mix.Task

  @shortdoc "Generates protobuf bindings from the plugin's proto/ directory"

  @moduledoc """
  Generates protobuf bindings from the plugin's `proto/*.proto` files — the
  game's single schema source for typed hooks (`<FnName>Request`/`Reply`),
  entity metadata (`UserMeta`/`LobbyMeta`/`GroupMeta`/`PartyMeta`) and KV
  data (`kv_schemas/0`).

  By default only the Elixir bindings are generated (into `lib/`, compiled
  into the plugin). Client bindings are generated on request so the same
  proto file feeds every side of the wire:

      mix plugin.gen.proto
      mix plugin.gen.proto --godot-out ../../godot/addons/my_game/my_game_pb.gd
      mix plugin.gen.proto --js-out ../../assets/js/my_game_pb.js

  ## Options

    * `--proto DIR`     - proto source directory (default: `proto`)
    * `--elixir-out DIR`- Elixir output directory (default: `lib`)
    * `--no-elixir`     - skip the Elixir bindings
    * `--godot-out FILE`- also generate a godobuf GDScript file. Requires
      `GODOT_BIN` (a Godot 4 binary) and `GODOBUF_DIR` (a checkout of
      https://github.com/oniksan/godobuf) in the environment. godobuf's
      proto3 `optional` presence checks are fixed up automatically.
    * `--js-out FILE`   - also generate a protobufjs ES module (static,
      `--keep-case`, requires `npx`)

  ## Requirements

  Elixir generation needs `protoc` (e.g. `brew install protobuf`) and the
  `protoc-gen-elixir` escript:

      mix escript.install hex protobuf

  """

  @impl true
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [proto: :string, elixir_out: :string, no_elixir: :boolean, godot_out: :string, js_out: :string]
      )

    proto_dir = Keyword.get(opts, :proto, "proto")
    protos = Path.wildcard(Path.join(proto_dir, "*.proto"))

    if protos == [] do
      Mix.raise("No .proto files found in #{Path.expand(proto_dir)}")
    end

    unless Keyword.get(opts, :no_elixir, false) do
      gen_elixir(protos, proto_dir, Keyword.get(opts, :elixir_out, "lib"))
    end

    if out = Keyword.get(opts, :godot_out), do: gen_godot(protos, out)
    if out = Keyword.get(opts, :js_out), do: gen_js(protos, out)

    Mix.shell().info("protobuf bindings generated for #{Enum.join(protos, ", ")}")
  end

  # ── Elixir (protoc + protoc-gen-elixir) ─────────────────────────────────

  defp gen_elixir(protos, proto_dir, out_dir) do
    protoc = System.find_executable("protoc") || Mix.raise("protoc not found — install protobuf (e.g. brew install protobuf)")

    plugin_path = protoc_gen_elixir!()
    File.mkdir_p!(out_dir)

    args =
      ["--elixir_out=#{out_dir}", "--proto_path=#{proto_dir}", "--plugin=protoc-gen-elixir=#{plugin_path}"] ++ protos

    run!(protoc, args, "protoc (elixir)")
  end

  defp protoc_gen_elixir! do
    escripts = Path.join([System.user_home!(), ".mix", "escripts", "protoc-gen-elixir"])

    cond do
      path = System.find_executable("protoc-gen-elixir") -> path
      File.exists?(escripts) -> escripts
      true -> Mix.raise("protoc-gen-elixir not found — run: mix escript.install hex protobuf")
    end
  end

  # ── Godot (godobuf + proto3-optional presence fix) ───────────────────────

  defp gen_godot(protos, out_file) do
    godot = System.get_env("GODOT_BIN") || Mix.raise("--godot-out requires GODOT_BIN (a Godot 4 binary)")
    godobuf = System.get_env("GODOBUF_DIR") || Mix.raise("--godot-out requires GODOBUF_DIR (a github.com/oniksan/godobuf checkout)")

    unless File.exists?(Path.join(godobuf, "addons/godobuf/godobuf_cmdln.gd")) do
      Mix.raise("GODOBUF_DIR does not look like a godobuf checkout: #{godobuf}")
    end

    # godobuf compiles one input file; multiple protos need one entry file.
    input =
      case protos do
        [single] -> Path.expand(single)
        _ -> Mix.raise("--godot-out supports a single .proto file (found #{length(protos)}); use imports in one entry file")
      end

    out = Path.expand(out_file)
    File.mkdir_p!(Path.dirname(out))

    run!(
      godot,
      ["--headless", "-s", "addons/godobuf/godobuf_cmdln.gd", "--input=#{input}", "--output=#{out}"],
      "godobuf",
      cd: godobuf
    )

    fix_godobuf_presence!(out)
  end

  # godobuf generates scalar `has_x()` as `value != null`, but scalars are
  # initialized to their type default (never null), so absent proto3-optional
  # fields would read as present-with-default and delta semantics would
  # break. The decoder does track presence via `data[tag].state == FILLED`
  # (godobuf itself uses that for oneofs), so rewrite the null-check bodies.
  defp fix_godobuf_presence!(path) do
    lines = path |> File.read!() |> String.split("\n")

    field_decl = ~r/^\t+__(\w+) = PBField\.new\("\1", PB_DATA_TYPE\.\w+, PB_RULE\.\w+, (\d+),/
    has_func = ~r/^(\t+)func has_(\w+)\(\) -> bool:$/

    {out, _tags, rewritten} = rewrite_presence(lines, %{}, [], 0, field_decl, has_func)

    File.write!(path, out |> Enum.reverse() |> Enum.join("\n"))
    Mix.shell().info("fixed #{rewritten} godobuf has_() presence checks in #{path}")
  end

  defp rewrite_presence([], tags, acc, rewritten, _fd, _hf), do: {acc, tags, rewritten}

  defp rewrite_presence([line | rest], tags, acc, rewritten, field_decl, has_func) do
    cond do
      match = Regex.run(field_decl, line) ->
        [_, name, tag] = match
        rewrite_presence(rest, Map.put(tags, name, tag), [line | acc], rewritten, field_decl, has_func)

      (match = Regex.run(has_func, line)) && presence_body?(rest, Enum.at(match, 2)) &&
          Map.has_key?(tags, Enum.at(match, 2)) ->
        [_, indent, name] = match
        replacement = "#{indent}\treturn data[#{tags[name]}].state == PB_SERVICE_STATE.FILLED"
        rest = Enum.drop(rest, 3)
        rewrite_presence(rest, tags, [replacement, line | acc], rewritten + 1, field_decl, has_func)

      true ->
        rewrite_presence(rest, tags, [line | acc], rewritten, field_decl, has_func)
    end
  end

  defp presence_body?(rest, name) do
    match?(
      [a, b, c | _] when is_binary(a) and is_binary(b) and is_binary(c),
      rest
    ) and
      String.trim(Enum.at(rest, 0)) == "if __#{name}.value != null:" and
      String.trim(Enum.at(rest, 1)) == "return true" and
      String.trim(Enum.at(rest, 2)) == "return false"
  end

  # ── JavaScript (protobufjs static module) ────────────────────────────────

  defp gen_js(protos, out_file) do
    npx = System.find_executable("npx") || Mix.raise("--js-out requires npx (Node.js)")
    out = Path.expand(out_file)
    File.mkdir_p!(Path.dirname(out))

    args =
      ["-y", "-p", "protobufjs-cli", "pbjs", "-t", "static-module", "-w", "es6", "--keep-case",
       "--no-create", "--no-verify", "--no-delimited", "-o", out] ++ protos

    run!(npx, args, "pbjs")
  end

  defp run!(cmd, args, label, opts \\ []) do
    case System.cmd(cmd, args, [stderr_to_stdout: true] ++ opts) do
      {_, 0} -> :ok
      {output, code} -> Mix.raise("#{label} failed (exit #{code}):\n#{output}")
    end
  end
end
