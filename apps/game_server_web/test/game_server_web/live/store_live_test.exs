defmodule GameServerWeb.StoreLiveTest do
  use GameServerWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias GameServer.AccountsFixtures
  alias GameServer.Payments

  defmodule StripeAdapter do
    def create_checkout_session(_purchase, %{external_id: "price_store_error" <> _rest}, _attrs) do
      {:error,
       {:stripe_error,
        %{
          "message" => "No such price: 'price_store_error'; a similar object exists in live mode."
        }}}
    end

    def create_checkout_session(purchase, _provider_product, _attrs) do
      {:ok,
       %{
         "id" => "cs_test_#{purchase.id}",
         "url" => "https://checkout.test/session/#{purchase.id}"
       }}
    end
  end

  setup do
    original_stripe = Application.get_env(:game_server_core, :stripe_adapter)
    Application.put_env(:game_server_core, :stripe_adapter, StripeAdapter)

    on_exit(fn -> restore_env(:stripe_adapter, original_stripe) end)

    :ok
  end

  test "regular user can see catalog products and start Stripe checkout", %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    {_product, provider_product} = create_provider_product("stripe", "price_store_checkout")

    {:ok, view, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/store")

    assert html =~ "Store"
    assert html =~ "100 Coins"
    assert html =~ "consumable"

    assert {:error, {:redirect, redirect}} =
             view
             |> element("#store-item-#{provider_product.id} button", "Buy")
             |> render_click()

    assert (redirect[:to] || redirect[:external]) =~ "https://checkout.test/session/"
  end

  test "success page shows returned purchase for current user", %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    {_product, provider_product} = create_provider_product("stripe", "price_store_success")

    {:ok, purchase} =
      Payments.create_purchase(user, provider_product, %{
        "status" => "requires_action",
        "provider_transaction_id" => "cs_success_#{System.unique_integer([:positive])}"
      })

    {:ok, _view, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/store/success?session_id=#{purchase.provider_transaction_id}")

    assert html =~ "Checkout returned."
    assert html =~ purchase.order_id
    assert html =~ "waiting for Stripe webhook confirmation"
    refute html =~ "requires_action"
  end

  test "checkout failure shows readable Stripe error", %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    {_product, provider_product} = create_provider_product("stripe", "price_store_error")

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/store")

    html =
      view
      |> element("#store-item-#{provider_product.id} button", "Buy")
      |> render_click()

    assert html =~ "No such price"
    assert html =~ "similar object exists in live mode"
    refute html =~ "raw_error"
  end

  test "store lists non-Stripe provider products as API-only rows", %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    {_product, provider_product} = create_provider_product("google", "coins_google_store")

    {:ok, _view, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/store")

    assert html =~ provider_product.external_id
    assert html =~ "google"
    assert html =~ "API only"
  end

  test "owned entitlement products cannot be bought again from store", %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    {_product, provider_product} = create_entitlement_provider_product("stripe", "price_artbook")

    {:ok, purchase} =
      Payments.create_purchase(user, provider_product, %{
        "provider_transaction_id" => "cs_owned_store_#{System.unique_integer([:positive])}"
      })

    {:ok, _completed} = Payments.fulfill_purchase(purchase)

    {:ok, _view, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/store")

    assert html =~ "Digital Artbook"
    assert html =~ "Owned"
    refute html =~ ~s(phx-value-id="#{provider_product.id}")
  end

  test "owned entitlement key disables matching Stripe product across providers", %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    {_apple_product, apple_provider_product} = create_keyed_entitlement_provider_product("apple")

    {_stripe_product, stripe_provider_product} =
      create_keyed_entitlement_provider_product("stripe")

    {:ok, purchase} =
      Payments.create_purchase(user, apple_provider_product, %{
        "provider_transaction_id" => "apple_owned_store_#{System.unique_integer([:positive])}"
      })

    {:ok, _completed} = Payments.fulfill_purchase(purchase)

    {:ok, _view, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/store")

    assert html =~ stripe_provider_product.external_id
    assert html =~ "Owned"
    refute html =~ ~s(phx-value-id="#{stripe_provider_product.id}")
  end

  defp create_provider_product(provider, external_id) do
    sku = "store_#{provider}_#{System.unique_integer([:positive])}"

    {:ok, product} =
      Payments.create_product(%{
        "sku" => sku,
        "title" => "100 Coins",
        "description" => "Consumable purchase handled by game hooks.",
        "kind" => "consumable",
        "grant_config" => %{"hook_payload" => %{"coins" => 100}}
      })

    {:ok, provider_product} =
      Payments.create_provider_product(%{
        "product_id" => product.id,
        "provider" => provider,
        "external_id" => external_id <> "_" <> to_string(System.unique_integer([:positive])),
        "currency" => "USD",
        "unit_amount" => 199
      })

    {product, provider_product}
  end

  defp create_entitlement_provider_product(provider, external_id) do
    sku = "store_artbook_#{System.unique_integer([:positive])}"

    {:ok, product} =
      Payments.create_product(%{
        "sku" => sku,
        "title" => "Digital Artbook",
        "description" => "Downloadable artbook.",
        "kind" => "entitlement",
        "grant_config" => %{"entitlement_key" => sku}
      })

    {:ok, provider_product} =
      Payments.create_provider_product(%{
        "product_id" => product.id,
        "provider" => provider,
        "external_id" => external_id <> "_" <> to_string(System.unique_integer([:positive])),
        "currency" => "USD",
        "unit_amount" => 999
      })

    {product, provider_product}
  end

  defp create_keyed_entitlement_provider_product(provider) do
    sku = "store_shared_#{provider}_#{System.unique_integer([:positive])}"

    {:ok, product} =
      Payments.create_product(%{
        "sku" => sku,
        "title" => "Shared Pass",
        "description" => "Same entitlement across providers.",
        "kind" => "entitlement",
        "grant_config" => %{"entitlement_key" => "shared_pass"}
      })

    {:ok, provider_product} =
      Payments.create_provider_product(%{
        "product_id" => product.id,
        "provider" => provider,
        "external_id" => "price_#{provider}_shared_#{System.unique_integer([:positive])}",
        "currency" => "USD",
        "unit_amount" => 999
      })

    {product, provider_product}
  end

  defp restore_env(key, nil), do: Application.delete_env(:game_server_core, key)
  defp restore_env(key, value), do: Application.put_env(:game_server_core, key, value)
end
