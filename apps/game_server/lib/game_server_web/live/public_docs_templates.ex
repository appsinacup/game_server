defmodule GameServerWeb.PublicDocsTemplates do
  @moduledoc """
  Embedded HEEx templates used by the public docs LiveView.

  This module wraps `embed_templates "public_docs/*"` so templates can be
  referenced from `GameServerWeb.PublicDocs` and keeps large static pages
  cleanly separated into smaller .heex partials.
  """
  use GameServerWeb, :html

  embed_templates "public_docs/*"
end
