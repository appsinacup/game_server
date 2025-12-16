defmodule GameServer.Env do
  @moduledoc """
  Helpers for reading and parsing environment variables.

  Safe to use from `config/runtime.exs` (runs at runtime after compilation).
  """

  @type bool_default :: boolean()

  @spec bool(String.t(), bool_default()) :: boolean()
  def bool(name, default \\ false) when is_binary(name) and is_boolean(default) do
    case System.get_env(name) do
      nil ->
        default

      "" ->
        default

      v ->
        case String.downcase(String.trim(v)) do
          "true" -> true
          "1" -> true
          "yes" -> true
          "y" -> true
          "on" -> true
          "false" -> false
          "0" -> false
          "no" -> false
          "n" -> false
          "off" -> false
          "none" -> false
          _ -> default
        end
    end
  end

  @spec integer(String.t(), integer() | nil) :: integer() | nil
  def integer(name, default \\ nil) when is_binary(name) do
    case System.get_env(name) do
      nil -> default
      "" -> default
      v -> String.to_integer(String.trim(v))
    end
  end

  @spec atom_existing(String.t(), atom() | nil) :: atom() | nil
  def atom_existing(name, default \\ nil) when is_binary(name) do
    case System.get_env(name) do
      nil -> default
      "" -> default
      v -> String.to_existing_atom(String.trim(v))
    end
  end

  @spec log_level(String.t(), Logger.level() | false) :: Logger.level() | false
  def log_level(name, default \\ :debug) when is_binary(name) do
    case System.get_env(name) do
      nil ->
        default

      "" ->
        default

      v ->
        case String.downcase(String.trim(v)) do
          "false" -> false
          "0" -> false
          "off" -> false
          "none" -> false
          "debug" -> :debug
          "info" -> :info
          "warning" -> :warning
          "warn" -> :warning
          "error" -> :error
          _ -> default
        end
    end
  end
end
