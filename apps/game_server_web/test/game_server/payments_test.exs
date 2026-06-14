defmodule GameServer.PaymentsTest do
  use GameServer.DataCase

  alias GameServer.AccountsFixtures
  alias GameServer.Payments
  alias GameServer.Payments.Entitlement
  alias GameServer.Payments.ProviderEvent
  alias GameServer.Payments.Purchase
  alias GameServer.Payments.WalletLedgerEntry

  defmodule StoreAdapter do
    def validate_purchase(_user, attrs) do
      attrs = normalize(attrs)

      {:ok,
       %{
         "product_id" => attrs["product_id"],
         "transaction_id" => attrs["transaction_id"],
         "original_transaction_id" => attrs["original_transaction_id"],
         "status" => attrs["status"] || "completed",
         "quantity" => attrs["quantity"] || 1,
         "currency" => attrs["currency"],
         "amount" => attrs["amount"],
         "environment" => attrs["environment"] || "test",
         "raw_payload" => attrs
       }}
    end

    def verify_webhook(raw_body, _authorization), do: Jason.decode(raw_body)
    def verify_notification(raw_body), do: Jason.decode(raw_body)

    defp normalize(attrs) do
      Map.new(attrs, fn
        {key, value} when is_atom(key) -> {Atom.to_string(key), value}
        pair -> pair
      end)
    end
  end

  defmodule CapturePaymentHooks do
    def after_purchase_fulfilled(purchase) do
      send(hook_pid(), {:payment_purchase_fulfilled, purchase.id, purchase.user_id})
      send(hook_pid(), {:payment_hook_item_grant, purchase.user_id, purchase.product_id})
      :ok
    end

    def after_purchase_revoked(purchase) do
      send(hook_pid(), {:payment_purchase_revoked, purchase.id, purchase.user_id})
      :ok
    end

    def after_entitlement_changed(entitlement) do
      send(
        hook_pid(),
        {:payment_entitlement_changed, entitlement.key, entitlement.status, entitlement.user_id}
      )

      :ok
    end

    defp hook_pid do
      :persistent_term.get({__MODULE__, :pid})
    end
  end

  setup do
    original_adapters = Application.get_env(:game_server_core, :payment_provider_adapters)
    original_hooks = Application.get_env(:game_server_core, :hooks_module)

    Application.put_env(:game_server_core, :payment_provider_adapters,
      apple: StoreAdapter,
      google: StoreAdapter,
      steam: StoreAdapter
    )

    Application.put_env(:game_server_core, :hooks_module, GameServer.Hooks.Default)

    on_exit(fn ->
      restore_env(:payment_provider_adapters, original_adapters)
      restore_env(:hooks_module, original_hooks)
    end)

    :ok
  end

  describe "fulfillment" do
    test "currency purchases grant wallet balance once" do
      user = AccountsFixtures.user_fixture()
      {_product, provider_product} = create_currency_provider_product("stripe", "price_coins")

      assert {:ok, %Purchase{} = purchase} =
               Payments.create_purchase(user, provider_product, %{
                 "provider_transaction_id" => "cs_test_currency"
               })

      assert {:ok, %Purchase{status: "completed"} = completed} =
               Payments.fulfill_purchase(purchase, %{"provider" => "stripe"})

      assert Payments.wallet_balance(user.id, "coins") == 100

      assert {:ok, %Purchase{status: "completed"}} = Payments.fulfill_purchase(completed)
      assert Payments.wallet_balance(user.id, "coins") == 100

      assert Repo.aggregate(WalletLedgerEntry, :count, :id) == 1
    end

    test "entitlement purchases create one active entitlement and revoke cleanly" do
      user = AccountsFixtures.user_fixture()
      {_product, provider_product} = create_entitlement_provider_product("google", "battle_pass")

      {:ok, purchase} =
        Payments.create_purchase(user, provider_product, %{
          "provider_transaction_id" => "google_tx_entitlement"
        })

      assert {:ok, completed} = Payments.fulfill_purchase(purchase)
      assert Payments.has_entitlement?(user.id, "battle_pass") == true

      assert {:ok, _completed_again} = Payments.fulfill_purchase(completed)
      assert Repo.aggregate(Entitlement, :count, :id) == 1

      assert {:ok, revoked} = Payments.revoke_purchase(completed, %{"reason" => "refund"})
      assert revoked.status == "revoked"
      assert Payments.has_entitlement?(user.id, "battle_pass") == false
    end
  end

  describe "provider events" do
    test "provider events are deduped by provider and event id" do
      assert {:ok, %ProviderEvent{} = event, true} =
               Payments.record_provider_event(
                 "stripe",
                 "evt_1",
                 "checkout.session.completed",
                 %{}
               )

      assert {:ok, %ProviderEvent{} = duplicate, false} =
               Payments.record_provider_event(
                 "stripe",
                 "evt_1",
                 "checkout.session.completed",
                 %{}
               )

      assert duplicate.id == event.id
      assert Repo.aggregate(ProviderEvent, :count, :id) == 1
    end
  end

  describe "provider webhook processing and hooks" do
    test "fake Google subscription events grant, hook, dedupe, and revoke subscription" do
      capture_payment_hooks()

      user = AccountsFixtures.user_fixture()

      {_product, provider_product} =
        create_subscription_provider_product("google", "premium_monthly")

      {:ok, purchase} =
        Payments.create_purchase(user, provider_product, %{
          "provider_transaction_id" => "GPA.subscription.1",
          "provider_original_transaction_id" => "google_sub_token_1"
        })

      activated_body =
        Jason.encode!(%{
          "message_id" => "google_msg_subscription_activated",
          "subscriptionNotification" => %{
            "purchaseToken" => "google_sub_token_1",
            "notificationType" => 2
          }
        })

      assert {:ok, :processed} = Payments.handle_google_webhook(activated_body, nil)

      completed = Payments.get_purchase(purchase.id)
      assert completed.status == "completed"
      assert Payments.has_entitlement?(user.id, "premium_subscription") == true

      assert_receive {:payment_purchase_fulfilled, purchase_id, user_id}, 1_000
      assert purchase_id == purchase.id
      assert user_id == user.id

      assert_receive {:payment_entitlement_changed, "premium_subscription", "active", ^user_id},
                     1_000

      assert_receive {:payment_hook_item_grant, ^user_id, product_id}, 1_000
      assert product_id == provider_product.product_id

      assert {:ok, :duplicate} = Payments.handle_google_webhook(activated_body, nil)
      assert Repo.aggregate(Entitlement, :count, :id) == 1

      revoked_body =
        Jason.encode!(%{
          "message_id" => "google_msg_subscription_revoked",
          "subscriptionNotification" => %{
            "purchaseToken" => "google_sub_token_1",
            "notificationType" => 13
          }
        })

      assert {:ok, :processed} = Payments.handle_google_webhook(revoked_body, nil)

      revoked = Payments.get_purchase(purchase.id)
      assert revoked.status == "revoked"
      assert Payments.has_entitlement?(user.id, "premium_subscription") == false

      assert_receive {:payment_purchase_revoked, ^purchase_id, ^user_id}, 1_000

      assert_receive {:payment_entitlement_changed, "premium_subscription", "revoked", ^user_id},
                     1_000
    end
  end

  describe "store validation" do
    test "validated receipts create fulfilled purchases and reject replay across users" do
      user = AccountsFixtures.user_fixture()
      other_user = AccountsFixtures.user_fixture()
      {_product, provider_product} = create_currency_provider_product("apple", "coins_pack")

      attrs = %{
        "product_id" => provider_product.external_id,
        "transaction_id" => "apple_tx_1",
        "currency" => "USD",
        "amount" => 199,
        "environment" => "test"
      }

      assert {:ok, %{purchase: %Purchase{} = purchase, seen_before: false}} =
               Payments.validate_store_purchase(user, "apple", attrs)

      assert purchase.status == "completed"
      assert purchase.provider_transaction_id == "apple_tx_1"
      assert Payments.wallet_balance(user.id, "coins") == 100

      assert {:ok, %{purchase: same_purchase, seen_before: true}} =
               Payments.validate_store_purchase(user, "apple", attrs)

      assert same_purchase.id == purchase.id
      assert Payments.wallet_balance(user.id, "coins") == 100

      assert {:error, :receipt_already_used} =
               Payments.validate_store_purchase(other_user, "apple", attrs)
    end
  end

  defp create_currency_provider_product(provider, external_id) do
    sku = unique_sku("coins")

    {:ok, product} =
      Payments.create_product(%{
        "sku" => sku,
        "title" => "100 Coins",
        "kind" => "currency",
        "grant_config" => %{"currency_key" => "coins", "amount" => 100}
      })

    {:ok, provider_product} =
      Payments.create_provider_product(%{
        "product_id" => product.id,
        "provider" => provider,
        "external_id" =>
          external_id <> "_" <> Integer.to_string(System.unique_integer([:positive])),
        "currency" => "USD",
        "unit_amount" => 199
      })

    {product, provider_product}
  end

  defp create_entitlement_provider_product(provider, external_id) do
    sku = unique_sku("battle_pass")

    {:ok, product} =
      Payments.create_product(%{
        "sku" => sku,
        "title" => "Battle Pass",
        "kind" => "entitlement",
        "grant_config" => %{"entitlement_key" => "battle_pass"}
      })

    {:ok, provider_product} =
      Payments.create_provider_product(%{
        "product_id" => product.id,
        "provider" => provider,
        "external_id" =>
          external_id <> "_" <> Integer.to_string(System.unique_integer([:positive])),
        "currency" => "USD",
        "unit_amount" => 999
      })

    {product, provider_product}
  end

  defp create_subscription_provider_product(provider, external_id) do
    sku = unique_sku("premium")

    {:ok, product} =
      Payments.create_product(%{
        "sku" => sku,
        "title" => "Premium Monthly",
        "kind" => "subscription",
        "grant_config" => %{
          "entitlement_key" => "premium_subscription",
          "duration_seconds" => 2_592_000
        }
      })

    {:ok, provider_product} =
      Payments.create_provider_product(%{
        "product_id" => product.id,
        "provider" => provider,
        "external_id" =>
          external_id <> "_" <> Integer.to_string(System.unique_integer([:positive])),
        "currency" => "USD",
        "unit_amount" => 499
      })

    {product, provider_product}
  end

  defp capture_payment_hooks do
    :persistent_term.put({CapturePaymentHooks, :pid}, self())
    Application.put_env(:game_server_core, :hooks_module, CapturePaymentHooks)

    on_exit(fn ->
      :persistent_term.erase({CapturePaymentHooks, :pid})
    end)
  end

  defp unique_sku(prefix), do: "#{prefix}_#{System.unique_integer([:positive])}"

  defp restore_env(key, nil), do: Application.delete_env(:game_server_core, key)
  defp restore_env(key, value), do: Application.put_env(:game_server_core, key, value)
end
