defmodule GameServer.PaymentsTest do
  use GameServer.DataCase

  alias GameServer.Accounts
  alias GameServer.AccountsFixtures
  alias GameServer.Payments
  alias GameServer.Payments.Entitlement
  alias GameServer.Payments.ProviderEvent
  alias GameServer.Payments.Purchase

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

  defmodule NoopPaymentHooks do
    use GameServerWeb.TestSupport.NoopHooks
  end

  defmodule CapturePaymentHooks do
    use GameServerWeb.TestSupport.NoopHooks

    @impl true
    def after_purchase_fulfilled(purchase) do
      send(hook_pid(), {:payment_purchase_fulfilled, purchase.id, purchase.user_id})
      send(hook_pid(), {:payment_hook_item_grant, purchase.user_id, purchase.product_id})
      :ok
    end

    @impl true
    def after_purchase_revoked(purchase) do
      send(hook_pid(), {:payment_purchase_revoked, purchase.id, purchase.user_id})
      :ok
    end

    @impl true
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

    Application.put_env(:game_server_core, :hooks_module, NoopPaymentHooks)

    on_exit(fn ->
      restore_env(:payment_provider_adapters, original_adapters)
      restore_env(:hooks_module, original_hooks)
    end)

    :ok
  end

  describe "fulfillment" do
    test "consumable purchases complete once and rely on hooks for game grants" do
      capture_payment_hooks()

      user = AccountsFixtures.user_fixture()
      {_product, provider_product} = create_consumable_provider_product("stripe", "price_coins")

      assert {:ok, %Purchase{} = purchase} =
               Payments.create_purchase(user, provider_product, %{
                 "provider_transaction_id" => "cs_test_consumable"
               })

      assert {:ok, %Purchase{status: "completed"} = completed} =
               Payments.fulfill_purchase(purchase, %{"provider" => "stripe"})

      assert Repo.aggregate(Entitlement, :count, :id) == 0
      assert_receive {:payment_purchase_fulfilled, purchase_id, user_id}, 1_000
      assert purchase_id == purchase.id
      assert user_id == user.id

      assert_receive {:payment_hook_item_grant, ^user_id, product_id}, 1_000
      assert product_id == provider_product.product_id

      assert {:ok, %Purchase{status: "completed"}} = Payments.fulfill_purchase(completed)
      assert Repo.aggregate(Entitlement, :count, :id) == 0
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

    test "default payment hooks mirror purchase and entitlement state into user metadata" do
      use_default_payment_hooks()

      user = AccountsFixtures.user_fixture()
      {_product, provider_product} = create_entitlement_provider_product("stripe", "battle_pass")

      {:ok, purchase} =
        Payments.create_purchase(user, provider_product, %{
          "provider_transaction_id" => "cs_metadata_entitlement"
        })

      assert {:ok, completed} = Payments.fulfill_purchase(purchase)

      entitlement = Repo.get_by!(Entitlement, user_id: user.id, key: "battle_pass")
      purchase_id = to_string(purchase.id)
      entitlement_id = to_string(entitlement.id)

      eventually(fn ->
        metadata = Accounts.get_user!(user.id).metadata || %{}

        assert get_in(metadata, ["payments", "purchase_ids", purchase_id]) == true
        assert get_in(metadata, ["payments", "entitlements", "battle_pass"]) == true
        assert get_in(metadata, ["payments", "entitlement_ids", entitlement_id]) == true

        assert get_in(metadata, ["payments", "entitlement_details", "battle_pass", "active"]) ==
                 true

        assert get_in(metadata, ["payments", "entitlement_details", "battle_pass", "status"]) ==
                 "active"
      end)

      assert {:ok, _revoked} = Payments.revoke_purchase(completed, %{"reason" => "refund"})

      eventually(fn ->
        metadata = Accounts.get_user!(user.id).metadata || %{}

        assert get_in(metadata, ["payments", "purchase_ids", purchase_id]) == false
        assert get_in(metadata, ["payments", "entitlements", "battle_pass"]) == false
        assert get_in(metadata, ["payments", "entitlement_ids", entitlement_id]) == false

        assert get_in(metadata, ["payments", "entitlement_details", "battle_pass", "active"]) ==
                 false

        assert get_in(metadata, ["payments", "entitlement_details", "battle_pass", "status"]) ==
                 "revoked"
      end)
    end

    test "subscription purchases create entitlement metadata with expiry" do
      use_default_payment_hooks()

      user = AccountsFixtures.user_fixture()
      {_product, provider_product} = create_subscription_provider_product("stripe", "premium")

      {:ok, purchase} =
        Payments.create_purchase(user, provider_product, %{
          "provider_transaction_id" => "cs_metadata_subscription"
        })

      assert {:ok, _completed} = Payments.fulfill_purchase(purchase)

      eventually(fn ->
        metadata = Accounts.get_user!(user.id).metadata || %{}
        details = get_in(metadata, ["payments", "entitlement_details", "premium_subscription"])

        assert get_in(metadata, ["payments", "entitlements", "premium_subscription"]) == true
        assert details["active"] == true
        assert details["status"] == "active"
        assert is_binary(details["expires_at"])
      end)
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
      {_product, provider_product} = create_consumable_provider_product("apple", "coins_pack")

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
      assert Repo.aggregate(Entitlement, :count, :id) == 0

      assert {:ok, %{purchase: same_purchase, seen_before: true}} =
               Payments.validate_store_purchase(user, "apple", attrs)

      assert same_purchase.id == purchase.id
      assert Repo.aggregate(Entitlement, :count, :id) == 0

      assert {:error, :receipt_already_used} =
               Payments.validate_store_purchase(other_user, "apple", attrs)
    end

    test "validated entitlement receipts reject already-owned entitlement across providers" do
      user = AccountsFixtures.user_fixture()

      {_apple_product, apple_provider_product} =
        create_entitlement_provider_product("apple", "pass")

      {_google_product, google_provider_product} =
        create_entitlement_provider_product("google", "pass")

      assert {:ok, %{purchase: %Purchase{} = purchase, seen_before: false}} =
               Payments.validate_store_purchase(user, "apple", %{
                 "product_id" => apple_provider_product.external_id,
                 "transaction_id" => "apple_tx_pass_1",
                 "environment" => "test"
               })

      assert purchase.status == "completed"
      assert Payments.has_entitlement?(user.id, "battle_pass") == true

      assert {:error, :already_owned} =
               Payments.validate_store_purchase(user, "google", %{
                 "product_id" => google_provider_product.external_id,
                 "transaction_id" => "google_tx_pass_1",
                 "environment" => "test"
               })
    end
  end

  defp create_consumable_provider_product(provider, external_id) do
    sku = unique_sku("coins")

    {:ok, product} =
      Payments.create_product(%{
        "sku" => sku,
        "title" => "100 Coins",
        "kind" => "consumable",
        "grant_config" => %{"hook_payload" => %{"coins" => 100}}
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

  defp use_default_payment_hooks do
    Application.put_env(:game_server_core, :hooks_module, GameServer.Hooks.Default)
  end

  defp eventually(fun, attempts \\ 20)

  defp eventually(fun, attempts) when attempts > 0 do
    fun.()
  rescue
    error ->
      if attempts == 1 do
        reraise error, __STACKTRACE__
      else
        Process.sleep(50)
        eventually(fun, attempts - 1)
      end
  end

  defp unique_sku(prefix), do: "#{prefix}_#{System.unique_integer([:positive])}"

  defp restore_env(key, nil), do: Application.delete_env(:game_server_core, key)
  defp restore_env(key, value), do: Application.put_env(:game_server_core, key, value)
end
