defmodule GameServer.Payments.ProviderAdaptersTest do
  use ExUnit.Case, async: false

  alias GameServer.Payments.Product
  alias GameServer.Payments.ProviderProduct
  alias GameServer.Payments.Providers.Apple
  alias GameServer.Payments.Providers.Google
  alias GameServer.Payments.Providers.Steam
  alias GameServer.Payments.Purchase

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
      "GOOGLE_PLAY_PACKAGE_NAME",
      "GOOGLE_PLAY_ACCESS_TOKEN",
      "GOOGLE_PLAY_AUTO_ACKNOWLEDGE",
      "GOOGLE_PLAY_RTDN_TOKEN",
      "APPLE_BUNDLE_ID",
      "APPLE_ENVIRONMENT",
      "STEAM_WEB_API_KEY",
      "STEAM_APP_ID",
      "STEAM_PAYMENTS_ENVIRONMENT"
    ]

    app_keys = [
      :payments_http_client,
      :apple_jws_verifier
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
    System.put_env("STEAM_PAYMENTS_ENVIRONMENT", "sandbox")

    product = %Product{title: "100 Coins", kind: "currency"}
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
