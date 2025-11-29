defmodule GameServer.Hooks.InternalCallTest.ReturnOkTuple do
  def before_lobby_create(attrs), do: {:ok, Map.put(attrs, :x, 1)}
end

defmodule GameServer.Hooks.InternalCallTest.ReturnRaw do
  def before_lobby_create(attrs), do: Map.put(attrs, :raw, true)
end

defmodule GameServer.Hooks.InternalCallTest.NoCallbacks do
  # intentionally missing before_lobby_create
end

defmodule GameServer.Hooks.InternalCallTest do
  use ExUnit.Case, async: true
  alias GameServer.Hooks
  alias GameServer.Hooks.InternalCallTest.{NoCallbacks, ReturnOkTuple, ReturnRaw}

  setup do
    # preserve original config and restore after
    original = Application.get_env(:game_server, :hooks_module)

    on_exit(fn ->
      if original do
        Application.put_env(:game_server, :hooks_module, original)
      else
        Application.delete_env(:game_server, :hooks_module)
      end
    end)

    :ok
  end

  test "internal_call unwraps hook returning {:\:ok, value} (no double wrap)" do
    # create a temporary module under the test namespace that returns {:ok, attrs}
    mod = ReturnOkTuple

    Application.put_env(:game_server, :hooks_module, mod)

    # sanity-check the module exports
    assert function_exported?(mod, :before_lobby_create, 1)

    assert {:ok, %{name: "t1", x: 1}} =
             Hooks.internal_call(:before_lobby_create, [%{name: "t1"}])
  end

  test "internal_call unwraps hook returning raw value and wraps it in {:ok, value}" do
    mod = ReturnRaw

    Application.put_env(:game_server, :hooks_module, mod)

    assert function_exported?(mod, :before_lobby_create, 1)

    # raw return should be normalized to {:ok, value}
    assert {:ok, %{name: "t2", raw: true}} =
             Hooks.internal_call(:before_lobby_create, [%{name: "t2"}])
  end

  test "internal_call returns sensible default when callback missing" do
    mod = NoCallbacks

    Application.put_env(:game_server, :hooks_module, mod)

    assert {:ok, %{name: "t3"}} =
             Hooks.internal_call(:before_lobby_create, [%{name: "t3"}])
  end
end
