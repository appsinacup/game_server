defmodule GameServerWeb.UserLive.SettingsPaymentsTest do
  use GameServerWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias GameServer.AccountsFixtures
  alias GameServer.Payments

  defmodule NoopPaymentHooks do
    use GameServerWeb.TestSupport.NoopHooks
  end

  defmodule StripeAdapter do
    def cancel_subscription_at_period_end("sub_settings_cancel") do
      {:ok,
       %{
         "id" => "sub_settings_cancel",
         "object" => "subscription",
         "status" => "active",
         "cancel_at_period_end" => true,
         "current_period_end" => 1_900_000_000
       }}
    end
  end

  setup do
    original_stripe = Application.get_env(:game_server_core, :stripe_adapter)
    original_hooks = Application.get_env(:game_server_core, :hooks_module)

    Application.put_env(:game_server_core, :stripe_adapter, StripeAdapter)
    Application.put_env(:game_server_core, :hooks_module, NoopPaymentHooks)

    on_exit(fn ->
      restore_env(:stripe_adapter, original_stripe)
      restore_env(:hooks_module, original_hooks)
    end)

    :ok
  end

  test "regular user can view purchases and owned entitlements", %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    {_coins_product, coins_provider_product} = create_consumable_provider_product("stripe")
    {_pass_product, pass_provider_product} = create_downloadable_provider_product("stripe")

    {:ok, coins_purchase} = Payments.create_purchase(user, coins_provider_product)
    {:ok, _coins_purchase} = Payments.fulfill_purchase(coins_purchase)

    {:ok, pass_purchase} = Payments.create_purchase(user, pass_provider_product)
    {:ok, _pass_purchase} = Payments.fulfill_purchase(pass_purchase)

    {:ok, view, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/users/settings")

    assert html =~ "Payments"

    view
    |> element(~s(button[phx-click="settings_tab"][phx-value-tab="payments"]))
    |> render_click()

    rendered = render(view)
    assert rendered =~ coins_purchase.order_id
    assert rendered =~ pass_purchase.order_id
    assert rendered =~ "completed"
    assert rendered =~ "Starter Pack"
    assert rendered =~ "starter_pack"
    assert rendered =~ "Download"
    refute rendered =~ "Game Wallet"
  end

  test "regular user can schedule Stripe subscription cancellation", %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    {_product, provider_product} = create_subscription_provider_product("stripe")

    {:ok, purchase} =
      Payments.create_purchase(user, provider_product, %{
        "metadata" => %{"stripe_subscription_id" => "sub_settings_cancel"}
      })

    {:ok, _purchase} = Payments.fulfill_purchase(purchase)

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/users/settings?tab=payments")

    html = render(view)
    assert html =~ "Premium"
    assert html =~ "Auto-renews"
    assert html =~ "Cancel renewal"

    html =
      view
      |> element(~s(button[phx-click="cancel_stripe_subscription"]), "Cancel renewal")
      |> render_click()

    assert html =~ "Subscription will cancel at the end of the period."
    assert html =~ "Cancels at period end"
    refute html =~ "Cancel renewal"

    [entitlement] = Payments.list_user_entitlements(user.id)
    assert entitlement.expires_at == DateTime.from_unix!(1_900_000_000, :second)
    assert entitlement.metadata["stripe_subscription_cancel_at_period_end"] == true
  end

  defp create_consumable_provider_product(provider) do
    sku = "coins_#{System.unique_integer([:positive])}"

    {:ok, product} =
      Payments.create_product(%{
        "sku" => sku,
        "title" => "250 Coins",
        "kind" => "consumable",
        "grant_config" => %{"hook_payload" => %{"coins" => 250}}
      })

    {:ok, provider_product} =
      Payments.create_provider_product(%{
        "product_id" => product.id,
        "provider" => provider,
        "external_id" => "price_#{sku}",
        "currency" => "USD",
        "unit_amount" => 299
      })

    {product, provider_product}
  end

  defp create_downloadable_provider_product(provider) do
    sku = "starter_pack_#{System.unique_integer([:positive])}"

    {:ok, product} =
      Payments.create_product(%{
        "sku" => sku,
        "title" => "Starter Pack",
        "kind" => "entitlement",
        "grant_config" => %{
          "entitlement_key" => "starter_pack",
          "download" => %{"asset_key" => "starter_pack.zip", "filename" => "starter_pack.zip"}
        }
      })

    {:ok, provider_product} =
      Payments.create_provider_product(%{
        "product_id" => product.id,
        "provider" => provider,
        "external_id" => "price_#{sku}",
        "currency" => "USD",
        "unit_amount" => 499
      })

    {product, provider_product}
  end

  defp create_subscription_provider_product(provider) do
    sku = "premium_#{System.unique_integer([:positive])}"

    {:ok, product} =
      Payments.create_product(%{
        "sku" => sku,
        "title" => "Premium",
        "kind" => "subscription",
        "grant_config" => %{"entitlement_key" => "premium"}
      })

    {:ok, provider_product} =
      Payments.create_provider_product(%{
        "product_id" => product.id,
        "provider" => provider,
        "external_id" => "price_#{sku}",
        "currency" => "USD",
        "unit_amount" => 999
      })

    {product, provider_product}
  end

  defp restore_env(key, nil), do: Application.delete_env(:game_server_core, key)
  defp restore_env(key, value), do: Application.put_env(:game_server_core, key, value)
end
