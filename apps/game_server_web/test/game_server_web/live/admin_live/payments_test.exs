defmodule GameServerWeb.AdminLive.PaymentsTest do
  use GameServerWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias GameServer.Accounts.User
  alias GameServer.AccountsFixtures
  alias GameServer.Payments
  alias GameServer.Repo

  setup do
    original_secret = System.get_env("STRIPE_SECRET_KEY")
    original_webhook = System.get_env("STRIPE_WEBHOOK_SECRET")
    original_environment = System.get_env("PAYMENTS_ENVIRONMENT")

    System.put_env("STRIPE_SECRET_KEY", "sk_test_admin_payments_123456")
    System.put_env("STRIPE_WEBHOOK_SECRET", "whsec_admin_payments_123456")
    System.put_env("PAYMENTS_ENVIRONMENT", "test")

    on_exit(fn ->
      restore_env("STRIPE_SECRET_KEY", original_secret)
      restore_env("STRIPE_WEBHOOK_SECRET", original_webhook)
      restore_env("PAYMENTS_ENVIRONMENT", original_environment)
    end)

    admin = AccountsFixtures.user_fixture()
    {:ok, admin} = admin |> User.admin_changeset(%{"is_admin" => true}) |> Repo.update()

    %{admin: admin}
  end

  test "admin can view payment config and ledger data", %{conn: conn, admin: admin} do
    {product, provider_product} = create_provider_product("stripe", "price_admin_view")
    {:ok, purchase} = Payments.create_purchase(admin, provider_product)
    {:ok, _purchase} = Payments.fulfill_purchase(purchase)

    {:ok, _view, html} = conn |> log_in_user(admin) |> live(~p"/admin/payments")

    assert html =~ "Payments"
    assert html =~ "Payment Providers"
    assert html =~ "configured"
    assert html =~ "test"
    refute html =~ "sk_test_admin_payments"
    refute html =~ "whsec_admin_payments"
    assert html =~ product.sku
    assert html =~ provider_product.external_id
    assert html =~ purchase.order_id
    assert html =~ "completed"
    assert html =~ "Wallet Ledger"
  end

  test "admin can create product and provider SKU", %{conn: conn, admin: admin} do
    {:ok, view, _html} = conn |> log_in_user(admin) |> live(~p"/admin/payments")

    view |> element(~S(button[phx-click="new_product"])) |> render_click()

    product_sku = "admin_created_#{System.unique_integer([:positive])}"

    view
    |> form("#admin-payment-product-form",
      product: %{
        "id" => "",
        "sku" => product_sku,
        "title" => "Admin Created",
        "description" => "Created from admin",
        "kind" => "currency",
        "active" => "true",
        "grant_config_json" => ~s({"currency_key":"coins","amount":25}),
        "metadata_json" => "{}"
      }
    )
    |> render_submit()

    product = Payments.get_product_by_sku(product_sku)
    assert product.title == "Admin Created"

    view |> element(~S(button[phx-click="new_provider_product"])) |> render_click()

    external_id = "price_admin_created_#{System.unique_integer([:positive])}"

    view
    |> form("#admin-payment-provider-product-form",
      provider_product: %{
        "id" => "",
        "product_id" => Integer.to_string(product.id),
        "provider" => "stripe",
        "external_id" => external_id,
        "currency" => "USD",
        "unit_amount" => "250",
        "active" => "true",
        "metadata_json" => "{}"
      }
    )
    |> render_submit()

    assert %GameServer.Payments.ProviderProduct{} =
             Payments.get_provider_product("stripe", external_id)
  end

  defp create_provider_product(provider, external_id) do
    sku = "admin_pay_#{System.unique_integer([:positive])}"

    {:ok, product} =
      Payments.create_product(%{
        "sku" => sku,
        "title" => "Admin Pay Product",
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

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)
end
