defmodule GameServerWeb.I18n.ErrorsCatalog do
  @moduledoc false

  # This module exists only so `mix gettext.extract` can discover msgids
  # for changeset errors produced in `game_server_core`.
  #
  # Those errors are translated at runtime via:
  #   Gettext.dgettext(GameServerWeb.Gettext, "errors", msg, opts)
  # in `GameServerWeb.CoreComponents.translate_error/1`.
  #
  # By calling dgettext/2 here, we ensure the msgids are present in
  # `priv/gettext/errors.pot` and can be translated in `errors.po`.

  use Gettext, backend: GameServerWeb.Gettext

  def msgids do
    [
      dgettext("errors", "cannot friend yourself"),
      dgettext("errors", "did not change"),
      dgettext("errors", "does not exist"),
      dgettext("errors", "has already been taken"),
      dgettext("errors", "must be lowercase alphanumeric with underscores"),
      dgettext("errors", "must have the @ sign and no spaces"),
      dgettext("errors", "does not match password")
    ]
  end
end
