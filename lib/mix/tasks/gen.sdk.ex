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
    {GameServer.Accounts, "accounts.ex",
     [
       :get_user,
       :get_user_by_email,
       :search_users,
       :update_user,
       :register_user
     ]},
    {GameServer.Lobbies, "lobbies.ex",
     [
       :get_lobby,
       :get_lobby_by_name,
       :get_lobby_members,
       :list_lobbies,
       :create_lobby,
       :update_lobby,
       :delete_lobby,
       :join_lobby,
       :leave_lobby,
       :kick_user,
       :subscribe_lobbies,
       :subscribe_lobby
     ]},
    {GameServer.Leaderboards, "leaderboards.ex",
     [
       :get_leaderboard,
       :create_leaderboard,
       :update_leaderboard,
       :delete_leaderboard,
       :list_leaderboards,
       :submit_score,
       :list_records,
       :get_user_record,
       :delete_user_record
     ]},
    {GameServer.Friends, "friends.ex",
     [
       :create_request,
       :accept_friend_request,
       :reject_friend_request,
       :remove_friendship,
       :block_user,
       :unblock_user,
       :list_friends_for_user,
       :list_incoming_requests,
       :list_outgoing_requests,
       :list_blocked_users,
       :friends?
     ]}
  ]

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("compile")

    sdk_dir = Path.join([File.cwd!(), "sdk", "lib", "game_server"])
    File.mkdir_p!(sdk_dir)

    for {module, filename, functions} <- @sdk_modules do
      generate_stub(module, filename, functions, sdk_dir)
    end

    Mix.shell().info("SDK stubs generated in #{sdk_dir}")
  end

  defp generate_stub(module, filename, functions, sdk_dir) do
    {:docs_v1, _, :elixir, _, module_doc, _, function_docs} = Code.fetch_docs(module)

    specs = get_specs(module)

    module_doc_text =
      case module_doc do
        %{"en" => doc} -> doc
        _ -> ""
      end

    stub_content =
      generate_module_content(module, module_doc_text, functions, function_docs, specs)

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

  defp generate_module_content(module, module_doc, functions, function_docs, specs) do
    module_name = inspect(module)

    function_stubs =
      functions
      |> Enum.map(&generate_function_stub(&1, module_name, function_docs, specs))
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n\n")

    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
    #{indent_doc(module_doc, 2)}

      **Note:** This is an SDK stub. Calling these functions will raise an error.
      The actual implementation runs on the GameServer.
      \"\"\"

    #{function_stubs}
    end
    """
  end

  defp generate_function_stub(function_name, module_name, function_docs, specs) do
    # Find matching function docs (there might be multiple arities)
    matching_docs =
      Enum.filter(function_docs, fn
        {{:function, name, _arity}, _line, _sig, _doc, _meta} -> name == function_name
        _ -> false
      end)

    if matching_docs == [] do
      nil
    else
      # Get docs from first matching
      {{:function, _, arity}, _line, signatures, doc_content, _meta} = hd(matching_docs)

      doc_text =
        case doc_content do
          %{"en" => doc} -> doc
          _ -> ""
        end

      # Find spec if it exists
      spec_text = find_spec_text(function_name, arity, specs)

      # Extract parameter names from the signature
      ignored_args = extract_ignored_args_from_signature(signatures, arity)

      """
        @doc \"\"\"
      #{indent_doc(doc_text, 4)}
        \"\"\"
      #{spec_text}  def #{function_name}(#{ignored_args}) do
          raise "#{module_name}.#{function_name}/#{arity} is a stub - only available at runtime on GameServer"
        end
      """
    end
  end

  defp extract_ignored_args_from_signature(signatures, arity) when is_list(signatures) do
    case signatures do
      [sig | _] when is_binary(sig) ->
        # Parse "func_name(arg1, arg2, opts \\\\ [])" to get arg names
        case Regex.run(~r/\w+\(([^)]*)\)/, sig) do
          [_, args_str] ->
            args_str
            |> String.split(",")
            |> Enum.map(&extract_arg_name/1)
            |> Enum.take(arity)
            |> Enum.map_join(", ", &"_#{&1}")

          _ ->
            generate_ignored_args(arity)
        end

      _ ->
        generate_ignored_args(arity)
    end
  end

  defp extract_ignored_args_from_signature(_, arity), do: generate_ignored_args(arity)

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

  defp generate_ignored_args(0), do: ""

  defp generate_ignored_args(arity) do
    Enum.map_join(1..arity, ", ", &"_arg#{&1}")
  end

  defp indent_doc(doc, spaces) when is_binary(doc) do
    indent = String.duplicate(" ", spaces)

    doc
    |> String.split("\n")
    |> Enum.map_join("\n", &(indent <> &1))
  end

  defp indent_doc(_, _), do: ""
end
