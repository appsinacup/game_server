defmodule GameServerWeb.NotFoundError do
  @moduledoc """
  Raised to render a 404 from LiveViews/controllers — e.g. when a feature
  flag (`LIST_*_ENABLED`) disables a public listing page and it should look
  like the page does not exist.
  """
  defexception message: "not found", plug_status: 404
end
