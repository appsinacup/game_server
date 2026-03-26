defmodule GameServerWeb.Helpers.ParamParser do
  @moduledoc """
  Shared helpers for safely parsing controller parameters.

  Import into controllers that need safe integer parsing:

      import GameServerWeb.Helpers.ParamParser
  """

  @doc """
  Safely parse a value into an integer. Returns the integer or `nil`.

  Handles integers, numeric strings, and rejects everything else.

  ## Examples

      iex> parse_id(42)
      42
      iex> parse_id("42")
      42
      iex> parse_id("abc")
      nil
      iex> parse_id(nil)
      nil
  """
  @spec parse_id(term()) :: integer() | nil
  def parse_id(val) when is_integer(val), do: val

  def parse_id(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, ""} -> int
      _ -> nil
    end
  end

  def parse_id(_), do: nil

  @doc """
  Like `parse_id/1` but returns `{:ok, int}` or `:error`.
  """
  @spec parse_id!(term()) :: {:ok, integer()} | :error
  def parse_id!(val) do
    case parse_id(val) do
      nil -> :error
      int -> {:ok, int}
    end
  end
end
