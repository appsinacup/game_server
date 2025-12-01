defmodule GameServer.HooksRegistrationTest do
  # Registering files at runtime changes application state and can race with
  # other tests that expect a particular hooks module. Run serially to avoid
  # flakiness in CI where tests may run in parallel or with Postgres workers.
  use ExUnit.Case, async: false

  test "register_file/1 compiles and registers a module file at runtime" do
    orig = Application.get_env(:game_server, :hooks_module)
    on_exit(fn -> Application.put_env(:game_server, :hooks_module, orig) end)

    # compile & register from a temporary test-only hooks file (avoid using modules/example_hook.ex)
    tmp = Path.join(System.tmp_dir!(), "hooks_register_#{System.unique_integer([:positive])}.ex")

    mod =
      Module.concat([
        GameServer,
        TestHooks,
        String.to_atom("RegisterTest_#{System.unique_integer([:positive])}")
      ])

    src = """
    defmodule #{inspect(mod)} do
      @moduledoc false

      # implement minimal callback so register_file accepts the module
      def after_user_register(_user), do: :ok

      def example(), do: :ok
    end
    """

    File.write!(tmp, src)

    assert {:ok, regmod} = GameServer.Hooks.register_file(tmp)
    assert regmod == mod
    assert GameServer.Hooks.module() == mod

    # verify register_file recorded compile timestamp/status in app env
    assert is_binary(Application.get_env(:game_server, :hooks_last_compiled_at))
    assert Application.get_env(:game_server, :hooks_last_compile_status) == {:ok, regmod}

    File.rm!(tmp)
  end
end
