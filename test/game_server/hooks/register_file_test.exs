defmodule GameServer.Hooks.RegisterFileTest do
  use ExUnit.Case, async: true

  @tmp_dir System.tmp_dir!()

  setup do
    orig_module = Application.get_env(:game_server, :hooks_module)
    orig_status = Application.get_env(:game_server, :hooks_last_compile_status)
    orig_time = Application.get_env(:game_server, :hooks_last_compiled_at)

    on_exit(fn ->
      Application.put_env(:game_server, :hooks_module, orig_module)
      Application.put_env(:game_server, :hooks_last_compile_status, orig_status)
      Application.put_env(:game_server, :hooks_last_compiled_at, orig_time)
    end)

    :ok
  end

  test "registers a module with after_user_register/1" do
    n = System.unique_integer([:positive])
    mod = Module.concat([GameServer, TestHooks, String.to_atom("WithRegister#{n}")])
    path = Path.join(@tmp_dir, "hooks_#{System.unique_integer([:positive])}.ex")

    File.write!(
      path,
      "defmodule #{inspect(mod)} do\n  def after_user_register(_), do: :ok\nend\n"
    )

    assert {:ok, ^mod} = GameServer.Hooks.register_file(path)
    assert Application.get_env(:game_server, :hooks_module) == mod

    File.rm!(path)
  end

  test "reports invalid implementation when expected callback missing" do
    n = System.unique_integer([:positive])
    mod = Module.concat([GameServer, TestHooks, String.to_atom("NoRegister#{n}")])
    path = Path.join(@tmp_dir, "hooks_#{System.unique_integer([:positive])}_no.ex")

    File.write!(path, "defmodule #{inspect(mod)} do\n  def foo(), do: :ok\nend\n")

    assert {:error, :invalid_hooks_impl} = GameServer.Hooks.register_file(path)

    status = Application.get_env(:game_server, :hooks_last_compile_status)
    assert status == {:error, :invalid_hooks_impl}

    File.rm!(path)
  end

  test "reports no module in file" do
    path = Path.join(@tmp_dir, "hooks_#{System.unique_integer([:positive])}_empty.ex")
    File.write!(path, "# just a comment\n")

    assert {:error, :no_module_in_file} = GameServer.Hooks.register_file(path)

    File.rm!(path)
  end
end
