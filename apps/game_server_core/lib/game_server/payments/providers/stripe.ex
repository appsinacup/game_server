defmodule GameServer.Payments.Providers.Stripe do
  @moduledoc """
  Minimal Stripe Checkout and webhook adapter.
  """

  @checkout_url "https://api.stripe.com/v1/checkout/sessions"
  @timestamp_tolerance_seconds 300

  def create_checkout_session(purchase, provider_product, attrs) do
    with {:ok, secret_key} <- secret_key(),
         {:ok, success_url} <- required_attr(attrs, "success_url"),
         {:ok, cancel_url} <- required_attr(attrs, "cancel_url") do
      body = [
        {"mode", stripe_mode(provider_product.product.kind)},
        {"line_items[0][price]", provider_product.external_id},
        {"line_items[0][quantity]", to_string(purchase.quantity)},
        {"success_url", success_url},
        {"cancel_url", cancel_url},
        {"metadata[purchase_id]", to_string(purchase.id)},
        {"metadata[order_id]", purchase.order_id},
        {"metadata[user_id]", to_string(purchase.user_id)},
        {"metadata[product_sku]", provider_product.product.sku},
        {"payment_intent_data[metadata][purchase_id]", to_string(purchase.id)},
        {"payment_intent_data[metadata][order_id]", purchase.order_id},
        {"payment_intent_data[metadata][user_id]", to_string(purchase.user_id)},
        {"payment_intent_data[metadata][product_sku]", provider_product.product.sku}
      ]

      case Req.post(@checkout_url,
             auth: {:bearer, secret_key},
             form: body,
             headers: [{"content-type", "application/x-www-form-urlencoded"}]
           ) do
        {:ok, %{status: status, body: body}} when status in 200..299 and is_map(body) ->
          {:ok, body}

        {:ok, %{status: status, body: body}} ->
          {:error, {:stripe_error, status, body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  def verify_webhook(raw_body, signature_header) when is_binary(raw_body) do
    with {:ok, secret} <- webhook_secret(),
         {:ok, timestamp, signatures} <- parse_signature_header(signature_header),
         :ok <- validate_timestamp(timestamp),
         :ok <- validate_signature(raw_body, secret, timestamp, signatures) do
      Jason.decode(raw_body)
    end
  end

  defp stripe_mode("subscription"), do: "subscription"
  defp stripe_mode(_kind), do: "payment"

  defp secret_key do
    case System.get_env("STRIPE_SECRET_KEY") ||
           Application.get_env(:game_server_core, :stripe_secret_key) do
      key when is_binary(key) and key != "" -> {:ok, key}
      _ -> {:error, :stripe_not_configured}
    end
  end

  defp webhook_secret do
    case System.get_env("STRIPE_WEBHOOK_SECRET") ||
           Application.get_env(:game_server_core, :stripe_webhook_secret) do
      secret when is_binary(secret) and secret != "" -> {:ok, secret}
      _ -> {:error, :stripe_webhook_not_configured}
    end
  end

  defp required_attr(attrs, key) do
    case attrs[key] do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, String.to_atom("missing_#{key}")}
    end
  end

  defp parse_signature_header(nil), do: {:error, :missing_stripe_signature}

  defp parse_signature_header(header) when is_binary(header) do
    parts =
      header
      |> String.split(",", trim: true)
      |> Enum.map(fn part ->
        case String.split(part, "=", parts: 2) do
          [key, value] -> {key, value}
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    with {_, timestamp} <- Enum.find(parts, fn {key, _value} -> key == "t" end),
         {int, ""} <- Integer.parse(timestamp) do
      signatures =
        parts
        |> Enum.filter(fn {key, _value} -> key == "v1" end)
        |> Enum.map(fn {_key, value} -> value end)

      {:ok, int, signatures}
    else
      _ -> {:error, :invalid_stripe_signature}
    end
  end

  defp validate_timestamp(timestamp) when is_integer(timestamp) do
    now = DateTime.utc_now() |> DateTime.to_unix()

    if abs(now - timestamp) <= @timestamp_tolerance_seconds do
      :ok
    else
      {:error, :stale_stripe_signature}
    end
  end

  defp validate_signature(raw_body, secret, timestamp, signatures) do
    signed_payload = "#{timestamp}.#{raw_body}"

    expected =
      :crypto.mac(:hmac, :sha256, secret, signed_payload)
      |> Base.encode16(case: :lower)

    if Enum.any?(signatures, &secure_compare(&1, expected)) do
      :ok
    else
      {:error, :invalid_stripe_signature}
    end
  end

  defp secure_compare(left, right) when byte_size(left) == byte_size(right) do
    Plug.Crypto.secure_compare(left, right)
  end

  defp secure_compare(_left, _right), do: false
end
