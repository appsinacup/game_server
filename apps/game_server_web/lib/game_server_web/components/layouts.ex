defmodule GameServerWeb.Layouts do
  @moduledoc """
  Compatibility facade for the host-owned layout shell.
  """

  use GameServerWeb, :html

  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :current_path, :string, default: nil, doc: "current request path for nav active state"

  attr :flush, :boolean,
    default: false,
    doc: "when true, render content edge-to-edge with no main wrapper, padding, or footer"

  slot :inner_block, required: true

  def app(assigns) do
    host_layouts = host_layouts()
    host_layouts.app(assigns)
  end

  def root(assigns) do
    host_layouts = host_layouts()
    host_layouts.root(assigns)
  end

  def icon_placements(icons) do
    host_layouts = host_layouts()
    host_layouts.icon_placements(icons)
  end

  def locale_labels do
    host_layouts = host_layouts()
    host_layouts.locale_labels()
  end

  def strip_locale_prefix(path, known_locales) do
    host_layouts = host_layouts()
    host_layouts.strip_locale_prefix(path, known_locales)
  end

  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    host_layouts = host_layouts()
    host_layouts.flash_group(assigns)
  end

  def theme_toggle(assigns) do
    host_layouts = host_layouts()
    host_layouts.theme_toggle(assigns)
  end

  defp host_layouts, do: Module.concat([GameServerWeb, HostLayouts])
end
