defmodule GameServerWeb.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by
  channel tests that require socket support.

  It sets up the database sandbox and imports the
  conveniences from `Phoenix.ChannelTest` for testing channels.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Use the channel test helpers provided by Phoenix
      use Phoenix.ChannelTest

      # The default endpoint for testing
      @endpoint GameServerWeb.Endpoint

      import GameServerWeb.ChannelCase
    end
  end

  setup tags do
    GameServer.DataCase.setup_sandbox(tags)
    :ok
  end
end
