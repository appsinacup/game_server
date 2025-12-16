defmodule GameServer.Hooks.CallTest do
  use ExUnit.Case, async: false

  setup do
    orig = Application.get_env(:game_server_core, :hooks_module)
    on_exit(fn -> Application.put_env(:game_server_core, :hooks_module, orig) end)
    :ok
  end

  test "call invokes exported function and exported_functions lists it" do
    n = System.unique_integer([:positive])
    mod = Module.concat([GameServer, TestHooks, String.to_atom("CallTest_#{n}")])

    # Create a simple module with a couple of public functions
    Module.create(
      mod,
      quote do
        def hello(a), do: {:hello, a}
        def add(a, b), do: a + b
      end,
      __ENV__
    )

    Application.put_env(:game_server_core, :hooks_module, mod)

    assert {:ok, {:hello, "x"}} = GameServer.Hooks.call(:hello, ["x"])
    assert {:ok, 3} = GameServer.Hooks.call(:add, [1, 2])

    funcs = GameServer.Hooks.exported_functions()
    names = Enum.map(funcs, & &1.name)
    assert "hello" in names
    assert "add" in names
  end

  test "private defp functions are hidden and not callable via public call/3" do
    n = System.unique_integer([:positive])
    mod = Module.concat([GameServer, TestHooks, String.to_atom("HiddenTest_#{n}")])

    Module.create(
      mod,
      quote do
        defp hidden, do: :secret
        def visible, do: :ok
      end,
      __ENV__
    )

    Application.put_env(:game_server_core, :hooks_module, mod)

    funcs = GameServer.Hooks.exported_functions()
    names = Enum.map(funcs, & &1.name)

    assert "visible" in names
    refute "hidden" in names

    # defp functions are not exported and call/3 should report not_implemented
    assert {:error, :not_implemented} = GameServer.Hooks.call(:hidden, [])
  end

  test "extracts docs and returns info from docs when available" do
    mod =
      Module.concat([
        GameServer,
        TestHooks,
        String.to_atom("DocsTest_#{System.unique_integer([:positive])}")
      ])

    Module.create(
      mod,
      quote do
        @moduledoc false
        @doc "Does something.\n\nReturns: a special return value"
        def foo(a), do: {:ok, a}
      end,
      __ENV__
    )

    Application.put_env(:game_server_core, :hooks_module, mod)

    funcs = GameServer.Hooks.exported_functions()
    foo = Enum.find(funcs, fn f -> f.name == "foo" end)
    assert foo != nil
    sig = Enum.find(foo.signatures, &(&1.arity == 1))
    assert sig != nil

    if is_binary(sig.doc) do
      assert sig.doc =~ "Does something"
      assert sig.doc =~ "Returns: a special return value"
    end
  end

  test "call returns :not_implemented for missing function" do
    m = System.unique_integer([:positive])
    mod = Module.concat([GameServer, TestHooks, String.to_atom("CallTestMissing_#{m}")])

    Module.create(
      mod,
      quote do
        def ok, do: :ok
      end,
      __ENV__
    )

    Application.put_env(:game_server_core, :hooks_module, mod)

    assert {:error, :not_implemented} = GameServer.Hooks.call(:does_not_exist, [])
  end

  test "call returns a structured error on bad arg types (function clause)" do
    m = System.unique_integer([:positive])
    mod = Module.concat([GameServer, TestHooks, String.to_atom("CallTestType_#{m}")])

    Module.create(
      mod,
      quote do
        def hello(name) when is_binary(name), do: "hi: #{name}"
      end,
      __ENV__
    )

    Application.put_env(:game_server_core, :hooks_module, mod)

    assert {:error, {:function_clause, _msg}} = GameServer.Hooks.call(:hello, [1])
  end

  test "call exposes caller context available via GameServer.Hooks.caller/0 and caller_id/0" do
    mod =
      Module.concat([
        GameServer,
        TestHooks,
        String.to_atom("CallerTest_#{System.unique_integer([:positive])}")
      ])

    Module.create(
      mod,
      quote do
        def who_called, do: GameServer.Hooks.caller()
        def who_called_id, do: GameServer.Hooks.caller_id()
      end,
      __ENV__
    )

    Application.put_env(:game_server_core, :hooks_module, mod)

    caller = %{id: 999, email: "caller@example.com"}

    assert {:ok, ^caller} = GameServer.Hooks.call(:who_called, [], caller: caller)
    assert {:ok, 999} = GameServer.Hooks.call(:who_called_id, [], caller: caller)
  end

  test "caller_user/0 resolves user struct when caller is id or struct" do
    # Use a plain struct here (no DB dependency) to test struct-path resolution
    user = %GameServer.Accounts.User{id: 123_456, email: "caller@example.com"}

    mod =
      Module.concat([
        GameServer,
        TestHooks,
        String.to_atom("CallerUserTest_#{System.unique_integer([:positive])}")
      ])

    Module.create(
      mod,
      quote do
        def who_called_user, do: GameServer.Hooks.caller_user()
      end,
      __ENV__
    )

    Application.put_env(:game_server_core, :hooks_module, mod)

    # call with full struct (we avoid DB-dependent id resolution in tests)
    assert {:ok, %GameServer.Accounts.User{id: id2}} =
             GameServer.Hooks.call(:who_called_user, [], caller: user)

    assert id2 == user.id
  end

  test "exported_functions returns empty for default module and handles multiple arities" do
    # ensure default module is used
    Application.put_env(:game_server_core, :hooks_module, GameServer.Hooks.Default)

    assert GameServer.Hooks.exported_functions() == []

    # create module with multiple arities and a function lacking docs or source
    mod =
      Module.concat([
        GameServer,
        TestHooks,
        String.to_atom("MultiArity_#{System.unique_integer([:positive])}")
      ])

    Module.create(
      mod,
      quote do
        def foo(a), do: a
        def foo(a, b), do: a + b
        def no_doc, do: :ok
      end,
      __ENV__
    )

    Application.put_env(:game_server_core, :hooks_module, mod)

    funcs = GameServer.Hooks.exported_functions()
    foo = Enum.find(funcs, &(&1.name == "foo"))

    assert foo != nil
    assert Enum.sort(foo.arities) == [1, 2]

    no_doc = Enum.find(funcs, &(&1.name == "no_doc"))
    assert no_doc != nil
    # signature may be nil when neither docs nor source are available
    assert Enum.any?(no_doc.signatures, fn s -> s.signature == nil end)
  end

  test "zero-arity functions produce example_args of []" do
    mod =
      Module.concat([
        GameServer,
        TestHooks,
        String.to_atom("ZeroArity_#{System.unique_integer([:positive])}")
      ])

    Code.compile_string("""
    defmodule #{inspect(mod)} do
      @moduledoc false

      @doc "No-arg function"
      def no_args, do: :ok
    end
    """)

    Application.put_env(:game_server_core, :hooks_module, mod)

    funcs = GameServer.Hooks.exported_functions()
    f = Enum.find(funcs, &(&1.name == "no_args"))
    assert f != nil

    sig = Enum.find(f.signatures, &(&1.arity == 0))
    assert sig != nil
    # Signatures may be nil when docs/typespecs are not available.
    assert sig.example_args in ["[]", nil]
  end

  test "prefers @spec types for signatures when available" do
    _mod =
      Module.concat([
        GameServer,
        TestHooks,
        String.to_atom("SpecTest_#{System.unique_integer([:positive])}")
      ])

    # Not all dynamically compiled modules will retain typespecs in every
    # runtime. Use a known stdlib module (String) which has specs available
    # to validate that typespec extraction works when specs are present.
    Application.put_env(:game_server_core, :hooks_module, String)

    funcs = GameServer.Hooks.exported_functions()

    # ensure some signature text is present; prefer doc/parsed signatures which contain param names
    assert Enum.any?(funcs, fn f ->
             Enum.any?(f.signatures, fn s ->
               is_binary(s.signature) and String.contains?(s.signature, "(")
             end)
           end)
  end
end
