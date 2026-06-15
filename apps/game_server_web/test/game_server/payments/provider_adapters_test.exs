defmodule GameServer.Payments.ProviderAdaptersTest do
  use ExUnit.Case, async: false

  alias GameServer.Payments.Product
  alias GameServer.Payments.ProviderConfig
  alias GameServer.Payments.ProviderProduct
  alias GameServer.Payments.Providers.Apple
  alias GameServer.Payments.Providers.Google
  alias GameServer.Payments.Providers.Steam
  alias GameServer.Payments.Providers.Stripe
  alias GameServer.Payments.Purchase

  defmodule StripeClient do
    def create_checkout_session(params, opts) do
      send(self(), {:stripe_create_checkout_session, params, opts})
      {:ok, %{id: "cs_test_sdk", url: "https://checkout.stripe.test/session"}}
    end

    def retrieve_checkout_session(session_id, params, opts) do
      send(self(), {:stripe_retrieve_checkout_session, session_id, params, opts})

      {:ok,
       %{
         id: session_id,
         object: "checkout.session",
         status: "complete",
         payment_status: "paid"
       }}
    end

    def retrieve_subscription(subscription_id, params, opts) do
      send(self(), {:stripe_retrieve_subscription, subscription_id, params, opts})

      {:ok,
       %{
         id: subscription_id,
         object: "subscription",
         status: "active",
         current_period_end: 1_900_000_000,
         cancel_at_period_end: false
       }}
    end

    def update_subscription(subscription_id, params, opts) do
      send(self(), {:stripe_update_subscription, subscription_id, params, opts})

      {:ok,
       %{
         id: subscription_id,
         object: "subscription",
         status: "active",
         current_period_end: 1_900_000_000,
         cancel_at_period_end: params[:cancel_at_period_end]
       }}
    end

    def construct_webhook_event(raw_body, signature_header, secret, tolerance_seconds) do
      send(
        self(),
        {:stripe_construct_webhook_event, raw_body, signature_header, secret, tolerance_seconds}
      )

      {:ok,
       %{
         id: "evt_test_sdk",
         type: "checkout.session.completed",
         data: %{object: %{id: "cs_test_sdk"}}
       }}
    end
  end

  defmodule GoogleHTTP do
    def get(url, opts) do
      send(self(), {:google_get, url, opts})

      {:ok,
       %{
         status: 200,
         body: %{
           "productId" => "coins_google",
           "orderId" => "GPA.1234-5678-9012-34567",
           "purchaseToken" => "google_token_1",
           "purchaseState" => 0,
           "purchaseType" => 0,
           "acknowledgementState" => 0,
           "quantity" => 2
         }
       }}
    end

    def post(url, opts) do
      send(self(), {:google_post, url, opts})
      {:ok, %{status: 204, body: ""}}
    end
  end

  defmodule AppleJWS do
    def verify_and_decode("signed_tx") do
      {:ok,
       %{
         "productId" => "coins_apple",
         "transactionId" => "apple_tx_1",
         "originalTransactionId" => "apple_orig_1",
         "bundleId" => "com.example.game",
         "environment" => "Sandbox",
         "expiresDate" => "1700000000000",
         "quantity" => "3"
       }}
    end

    def verify_and_decode("signed_notification") do
      {:ok,
       %{
         "notificationUUID" => "apple_note_1",
         "notificationType" => "REFUND",
         "data" => %{"signedTransactionInfo" => "signed_tx"}
       }}
    end
  end

  defmodule SteamHTTP do
    def post(url, opts) do
      send(self(), {:steam_post, url, opts})

      cond do
        String.contains?(url, "InitTxn") ->
          {:ok,
           %{
             status: 200,
             body: %{
               "response" => %{
                 "result" => "OK",
                 "params" => %{
                   "orderid" => "1234567890123",
                   "transid" => "steam_tx_1",
                   "steamurl" => "https://steam.test/checkout/1234567890123"
                 }
               }
             }
           }}

        String.contains?(url, "FinalizeTxn") ->
          {:ok,
           %{
             status: 200,
             body: %{
               "response" => %{
                 "result" => "OK",
                 "params" => %{
                   "orderid" => "1234567890123",
                   "transid" => "steam_tx_1"
                 }
               }
             }
           }}
      end
    end

    def get(url, opts) do
      send(self(), {:steam_get, url, opts})

      {:ok,
       %{
         status: 200,
         body: %{
           "response" => %{
             "result" => "OK",
             "params" => %{
               "orderid" => "1234567890123",
               "transid" => "steam_tx_1",
               "status" => "Succeeded",
               "currency" => "USD",
               "items" => [
                 %{"itemid" => "100", "qty" => 1, "amount" => 199}
               ]
             }
           }
         }
       }}
    end
  end

  setup do
    env_keys = [
      "PAYMENTS_ENVIRONMENT",
      "STRIPE_SANDBOX_SECRET_KEY",
      "STRIPE_SANDBOX_WEBHOOK_SECRET",
      "STRIPE_PRODUCTION_SECRET_KEY",
      "STRIPE_PRODUCTION_WEBHOOK_SECRET",
      "STRIPE_API_VERSION",
      "GOOGLE_PLAY_PACKAGE_NAME",
      "GOOGLE_PLAY_ACCESS_TOKEN",
      "GOOGLE_PLAY_AUTO_ACKNOWLEDGE",
      "GOOGLE_PLAY_RTDN_TOKEN",
      "APPLE_BUNDLE_ID",
      "STEAM_WEB_API_KEY",
      "STEAM_APP_ID"
    ]

    app_keys = [
      :payments_http_client,
      :apple_jws_verifier,
      :stripe_client,
      :stripe_api_version
    ]

    original_env = Map.new(env_keys, &{&1, System.get_env(&1)})
    original_app = Map.new(app_keys, &{&1, Application.get_env(:game_server_core, &1)})

    on_exit(fn ->
      Enum.each(original_env, fn {key, value} -> restore_system_env(key, value) end)
      Enum.each(original_app, fn {key, value} -> restore_app_env(key, value) end)
    end)

    Enum.each(env_keys, &System.delete_env/1)
    Enum.each(app_keys, &Application.delete_env(:game_server_core, &1))

    :ok
  end

  test "Stripe config follows global payment environment" do
    System.put_env("STRIPE_SANDBOX_SECRET_KEY", "sk_test_sandbox_123")
    System.put_env("STRIPE_PRODUCTION_SECRET_KEY", "sk_live_production_123")

    System.put_env("PAYMENTS_ENVIRONMENT", "sandbox")
    assert ProviderConfig.stripe_secret_key() == "sk_test_sandbox_123"

    System.put_env("PAYMENTS_ENVIRONMENT", "production")
    assert ProviderConfig.stripe_secret_key() == "sk_live_production_123"

    System.put_env("PAYMENTS_ENVIRONMENT", "sandbox")
    System.delete_env("STRIPE_SANDBOX_SECRET_KEY")
    assert ProviderConfig.stripe_secret_key() == nil

    System.put_env("PAYMENTS_ENVIRONMENT", "definitely_not_real")
    assert ProviderConfig.environment() == "sandbox"
    assert ProviderConfig.environments() == ["production", "sandbox"]

    System.put_env("PAYMENTS_ENVIRONMENT", "test")
    assert ProviderConfig.environment() == "sandbox"

    assert ProviderConfig.stripe_api_version() == "2022-11-15"
    System.put_env("STRIPE_API_VERSION", "2024-06-20")
    assert ProviderConfig.stripe_api_version() == "2024-06-20"
  end

  test "Stripe creates checkout session through SDK client with pinned API options" do
    Application.put_env(:game_server_core, :stripe_client, StripeClient)
    System.put_env("PAYMENTS_ENVIRONMENT", "sandbox")
    System.put_env("STRIPE_SANDBOX_SECRET_KEY", "sk_test_sdk_123")
    System.put_env("STRIPE_API_VERSION", "2024-06-20")

    product = %Product{id: 10, sku: "coins_100", title: "100 Coins", kind: "consumable"}
    provider_product = %ProviderProduct{external_id: "price_123", product: product}
    purchase = %Purchase{id: 42, user_id: 7, order_id: "order_42", quantity: 2}

    assert {:ok, session} =
             Stripe.create_checkout_session(purchase, provider_product, %{
               "success_url" => "https://example.test/success",
               "cancel_url" => "https://example.test/cancel"
             })

    assert session["id"] == "cs_test_sdk"
    assert session["url"] == "https://checkout.stripe.test/session"

    assert_received {:stripe_create_checkout_session, params, opts}
    assert params.mode == "payment"
    assert params.line_items == [%{price: "price_123", quantity: 2}]
    assert params.success_url == "https://example.test/success"
    assert params.cancel_url == "https://example.test/cancel"

    assert params.metadata == %{
             "purchase_id" => "42",
             "order_id" => "order_42",
             "user_id" => "7",
             "product_sku" => "coins_100"
           }

    assert params.payment_intent_data == %{metadata: params.metadata}
    assert opts[:api_key] == "sk_test_sdk_123"
    assert opts[:api_version] == "2024-06-20"
    assert opts[:idempotency_key] == "order_42"
  end

  test "Stripe retrieves checkout session through SDK client with pinned API options" do
    Application.put_env(:game_server_core, :stripe_client, StripeClient)
    System.put_env("PAYMENTS_ENVIRONMENT", "sandbox")
    System.put_env("STRIPE_SANDBOX_SECRET_KEY", "sk_test_sdk_123")
    System.put_env("STRIPE_API_VERSION", "2024-06-20")

    assert {:ok, session} = Stripe.retrieve_checkout_session("cs_test_reconcile")

    assert session["id"] == "cs_test_reconcile"
    assert session["payment_status"] == "paid"

    assert_received {:stripe_retrieve_checkout_session, "cs_test_reconcile", params, opts}
    assert params == %{expand: ["payment_intent", "subscription"]}
    assert opts[:api_key] == "sk_test_sdk_123"
    assert opts[:api_version] == "2024-06-20"
    refute Keyword.has_key?(opts, :idempotency_key)
  end

  test "Stripe cancels subscription at period end through SDK client" do
    Application.put_env(:game_server_core, :stripe_client, StripeClient)
    System.put_env("PAYMENTS_ENVIRONMENT", "sandbox")
    System.put_env("STRIPE_SANDBOX_SECRET_KEY", "sk_test_sdk_123")
    System.put_env("STRIPE_API_VERSION", "2024-06-20")

    assert {:ok, subscription} = Stripe.cancel_subscription_at_period_end("sub_test_cancel")

    assert subscription["id"] == "sub_test_cancel"
    assert subscription["cancel_at_period_end"] == true

    assert_received {:stripe_update_subscription, "sub_test_cancel", params, opts}
    assert params == %{cancel_at_period_end: true}
    assert opts[:api_key] == "sk_test_sdk_123"
    assert opts[:api_version] == "2024-06-20"
  end

  test "Stripe sends subscription metadata through subscription data" do
    Application.put_env(:game_server_core, :stripe_client, StripeClient)
    System.put_env("PAYMENTS_ENVIRONMENT", "sandbox")
    System.put_env("STRIPE_SANDBOX_SECRET_KEY", "sk_test_sdk_123")

    product = %Product{id: 11, sku: "battle_pass", title: "Battle Pass", kind: "subscription"}
    provider_product = %ProviderProduct{external_id: "price_sub_123", product: product}
    purchase = %Purchase{id: 43, user_id: 8, order_id: "order_43", quantity: 1}

    assert {:ok, _session} =
             Stripe.create_checkout_session(purchase, provider_product, %{
               "success_url" => "https://example.test/success",
               "cancel_url" => "https://example.test/cancel"
             })

    assert_received {:stripe_create_checkout_session, params, _opts}
    assert params.mode == "subscription"
    assert params.subscription_data == %{metadata: params.metadata}
    refute Map.has_key?(params, :payment_intent_data)
  end

  test "Stripe verifies webhooks through SDK client" do
    Application.put_env(:game_server_core, :stripe_client, StripeClient)
    System.put_env("PAYMENTS_ENVIRONMENT", "sandbox")
    System.put_env("STRIPE_SANDBOX_WEBHOOK_SECRET", "whsec_sdk_123")

    raw_body = Jason.encode!(%{"id" => "evt_test_sdk"})
    signature = "t=1710000000,v1=abc"

    assert {:ok, event} = Stripe.verify_webhook(raw_body, signature)
    assert event["id"] == "evt_test_sdk"
    assert event["data"]["object"]["id"] == "cs_test_sdk"

    assert_received {:stripe_construct_webhook_event, ^raw_body, ^signature, "whsec_sdk_123", 300}
  end

  test "Google validates one-time product purchase and decodes RTDN push" do
    Application.put_env(:game_server_core, :payments_http_client, GoogleHTTP)
    System.put_env("GOOGLE_PLAY_PACKAGE_NAME", "com.example.game")
    System.put_env("GOOGLE_PLAY_ACCESS_TOKEN", "ya29_test_token")
    System.put_env("GOOGLE_PLAY_AUTO_ACKNOWLEDGE", "true")
    System.put_env("PAYMENTS_ENVIRONMENT", "test")

    assert {:ok, result} =
             Google.validate_purchase(nil, %{
               "product_id" => "coins_google",
               "purchase_token" => "google_token_1"
             })

    assert result["product_id"] == "coins_google"
    assert result["transaction_id"] == "GPA.1234-5678-9012-34567"
    assert result["original_transaction_id"] == "google_token_1"
    assert result["status"] == "completed"
    assert result["quantity"] == 2
    assert result["environment"] == "test"

    assert_received {:google_get, url, [auth: {:bearer, "ya29_test_token"}]}

    assert url =~
             "/applications/com.example.game/purchases/products/coins_google/tokens/google_token_1"

    assert_received {:google_post, ack_url, [auth: {:bearer, "ya29_test_token"}, json: %{}]}
    assert ack_url =~ ":acknowledge"

    notification = %{
      "version" => "1.0",
      "packageName" => "com.example.game",
      "voidedPurchaseNotification" => %{
        "purchaseToken" => "google_token_1",
        "orderId" => "GPA.1234-5678-9012-34567"
      }
    }

    body =
      Jason.encode!(%{
        "message" => %{
          "messageId" => "google_msg_1",
          "data" => Base.encode64(Jason.encode!(notification))
        },
        "subscription" => "projects/example/subscriptions/payments"
      })

    assert {:ok, event} = Google.verify_webhook(body, nil)
    assert event["message_id"] == "google_msg_1"
    assert event["subscription"] == "projects/example/subscriptions/payments"
    assert event["voidedPurchaseNotification"]["purchaseToken"] == "google_token_1"
  end

  test "Apple validates StoreKit signed transaction and notification payload" do
    Application.put_env(:game_server_core, :apple_jws_verifier, AppleJWS)
    System.put_env("APPLE_BUNDLE_ID", "com.example.game")
    System.put_env("PAYMENTS_ENVIRONMENT", "test")

    assert {:ok, result} =
             Apple.validate_purchase(nil, %{"signed_transaction_info" => "signed_tx"})

    assert result["product_id"] == "coins_apple"
    assert result["transaction_id"] == "apple_tx_1"
    assert result["original_transaction_id"] == "apple_orig_1"
    assert result["status"] == "completed"
    assert result["quantity"] == 3
    assert result["environment"] == "sandbox"
    assert result["expires_at"] == "2023-11-14T22:13:20.000Z"

    body = Jason.encode!(%{"signedPayload" => "signed_notification"})

    assert {:ok, event} = Apple.verify_notification(body)
    assert event["notificationUUID"] == "apple_note_1"
    assert event["notificationType"] == "REFUND"
    assert event["decoded_transaction_info"]["transactionId"] == "apple_tx_1"
  end

  test "Steam normalizes InitTxn, FinalizeTxn, and QueryTxn responses" do
    Application.put_env(:game_server_core, :payments_http_client, SteamHTTP)
    System.put_env("STEAM_WEB_API_KEY", "steam_key")
    System.put_env("STEAM_APP_ID", "480")
    System.put_env("PAYMENTS_ENVIRONMENT", "sandbox")

    product = %Product{title: "100 Coins", kind: "consumable"}
    provider_product = %ProviderProduct{external_id: "100", product: product}

    purchase = %Purchase{
      id: 1,
      order_id: "1234567890123",
      quantity: 1,
      amount: 199,
      currency: "USD",
      provider_product: provider_product
    }

    assert {:ok, init} =
             Steam.init_transaction(purchase, provider_product, %{
               "steam_id" => "76561197972751825",
               "ip_address" => "127.0.0.1"
             })

    assert init["response"]["params"]["transid"] == "steam_tx_1"
    assert_received {:steam_post, init_url, init_opts}
    assert init_url =~ "ISteamMicroTxnSandbox/InitTxn/v3"
    assert {"steamid", "76561197972751825"} in init_opts[:form]
    assert {"amount[0]", "199"} in init_opts[:form]

    assert {:ok, finalized} = Steam.finalize_transaction(purchase)
    assert finalized["product_id"] == "100"
    assert finalized["transaction_id"] == "steam_tx_1"
    assert finalized["original_transaction_id"] == "1234567890123"
    assert finalized["status"] == "completed"
    assert finalized["environment"] == "sandbox"

    assert {:ok, queried} = Steam.validate_purchase(nil, %{"order_id" => "1234567890123"})
    assert queried["product_id"] == "100"
    assert queried["transaction_id"] == "steam_tx_1"
    assert queried["status"] == "completed"
    assert queried["currency"] == "USD"
    assert queried["amount"] == 199

    assert_received {:steam_post, finalize_url, _finalize_opts}
    assert finalize_url =~ "ISteamMicroTxnSandbox/FinalizeTxn/v2"

    assert_received {:steam_get, query_url, query_opts}
    assert query_url =~ "ISteamMicroTxnSandbox/QueryTxn/v3"
    assert {"orderid", "1234567890123"} in query_opts[:params]
  end

  defp restore_system_env(key, nil), do: System.delete_env(key)
  defp restore_system_env(key, value), do: System.put_env(key, value)

  defp restore_app_env(key, nil), do: Application.delete_env(:game_server_core, key)
  defp restore_app_env(key, value), do: Application.put_env(:game_server_core, key, value)
end
