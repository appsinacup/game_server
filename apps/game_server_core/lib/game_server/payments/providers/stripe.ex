defmodule GameServer.Payments.Providers.Stripe do
  @moduledoc """
  Minimal Stripe Checkout and webhook adapter.
  """

  alias GameServer.Payments.ProviderConfig

  @webhook_tolerance_seconds 300

  def create_checkout_session(purchase, provider_product, attrs) do
    with {:ok, secret_key} <- secret_key(),
         {:ok, success_url} <- required_attr(attrs, "success_url"),
         {:ok, cancel_url} <- required_attr(attrs, "cancel_url") do
      metadata = checkout_metadata(purchase, provider_product)
      mode = stripe_mode(provider_product.product.kind)

      params =
        checkout_params(provider_product, purchase, success_url, cancel_url, mode, metadata)

      case create_checkout_session_with_sdk(
             params,
             stripe_request_opts(secret_key, purchase)
           ) do
        {:ok, session} ->
          {:ok, normalize_stripe_payload(session)}

        {:error, reason} ->
          {:error, {:stripe_error, normalize_stripe_payload(reason)}}
      end
    end
  end

  def verify_webhook(_raw_body, nil), do: {:error, :missing_stripe_signature}

  def verify_webhook(raw_body, signature_header)
      when is_binary(raw_body) and is_binary(signature_header) do
    with {:ok, secret} <- webhook_secret() do
      case construct_webhook_event_with_sdk(
             raw_body,
             signature_header,
             secret,
             @webhook_tolerance_seconds
           ) do
        {:ok, event} ->
          {:ok, normalize_stripe_payload(event)}

        {:error, reason} ->
          {:error, stripe_webhook_error(reason)}
      end
    end
  end

  def verify_webhook(_raw_body, _signature_header), do: {:error, :invalid_stripe_payload}

  defp stripe_mode("subscription"), do: "subscription"
  defp stripe_mode(_kind), do: "payment"

  defp checkout_metadata(purchase, provider_product) do
    %{
      "purchase_id" => to_string(purchase.id),
      "order_id" => purchase.order_id,
      "user_id" => to_string(purchase.user_id),
      "product_sku" => provider_product.product.sku
    }
  end

  defp checkout_params(provider_product, purchase, success_url, cancel_url, mode, metadata) do
    %{
      mode: mode,
      line_items: [
        %{
          price: provider_product.external_id,
          quantity: purchase.quantity
        }
      ],
      success_url: success_url,
      cancel_url: cancel_url,
      metadata: metadata
    }
    |> put_checkout_payment_metadata(mode, metadata)
  end

  defp put_checkout_payment_metadata(params, "subscription", metadata) do
    Map.put(params, :subscription_data, %{metadata: metadata})
  end

  defp put_checkout_payment_metadata(params, _mode, metadata) do
    Map.put(params, :payment_intent_data, %{metadata: metadata})
  end

  defp stripe_request_opts(secret_key, purchase) do
    [
      api_key: secret_key,
      api_version: ProviderConfig.stripe_api_version(),
      idempotency_key: purchase.order_id
    ]
  end

  defp secret_key do
    case ProviderConfig.stripe_secret_key() do
      key when is_binary(key) and key != "" -> {:ok, key}
      _ -> {:error, :stripe_not_configured}
    end
  end

  defp webhook_secret do
    case ProviderConfig.stripe_webhook_secret() do
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

  defp stripe_client do
    Application.get_env(:game_server_core, :stripe_client, __MODULE__.Client)
  end

  defp create_checkout_session_with_sdk(params, opts) do
    stripe_client().create_checkout_session(params, opts)
  rescue
    exception -> {:error, exception}
  end

  defp construct_webhook_event_with_sdk(raw_body, signature_header, secret, tolerance_seconds) do
    stripe_client().construct_webhook_event(raw_body, signature_header, secret, tolerance_seconds)
  rescue
    exception -> {:error, {:stripe_webhook_error, Exception.message(exception)}}
  end

  defp stripe_webhook_error({:stripe_webhook_error, _reason} = error), do: error
  defp stripe_webhook_error(reason), do: {:invalid_stripe_signature, reason}

  defp normalize_stripe_payload(%_module{} = struct) do
    struct
    |> Map.from_struct()
    |> normalize_stripe_payload()
  end

  defp normalize_stripe_payload(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      {to_string(key), normalize_stripe_payload(value)}
    end)
  end

  defp normalize_stripe_payload(list) when is_list(list) do
    Enum.map(list, &normalize_stripe_payload/1)
  end

  defp normalize_stripe_payload(value), do: value

  defmodule Client do
    @moduledoc false

    alias Stripe.Checkout.Session
    alias Stripe.Webhook

    def create_checkout_session(params, opts) do
      Session.create(params, opts)
    end

    def construct_webhook_event(raw_body, signature_header, secret, tolerance_seconds) do
      Webhook.construct_event(raw_body, signature_header, secret, tolerance_seconds)
    end
  end
end
