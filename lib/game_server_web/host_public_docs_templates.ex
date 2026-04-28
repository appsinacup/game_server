defmodule GameServerWeb.HostPublicDocsTemplates do
  @moduledoc """
  Embedded HEEx templates used by the host-owned public docs LiveView.
  """

  use GameServerWeb, :html

  embed_templates "host_public_docs/*"
end
