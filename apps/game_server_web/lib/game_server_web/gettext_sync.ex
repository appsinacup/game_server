defmodule GameServerWeb.GettextSync do
  @moduledoc false

  @spec known_locales() :: [String.t()]
  def known_locales do
    Gettext.known_locales(GameServerWeb.Gettext)
  end

  @spec normalize_locale(term()) :: String.t() | nil
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

  @spec put_locale(String.t()) :: :ok
  def put_locale(locale) when is_binary(locale) do
    Enum.each(backends(), &Gettext.put_locale(&1, locale))
  end

  @spec current_locale() :: String.t() | nil
  def current_locale do
    Gettext.get_locale(host_backend())
  end

  @spec host_backend() :: module()
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
