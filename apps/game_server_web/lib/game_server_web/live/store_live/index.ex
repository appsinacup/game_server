defmodule GameServerWeb.StoreLive.Index do
  use GameServerWeb, :live_view

  alias GameServer.Payments
  alias GameServer.Payments.ProviderConfig

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Store"))
     |> assign(:catalog, Payments.list_catalog())
     |> assign(:owned_entitlement_keys, owned_entitlement_keys(socket.assigns.current_scope.user))
     |> assign(:payment_environment, ProviderConfig.environment())
     |> assign(:success_purchase, nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, assign_success_purchase(socket, params)}
  end

  @impl true
  def handle_event("buy", %{"id" => id}, socket) do
    success_url = url(~p"/store/success") <> "?session_id={CHECKOUT_SESSION_ID}"
    cancel_url = url(~p"/store/cancel")

    attrs = %{
      "provider_product_id" => id,
      "quantity" => 1,
      "success_url" => success_url,
      "cancel_url" => cancel_url
    }

    case Payments.create_stripe_checkout(socket.assigns.current_scope.user, attrs) do
      {:ok, %{checkout_url: checkout_url}} ->
        {:noreply, redirect(socket, external: checkout_url)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, checkout_error(reason))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_path={assigns[:current_path]}>
      <div class="flex flex-col gap-6">
        <div class="flex flex-col gap-3 md:flex-row md:items-end md:justify-between">
          <div>
            <h1 class="text-3xl font-bold">{gettext("Store")}</h1>
            <div class="mt-2 flex flex-wrap items-center gap-2 text-sm text-base-content/70">
              <span class="badge badge-outline">{@payment_environment}</span>
              <span>{gettext("Subscriptions, one-time items, and consumables.")}</span>
            </div>
          </div>
          <div class="flex flex-wrap gap-2">
            <.link navigate={~p"/users/settings?tab=payments"} class="btn btn-sm btn-outline">
              {gettext("Payments")}
            </.link>
          </div>
        </div>

        <%= if @live_action == :success do %>
          <div class="alert alert-success">
            <div>
              <div class="font-semibold">{gettext("Checkout returned.")}</div>
              <div class="text-sm">
                {success_purchase_message(@success_purchase)}
              </div>
            </div>
          </div>
        <% end %>

        <%= if @live_action == :cancel do %>
          <div class="alert alert-warning">
            <div>
              <div class="font-semibold">{gettext("Checkout cancelled.")}</div>
              <div class="text-sm">{gettext("No purchase was fulfilled.")}</div>
            </div>
          </div>
        <% end %>

        <%= if @catalog == [] do %>
          <div class="card bg-base-200 p-6 rounded-lg">
            <div class="font-semibold">{gettext("No products configured.")}</div>
            <div class="mt-2 text-sm text-base-content/70">
              {gettext("Create products and provider SKUs in Admin -> Payments.")}
            </div>
          </div>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
            <div :for={provider_product <- @catalog} id={"store-item-#{provider_product.id}"}>
              <div class="card bg-base-200 p-4 rounded-lg h-full">
                <div class="flex h-full flex-col gap-4">
                  <div class="flex items-start justify-between gap-3">
                    <div>
                      <div class="font-semibold text-lg">{provider_product.product.title}</div>
                      <div class="font-mono text-xs text-base-content/60">
                        {provider_product.product.sku}
                      </div>
                    </div>
                    <span class={["badge badge-sm", kind_badge_class(provider_product.product.kind)]}>
                      {provider_product.product.kind}
                    </span>
                  </div>

                  <p class="text-sm text-base-content/75 min-h-10">
                    {provider_product.product.description || gettext("Store item")}
                  </p>

                  <div class="grid grid-cols-2 gap-2 text-sm">
                    <div>
                      <div class="text-xs uppercase text-base-content/50">{gettext("Provider")}</div>
                      <div class="font-medium">{provider_product.provider}</div>
                    </div>
                    <div>
                      <div class="text-xs uppercase text-base-content/50">{gettext("Price")}</div>
                      <div class="font-medium">{format_amount(provider_product)}</div>
                    </div>
                    <div>
                      <div class="text-xs uppercase text-base-content/50">{gettext("SKU")}</div>
                      <div class="font-mono text-xs break-all">{provider_product.external_id}</div>
                    </div>
                    <div>
                      <div class="text-xs uppercase text-base-content/50">{gettext("Status")}</div>
                      <div>
                        {if provider_product.active, do: gettext("Active"), else: gettext("Inactive")}
                      </div>
                    </div>
                  </div>

                  <div class="mt-auto flex items-center justify-between gap-2 pt-2">
                    <span class="text-xs text-base-content/60">
                      {download_hint(provider_product.product)}
                    </span>
                    <button
                      :if={owned?(provider_product, @owned_entitlement_keys)}
                      class="btn btn-sm btn-disabled"
                      disabled
                    >
                      {gettext("Owned")}
                    </button>
                    <button
                      :if={
                        provider_product.provider == "stripe" and
                          not owned?(provider_product, @owned_entitlement_keys)
                      }
                      phx-click="buy"
                      phx-value-id={provider_product.id}
                      class="btn btn-primary btn-sm"
                    >
                      {gettext("Buy")}
                    </button>
                    <button
                      :if={
                        provider_product.provider != "stripe" and
                          not owned?(provider_product, @owned_entitlement_keys)
                      }
                      class="btn btn-sm btn-disabled"
                      disabled
                    >
                      {gettext("API only")}
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp assign_success_purchase(%{assigns: %{live_action: :success}} = socket, params) do
    user = socket.assigns.current_scope.user

    purchase =
      case params["session_id"] do
        session_id when is_binary(session_id) and session_id != "" ->
          case Payments.get_purchase_by_provider_transaction("stripe", session_id) do
            %{user_id: user_id} = purchase when user_id == user.id -> purchase
            _ -> nil
          end

        _ ->
          nil
      end

    assign(socket, :success_purchase, purchase)
  end

  defp assign_success_purchase(socket, _params), do: assign(socket, :success_purchase, nil)

  defp success_purchase_message(nil) do
    gettext("Payment is still being processed. Refresh after webhook delivery.")
  end

  defp success_purchase_message(%{order_id: order_id, status: "completed"}) do
    gettext("Order %{order_id} completed.", order_id: order_id)
  end

  defp success_purchase_message(%{order_id: order_id, status: status})
       when status in ["pending", "requires_action"] do
    gettext("Order %{order_id} is waiting for Stripe webhook confirmation.", order_id: order_id)
  end

  defp success_purchase_message(%{order_id: order_id, status: "failed"}) do
    gettext("Order %{order_id} failed before payment was completed.", order_id: order_id)
  end

  defp success_purchase_message(%{order_id: order_id}) do
    gettext("Order %{order_id} returned from checkout.", order_id: order_id)
  end

  defp checkout_error(%Ecto.Changeset{}), do: gettext("Checkout failed.")

  defp checkout_error(:already_owned), do: gettext("You already own this item.")

  defp checkout_error(:purchase_already_in_progress) do
    gettext("Checkout is already open for this item. Finish or cancel that checkout first.")
  end

  defp checkout_error(:quantity_not_allowed), do: gettext("This item can only be bought once.")
  defp checkout_error(:stripe_not_configured), do: gettext("Stripe is not configured.")

  defp checkout_error({:stripe_error, %{"message" => message}}) when is_binary(message) do
    gettext("Checkout failed: %{reason}", reason: message)
  end

  defp checkout_error({:stripe_error, %{"user_message" => message}}) when is_binary(message) do
    gettext("Checkout failed: %{reason}", reason: message)
  end

  defp checkout_error({reason, _details}) when is_atom(reason),
    do: gettext("Checkout failed: %{reason}", reason: Atom.to_string(reason))

  defp checkout_error(reason) when is_atom(reason),
    do: gettext("Checkout failed: %{reason}", reason: Atom.to_string(reason))

  defp checkout_error(reason), do: gettext("Checkout failed: %{reason}", reason: inspect(reason))

  defp format_amount(%{unit_amount: nil}), do: gettext("Provider")
  defp format_amount(%{currency: nil, unit_amount: amount}), do: Integer.to_string(amount)

  defp format_amount(%{currency: currency, unit_amount: amount}) do
    major = div(amount, 100)
    minor = amount |> rem(100) |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{String.upcase(currency)} #{major}.#{minor}"
  end

  defp kind_badge_class("subscription"), do: "badge-info"
  defp kind_badge_class("consumable"), do: "badge-warning"
  defp kind_badge_class(_kind), do: "badge-primary"

  defp owned?(%{product: %{kind: kind} = product}, owned_entitlement_keys)
       when kind in ["entitlement", "subscription"] do
    MapSet.member?(owned_entitlement_keys, Payments.product_entitlement_key(product))
  end

  defp owned?(_provider_product, _owned_entitlement_keys), do: false

  defp owned_entitlement_keys(user) do
    user.id
    |> Payments.list_user_entitlements()
    |> Enum.map(& &1.key)
    |> MapSet.new()
  end

  defp download_hint(product) do
    if download_config(product) do
      gettext("Downloadable")
    else
      gettext("Grant")
    end
  end

  defp download_config(product) do
    map_value(product.grant_config, "download") || map_value(product.metadata, "download")
  end

  defp map_value(nil, _key), do: nil
  defp map_value(map, key) when is_map(map), do: map[key] || atom_map_value(map, key)
  defp map_value(_value, _key), do: nil

  defp atom_map_value(map, "download"), do: map[:download]
  defp atom_map_value(_map, _key), do: nil
end
