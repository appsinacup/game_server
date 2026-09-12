defmodule GamendWeb.JsTest do
  @moduledoc """
  The browser-side unit tests (`assets/js/test/*.test.mjs`), run under Node's
  built-in test runner so `mix test` covers them.

  They need no npm packages — the modules they test import nothing — so the only
  requirement is `node` on the PATH. Where it is missing the suite is skipped
  rather than failed.
  """
  use ExUnit.Case, async: true

  @node System.find_executable("node")
  @moduletag skip: is_nil(@node) && "node is not installed"

  test "assets/js/test passes under node --test" do
    files = Path.wildcard(Path.expand("../../assets/js/test/*.test.mjs", __DIR__))
    assert files != [], "no JS test files found"

    {output, status} = System.cmd(@node, ["--test" | files], stderr_to_stdout: true)
    assert status == 0, output
  end
end
