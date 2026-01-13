defmodule GameServerWeb.DocText do
  @moduledoc false

  @spec doc_text(String.t()) :: String.t()
  def doc_text(text) when is_binary(text), do: text

  @spec doc_text(String.t(), keyword()) :: String.t()
  def doc_text(text, bindings) when is_binary(text) and is_list(bindings) do
    :io_lib.format(text, bindings) |> IO.iodata_to_binary()
  end
end
