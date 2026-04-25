defmodule GameServerWeb.GettextSync do
  @moduledoc false

  def known_locales do
    Gettext.known_locales(GameServerWeb.Gettext)
  end

  def normalize_locale(locale) when is_binary(locale) do
    normalized =
      locale
      |> String.trim()
      |> String.replace("-", "_")

    Enum.find(known_locales(), fn known_locale ->
      String.downcase(known_locale) == String.downcase(normalized)
    end)
  end

  def normalize_locale(_locale), do: nil

  def put_locale(locale) when is_binary(locale) do
    Enum.each(backends(), &Gettext.put_locale(&1, locale))
  end

  def current_locale do
    Gettext.get_locale(host_backend())
  end

  def host_backend do
    backend = Application.get_env(:game_server_web, :host_gettext_backend, GameServerWeb.Gettext)

    if Code.ensure_loaded?(backend) do
      backend
    else
      GameServerWeb.Gettext
    end
  end

  defp backends do
    backend = host_backend()

    if backend == GameServerWeb.Gettext do
      [GameServerWeb.Gettext]
    else
      [GameServerWeb.Gettext, backend]
    end
  end
end
