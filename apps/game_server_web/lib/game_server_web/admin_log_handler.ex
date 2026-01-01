defmodule GameServerWeb.AdminLogHandler do
  @moduledoc false

  @behaviour :logger_handler

  alias GameServerWeb.AdminLogBuffer

  @handler_id :admin_ui

  def install do
    case :logger.get_handler_config(@handler_id) do
      {:ok, _config} ->
        :ok

      {:error, _} ->
        :logger.add_handler(@handler_id, __MODULE__, %{level: :debug})
    end
  end

  @impl true
  def adding_handler(config) do
    {:ok, config}
  end

  @impl true
  def removing_handler(_config) do
    :ok
  end

  @impl true
  def log(event, _config) do
    level = Map.get(event, :level)
    meta = Map.get(event, :meta, %{})

    entry = %{
      level: level,
      message: format_msg(event),
      module: Map.get(meta, :module),
      mfa: Map.get(meta, :mfa),
      meta: meta,
      timestamp: DateTime.utc_now()
    }

    AdminLogBuffer.put(entry)

    :ok
  end

  defp format_msg(%{msg: {:string, chardata}}) do
    chardata |> IO.iodata_to_binary() |> strip_trailing_newline()
  end

  defp format_msg(%{msg: {:format, format, args}}) do
    :io_lib.format(format, args) |> IO.iodata_to_binary() |> strip_trailing_newline()
  end

  defp format_msg(%{msg: {:report, report}}) do
    inspect(report) |> strip_trailing_newline()
  end

  defp format_msg(event) do
    inspect(Map.get(event, :msg)) |> strip_trailing_newline()
  end

  defp strip_trailing_newline(str) when is_binary(str) do
    String.trim_trailing(str, "\n")
  end
end
