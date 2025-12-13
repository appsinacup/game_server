defmodule Mix.Tasks.Gen.Sdk do
  @moduledoc """
  Generates SDK stub modules from the real GameServer modules.

  This task reads the real implementations and generates stub modules
  for the SDK package with matching type specs and documentation.

  ## Usage

      mix gen.sdk

  The generated files are placed in `sdk/lib/game_server/`.
  """
  use Mix.Task

  @shortdoc "Generate SDK stubs from real GameServer modules"

  @sdk_modules [
    {GameServer.Accounts, "accounts.ex"},
    {GameServer.Lobbies, "lobbies.ex"},
    {GameServer.Leaderboards, "leaderboards.ex"},
    {GameServer.Friends, "friends.ex"},
    {GameServer.Schedule, "schedule.ex"}
  ]

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("compile")

    sdk_dir = Path.join([File.cwd!(), "sdk", "lib", "game_server"])
    File.mkdir_p!(sdk_dir)

    for {module, filename} <- @sdk_modules do
      generate_stub(module, filename, sdk_dir)
    end

    Mix.shell().info("SDK stubs generated in #{sdk_dir}")
  end

  defp generate_stub(module, filename, sdk_dir) do
    {:docs_v1, _, :elixir, _, module_doc, _, function_docs} = Code.fetch_docs(module)

    specs = get_specs(module)

    functions = list_public_functions(module)

    function_docs_by_name = build_function_docs_by_name(function_docs)

    arg_names_by_mfa = build_arg_names_by_mfa(module)

    module_doc_text =
      case module_doc do
        %{"en" => doc} -> doc
        _ -> ""
      end

    stub_content =
      generate_module_content(
        module,
        module_doc_text,
        functions,
        function_docs,
        function_docs_by_name,
        arg_names_by_mfa,
        specs
      )

    path = Path.join(sdk_dir, filename)
    File.write!(path, stub_content)
    Mix.shell().info("Generated #{path}")
  end

  defp get_specs(module) do
    case Code.Typespec.fetch_specs(module) do
      {:ok, specs} -> specs
      :error -> []
    end
  end

  defp generate_module_content(
         module,
         module_doc,
         functions,
         function_docs,
         function_docs_by_name,
         arg_names_by_mfa,
         specs
       ) do
    module_name = inspect(module)

    function_stubs =
      functions
      |> Enum.map(
        &generate_function_stub(
          &1,
          module_name,
          function_docs,
          function_docs_by_name,
          arg_names_by_mfa,
          specs
        )
      )
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n\n")

    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
    #{indent_doc(escape_doc(module_doc), 2)}

      **Note:** This is an SDK stub. Calling these functions will raise an error.
      The actual implementation runs on the GameServer.
      \"\"\"

    #{function_stubs}
    end
    """
  end

  defp generate_function_stub(
         {function_name, arity},
         module_name,
         function_docs,
         function_docs_by_name,
         arg_names_by_mfa,
         specs
       )
       when is_atom(function_name) and is_integer(arity) do
    matching_doc =
      Enum.find(function_docs, fn
        {{:function, name, a}, _line, _sig, _doc, _meta} -> name == function_name and a == arity
        _ -> false
      end)

    {doc_text, signatures} =
      case matching_doc do
        {{:function, ^function_name, ^arity}, _line, sigs, doc_content, _meta} ->
          doc_text =
            case doc_content do
              %{"en" => doc} -> doc
              _ -> ""
            end

          {doc_text, sigs}

        _ ->
          fallback = Map.get(function_docs_by_name, function_name, nil)

          case fallback do
            %{doc_text: fallback_doc_text, signatures: fallback_sigs} ->
              {fallback_doc_text, fallback_sigs}

            _ ->
              {"", []}
          end
      end

    spec_text = find_spec_text(function_name, arity, specs)

    arg_names =
      arg_names_from_signature(signatures, arity)
      |> maybe_fallback_arg_names(function_name, arity, arg_names_by_mfa)

    arg_names = ensure_unique_arg_names(arg_names)

    ignored_args = Enum.map_join(arg_names, ", ", &"_#{&1}")

    doc_block =
      if doc_text == "" do
        "  @doc false\n"
      else
        """
          @doc \"\"\"
        #{indent_doc(escape_doc(doc_text), 4)}
          \"\"\"
        """
      end

    """
    #{doc_block}#{spec_text}  def #{function_name}(#{ignored_args}) do
        raise "#{module_name}.#{function_name}/#{arity} is a stub - only available at runtime on GameServer"
      end
    """
  end

  defp build_function_docs_by_name(function_docs) do
    function_docs
    |> Enum.reduce(%{}, fn
      {{:function, name, arity}, _line, sigs, doc_content, _meta}, acc ->
        doc_text =
          case doc_content do
            %{"en" => doc} -> doc
            _ -> ""
          end

        # Prefer an entry that actually has documentation.
        cond do
          doc_text == "" ->
            acc

          Map.has_key?(acc, name) ->
            existing = acc[name]

            if arity > existing.arity,
              do: Map.put(acc, name, %{arity: arity, doc_text: doc_text, signatures: sigs}),
              else: acc

          true ->
            Map.put(acc, name, %{arity: arity, doc_text: doc_text, signatures: sigs})
        end

      _, acc ->
        acc
    end)
  end

  defp list_public_functions(module) do
    module.__info__(:functions)
    |> Enum.reject(fn {name, _arity} ->
      name in [:module_info, :behaviour_info] or
        String.starts_with?(Atom.to_string(name), "__")
    end)
    |> Enum.sort_by(fn {name, arity} -> {Atom.to_string(name), arity} end)
  end

  defp arg_names_from_signature(signatures, arity) when is_list(signatures) do
    case signatures do
      [sig | _] when is_binary(sig) ->
        # Parse "func_name(arg1, arg2, opts \\ [])" to get arg names.
        # Note: function names can include ? and !
        case Regex.run(~r/[\w!?]+\(([^)]*)\)/, sig) do
          [_, args_str] ->
            args_str
            |> String.split(",")
            |> Enum.map(&extract_arg_name/1)
            |> Enum.take(arity)

          _ ->
            generate_arg_names(arity)
        end

      _ ->
        generate_arg_names(arity)
    end
  end

  defp arg_names_from_signature(_, arity), do: generate_arg_names(arity)

  defp maybe_fallback_arg_names(arg_names, function_name, arity, arg_names_by_mfa)
       when is_list(arg_names) do
    has_auto = Enum.any?(arg_names, &String.match?(&1, ~r/^arg\d+$/))

    cond do
      arg_names == [] ->
        Map.get(arg_names_by_mfa, {function_name, arity}, generate_arg_names(arity))

      has_auto ->
        Map.get(arg_names_by_mfa, {function_name, arity}, arg_names)

      true ->
        arg_names
    end
  end

  defp extract_arg_name(arg_str) do
    arg_str
    |> String.trim()
    # Remove default value (opts \\\\ [])
    |> String.replace(~r/\\\\.*$/, "")
    |> String.trim()
  end

  defp find_spec_text(function_name, arity, specs) do
    case Enum.find(specs, fn {{name, a}, _} -> name == function_name and a == arity end) do
      {{_, _}, [spec | _]} ->
        # spec is a single spec clause, wrap in list for spec_to_quoted
        try do
          spec_str = Macro.to_string(Code.Typespec.spec_to_quoted(function_name, spec))
          "  @spec #{spec_str}\n"
        rescue
          _ -> ""
        end

      _ ->
        ""
    end
  end

  defp generate_arg_names(0), do: []

  defp generate_arg_names(arity) do
    Enum.map(1..arity, &"arg#{&1}")
  end

  defp build_arg_names_by_mfa(module) do
    source = module.module_info(:compile)[:source]

    with true <- is_list(source),
         source_path <- List.to_string(source),
         {:ok, content} <- File.read(source_path),
         {:ok, ast} <- Code.string_to_quoted(content) do
      {_, acc} =
        Macro.prewalk(ast, %{}, fn
          {:def, _meta, [head, _body]} = node, acc ->
            {node, maybe_put_def_arg_names(head, acc)}

          {:defp, _meta, [head, _body]} = node, acc ->
            {node, maybe_put_def_arg_names(head, acc)}

          node, acc ->
            {node, acc}
        end)

      acc
    else
      _ ->
        %{}
    end
  end

  defp maybe_put_def_arg_names(head, acc) do
    {name, args_ast} =
      case head do
        {:when, _meta, [{fun_name, _meta2, args}, _guard]}
        when is_atom(fun_name) and is_list(args) ->
          {fun_name, args}

        {fun_name, _meta, args} when is_atom(fun_name) and is_list(args) ->
          {fun_name, args}

        _ ->
          {nil, nil}
      end

    if is_atom(name) and is_list(args_ast) do
      arity = length(args_ast)

      arg_names =
        args_ast
        |> Enum.with_index(1)
        |> Enum.map(fn {arg_ast, idx} ->
          arg_name_from_pattern(arg_ast, idx)
        end)

      # Populate entries for default-arg arities too (eg. def f(a, b \\ 1)
      # exports f/1 and f/2).
      Enum.reduce(0..arity, acc, fn a, acc ->
        Map.put_new(acc, {name, a}, Enum.take(arg_names, a))
      end)
    else
      acc
    end
  end

  defp arg_name_from_pattern({:=, _meta, [_left, {var, _m, _c}]}, _idx) when is_atom(var) do
    var
    |> Atom.to_string()
    |> String.trim_leading("_")
    |> blank_to("arg")
  end

  defp arg_name_from_pattern({:%, _meta, [alias_ast, map_ast]}, idx) do
    alias_last =
      case alias_ast do
        {:__aliases__, _m, parts} when is_list(parts) -> List.last(parts)
        atom when is_atom(atom) -> atom
        _ -> nil
      end

    base =
      if is_atom(alias_last) do
        Macro.underscore(Atom.to_string(alias_last))
      else
        "arg#{idx}"
      end

    hint = struct_var_hint(map_ast)

    if is_binary(hint) and hint != "" do
      hint
    else
      base
    end
  end

  defp arg_name_from_pattern({var, _m, _c}, idx) when is_atom(var) and var != :% do
    case Atom.to_string(var) do
      "_" -> "arg#{idx}"
      other -> other |> String.trim_leading("_") |> blank_to("arg#{idx}")
    end
  end

  defp arg_name_from_pattern(_other, idx), do: "arg#{idx}"

  defp struct_var_hint(map_ast) do
    # Try to infer a meaningful name from struct patterns like:
    #   %User{id: host_id} => "host"
    #   %User{id: target_id} => "target"
    case map_ast do
      {:%{}, _m, kvs} when is_list(kvs) ->
        kvs
        |> Enum.find_value(fn
          {:id, {var, _m2, _c2}} when is_atom(var) -> var
          _ -> nil
        end)
        |> case do
          nil ->
            nil

          var when is_atom(var) ->
            var
            |> Atom.to_string()
            |> String.trim_leading("_")
            |> String.trim_trailing("_id")
        end

      _ ->
        nil
    end
  end

  defp ensure_unique_arg_names(arg_names) when is_list(arg_names) do
    {uniq, _counts} =
      Enum.map_reduce(arg_names, %{}, fn name, counts ->
        name = if is_binary(name) and name != "", do: name, else: "arg"
        count = Map.get(counts, name, 0) + 1
        counts = Map.put(counts, name, count)
        uniq = if count == 1, do: name, else: "#{name}#{count}"
        {uniq, counts}
      end)

    uniq
  end

  defp blank_to("", fallback), do: fallback
  defp blank_to(val, _fallback), do: val

  defp indent_doc(doc, spaces) when is_binary(doc) do
    indent = String.duplicate(" ", spaces)

    doc
    |> String.split("\n")
    |> Enum.map_join("\n", &(indent <> &1))
  end

  defp indent_doc(_, _), do: ""

  defp escape_doc(doc) when is_binary(doc) do
    # Prevent docs that include "\"\"\"" from terminating the heredoc in generated files.
    String.replace(doc, "\"\"\"", "\\\"\\\"\\\"")
  end

  defp escape_doc(_), do: ""
end
