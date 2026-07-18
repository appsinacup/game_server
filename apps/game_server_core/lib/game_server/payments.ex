defmodule GameServer.Payments do
  @moduledoc """
  Payment catalog, purchase ledger, and entitlements.

  Provider-specific integrations validate or create transactions, but this
  context remains the source of truth for what a user owns inside the game.
  """

  import Ecto.Query, warn: false
  require Logger

  alias GameServer.Accounts.User
  alias GameServer.Payments.Entitlement
  alias GameServer.Payments.Product
  alias GameServer.Payments.ProviderConfig
  alias GameServer.Payments.ProviderEvent
  alias GameServer.Payments.ProviderProduct
  alias GameServer.Payments.Purchase
  alias GameServer.Payments.ReconciliationCursor
  alias GameServer.Repo

  @pubsub GameServer.PubSub
  @store_validation_providers ~w(apple google steam)
  @apple_reversal_notifications ~w(REFUND REVOKE EXPIRED)
  @apple_activation_notifications ~w(
    SUBSCRIBED
    DID_RENEW
    DID_RECOVER
    INTERACTIVE_RENEWAL
    DID_CHANGE_RENEWAL_PREF
    DID_CHANGE_RENEWAL_STATUS
  )

  # ---------------------------------------------------------------------------
  # Catalog
  # ---------------------------------------------------------------------------

  @spec create_product(map()) :: {:ok, Product.t()} | {:error, Ecto.Changeset.t()}
  def create_product(attrs) when is_map(attrs) do
    %Product{}
    |> Product.changeset(normalize_params(attrs))
    |> Repo.insert()
  end

  @spec update_product(Product.t(), map()) :: {:ok, Product.t()} | {:error, Ecto.Changeset.t()}
  def update_product(%Product{} = product, attrs) when is_map(attrs) do
    product
    |> Product.changeset(normalize_params(attrs))
    |> Repo.update()
  end

  @spec get_product(Ecto.UUID.t()) :: Product.t() | nil
  def get_product(id), do: Repo.get_uuid(Product, id)

  @spec get_product_by_sku(String.t()) :: Product.t() | nil
  def get_product_by_sku(sku) when is_binary(sku), do: Repo.get_by(Product, sku: sku)

  @spec list_products(keyword()) :: [Product.t()]
  def list_products(opts \\ []) do
    include_inactive = Keyword.get(opts, :include_inactive, false)

    Product
    |> maybe_active_only(include_inactive)
    |> order_by([p], asc: p.sku)
    |> Repo.all()
  end

  @spec create_provider_product(map()) ::
          {:ok, ProviderProduct.t()} | {:error, Ecto.Changeset.t()}
  def create_provider_product(attrs) when is_map(attrs) do
    %ProviderProduct{}
    |> ProviderProduct.changeset(normalize_params(attrs))
    |> Repo.insert()
  end

  @spec update_provider_product(ProviderProduct.t(), map()) ::
          {:ok, ProviderProduct.t()} | {:error, Ecto.Changeset.t()}
  def update_provider_product(%ProviderProduct{} = provider_product, attrs)
      when is_map(attrs) do
    provider_product
    |> ProviderProduct.changeset(normalize_params(attrs))
    |> Repo.update()
  end

  @spec get_provider_product(Ecto.UUID.t()) :: ProviderProduct.t() | nil
  def get_provider_product(id) do
    ProviderProduct
    |> Repo.get_uuid(id)
    |> preload_product()
  end

  @spec get_provider_product(String.t(), String.t()) :: ProviderProduct.t() | nil
  def get_provider_product(provider, external_id)
      when is_binary(provider) and is_binary(external_id) do
    ProviderProduct
    |> Repo.get_by(provider: provider, external_id: external_id)
    |> preload_product()
  end

  @spec list_catalog(String.t() | nil) :: [ProviderProduct.t()]
  def list_catalog(provider \\ nil) do
    query =
      from pp in ProviderProduct,
        join: p in assoc(pp, :product),
        where: pp.active == true and p.active == true,
        preload: [product: p],
        order_by: [asc: pp.provider, asc: p.sku]

    query =
      if is_binary(provider) and provider != "" do
        from pp in query, where: pp.provider == ^provider
      else
        query
      end

    Repo.all(query)
  end

  # ---------------------------------------------------------------------------
  # Purchases and fulfillment
  # ---------------------------------------------------------------------------

  @spec create_purchase(User.t(), ProviderProduct.t(), map()) ::
          {:ok, Purchase.t()} | {:error, Ecto.Changeset.t()}
  def create_purchase(user, %ProviderProduct{} = provider_product, attrs \\ %{}) do
    user_id = user.id
    provider_product = Repo.preload(provider_product, :product)
    attrs = normalize_params(attrs)
    quantity = parse_positive_int(attrs["quantity"], 1)
    unit_amount = provider_product.unit_amount

    purchase_attrs =
      attrs
      |> Map.merge(%{
        "user_id" => user_id,
        "product_id" => provider_product.product_id,
        "provider_product_id" => provider_product.id,
        "provider" => provider_product.provider,
        "order_id" => attrs["order_id"] || generate_order_id(),
        "status" => attrs["status"] || "pending",
        "quantity" => quantity,
        "currency" => attrs["currency"] || provider_product.currency,
        "amount" => attrs["amount"] || total_amount(unit_amount, quantity),
        "environment" => attrs["environment"] || default_environment()
      })

    %Purchase{}
    |> Purchase.changeset(purchase_attrs)
    |> Repo.insert()
  end

  @spec get_purchase(Ecto.UUID.t()) :: Purchase.t() | nil
  def get_purchase(id), do: Repo.get_uuid(Purchase, id) |> preload_purchase()

  @spec get_purchase_by_order_id(String.t()) :: Purchase.t() | nil
  def get_purchase_by_order_id(order_id) when is_binary(order_id) do
    Purchase
    |> Repo.get_by(order_id: order_id)
    |> preload_purchase()
  end

  @spec get_purchase_by_provider_transaction(String.t(), String.t()) :: Purchase.t() | nil
  def get_purchase_by_provider_transaction(provider, transaction_id)
      when is_binary(provider) and is_binary(transaction_id) do
    Purchase
    |> Repo.get_by(provider: provider, provider_transaction_id: transaction_id)
    |> preload_purchase()
  end

  @spec get_purchase_by_provider_original_transaction(String.t(), String.t()) ::
          Purchase.t() | nil
  def get_purchase_by_provider_original_transaction(provider, transaction_id)
      when is_binary(provider) and is_binary(transaction_id) do
    Purchase
    |> Repo.get_by(provider: provider, provider_original_transaction_id: transaction_id)
    |> preload_purchase()
  end

  @spec list_user_purchases(Ecto.UUID.t(), keyword()) :: [Purchase.t()]
  def list_user_purchases(user_id, opts \\ []) when is_binary(user_id) do
    limit = opts |> Keyword.get(:limit, 100) |> min(250)

    from(p in Purchase,
      where: p.user_id == ^user_id,
      order_by: [desc: p.inserted_at],
      limit: ^limit,
      preload: [:product, :provider_product]
    )
    |> Repo.all()
  end

  @spec fulfill_purchase(Purchase.t(), map()) :: {:ok, Purchase.t()} | {:error, term()}
  def fulfill_purchase(%Purchase{} = purchase, provider_payload \\ %{})
      when is_map(provider_payload) do
    result =
      Repo.transaction(fn ->
        purchase =
          Purchase
          |> Repo.get!(purchase.id)
          |> Repo.preload([:product, :provider_product])

        case purchase.status do
          "completed" ->
            {:ok, purchase, :already_fulfilled}

          status when status in ["refunded", "revoked"] ->
            Repo.rollback({:not_fulfillable, status})

          _ ->
            with {:ok, updated} <- complete_purchase(purchase, provider_payload),
                 :ok <- grant_purchase(updated) do
              {:ok, updated, :fulfilled}
            else
              {:error, reason} -> Repo.rollback(reason)
            end
        end
      end)

    case result do
      {:ok, {:ok, purchase, :fulfilled}} ->
        after_purchase_fulfilled(purchase)
        {:ok, preload_purchase(purchase)}

      {:ok, {:ok, purchase, :already_fulfilled}} ->
        {:ok, preload_purchase(purchase)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec revoke_purchase(Purchase.t(), map()) :: {:ok, Purchase.t()} | {:error, term()}
  def revoke_purchase(%Purchase{} = purchase, attrs \\ %{}) when is_map(attrs) do
    now = DateTime.utc_now(:second)
    attrs = normalize_params(attrs)

    Repo.transaction(fn ->
      purchase =
        Purchase
        |> Repo.get!(purchase.id)
        |> Repo.preload(:product)

      status = attrs["status"] || "revoked"

      {:ok, updated} =
        purchase
        |> Purchase.changeset(%{
          status: status,
          revoked_at: now,
          raw_provider_payload:
            merge_payload(purchase.raw_provider_payload, attrs["payload"] || %{})
        })
        |> Repo.update()

      entitlements = revoke_entitlements_for_purchase(updated, now, attrs["reason"])
      {updated, entitlements}
    end)
    |> case do
      {:ok, {purchase, entitlements}} ->
        after_purchase_revoked(purchase)
        Enum.each(entitlements, &after_entitlement_changed/1)
        {:ok, purchase}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Store receipt validation
  # ---------------------------------------------------------------------------

  @spec validate_store_purchase(User.t(), String.t(), map()) ::
          {:ok, %{purchase: Purchase.t(), seen_before: boolean()}} | {:error, term()}
  def validate_store_purchase(%User{} = user, provider, attrs)
      when provider in @store_validation_providers and is_map(attrs) do
    with {:ok, validation} <- provider_adapter(provider).validate_purchase(user, attrs),
         validation <- normalize_params(validation),
         {:ok, external_id} <- required_value(validation, "product_id"),
         {:ok, transaction_id} <- required_value(validation, "transaction_id"),
         %ProviderProduct{} = provider_product <- get_provider_product(provider, external_id) do
      case get_purchase_by_provider_transaction(provider, transaction_id) do
        %Purchase{user_id: existing_user_id} = purchase when existing_user_id == user.id ->
          {:ok, %{purchase: purchase, seen_before: true}}

        %Purchase{} ->
          {:error, :receipt_already_used}

        nil ->
          with :ok <- ensure_checkout_allowed(user, provider_product, validation) do
            create_validated_store_purchase(user, provider_product, validation)
          end
      end
    else
      nil -> {:error, :provider_product_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Stripe
  # ---------------------------------------------------------------------------

  @spec create_stripe_checkout(User.t(), map()) ::
          {:ok,
           %{purchase: Purchase.t(), checkout_url: String.t(), provider_session_id: String.t()}}
          | {:error, term()}
  def create_stripe_checkout(%User{} = user, attrs) when is_map(attrs) do
    attrs = normalize_params(attrs)

    with {:ok, provider_product} <- resolve_provider_product("stripe", attrs),
         :ok <- ensure_checkout_allowed(user, provider_product, attrs),
         {:ok, purchase} <- create_purchase(user, provider_product, attrs) do
      case stripe_adapter().create_checkout_session(purchase, provider_product, attrs) do
        {:ok, session} ->
          with {:ok, updated_purchase} <- mark_purchase_requires_action(purchase, session) do
            {:ok,
             %{
               purchase: updated_purchase,
               checkout_url: session["url"],
               provider_session_id: session["id"]
             }}
          end

        {:error, reason} ->
          mark_purchase_failed(purchase, "stripe_checkout_session_failed", reason)
          {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec handle_stripe_webhook(binary(), binary() | nil) :: {:ok, atom()} | {:error, term()}
  def handle_stripe_webhook(raw_body, signature) when is_binary(raw_body) do
    with {:ok, event} <- stripe_adapter().verify_webhook(raw_body, signature),
         event <- normalize_params(event),
         {:ok, event_id} <- required_value(event, "id"),
         event_type when is_binary(event_type) <- event["type"],
         {:ok, _record, true} <- record_provider_event("stripe", event_id, event_type, event) do
      process_stripe_event(event)
    else
      {:ok, _record, false} -> {:ok, :duplicate}
      nil -> {:error, :missing_event_type}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec reconcile_stripe_purchase(Purchase.t()) ::
          {:ok, %{purchase: Purchase.t(), result: atom(), stripe_session: map()}}
          | {:error, term()}
  def reconcile_stripe_purchase(
        %Purchase{
          provider: "stripe",
          provider_transaction_id: "cs_" <> _rest = session_id
        } = purchase
      ) do
    with {:ok, session} <- stripe_adapter().retrieve_checkout_session(session_id),
         session <- normalize_params(session),
         :ok <- ensure_stripe_session_matches_purchase(purchase, session),
         {:ok, updated_purchase, result} <-
           reconcile_stripe_purchase_from_session(purchase, session) do
      {:ok, %{purchase: updated_purchase, result: result, stripe_session: session}}
    end
  end

  def reconcile_stripe_purchase(%Purchase{provider: "stripe"}),
    do: {:error, :missing_stripe_session_id}

  def reconcile_stripe_purchase(%Purchase{}), do: {:error, :not_stripe_purchase}

  @spec cancel_stripe_subscription_at_period_end(User.t(), Ecto.UUID.t()) ::
          {:ok,
           %{purchase: Purchase.t(), entitlement: Entitlement.t(), stripe_subscription: map()}}
          | {:error, term()}
  def cancel_stripe_subscription_at_period_end(%User{} = user, entitlement_id)
      when is_binary(entitlement_id) do
    with {:ok, %Entitlement{} = entitlement} <-
           get_user_subscription_entitlement(user, entitlement_id),
         %Purchase{} = purchase <- entitlement.source_purchase,
         {:ok, subscription_id} <- stripe_subscription_id(purchase),
         {:ok, subscription} <-
           stripe_adapter().cancel_subscription_at_period_end(subscription_id),
         subscription <- normalize_params(subscription),
         {:ok, updated_purchase} <-
           update_purchase_from_stripe_subscription(
             purchase,
             subscription,
             "cancel_at_period_end"
           ),
         {:ok, updated_entitlements} <-
           update_entitlements_from_stripe_subscription(updated_purchase, subscription) do
      updated_entitlement =
        Enum.find(updated_entitlements, &(&1.id == entitlement.id)) ||
          Entitlement
          |> Repo.get(entitlement_id)
          |> Repo.preload([:product, :source_purchase])

      {:ok,
       %{
         purchase: updated_purchase,
         entitlement: updated_entitlement,
         stripe_subscription: subscription
       }}
    else
      %Purchase{} -> {:error, :not_stripe_subscription}
      {:error, reason} -> {:error, reason}
    end
  end

  def cancel_stripe_subscription_at_period_end(%User{}, _entitlement_id),
    do: {:error, :invalid_entitlement_id}

  # ---------------------------------------------------------------------------
  # Steam
  # ---------------------------------------------------------------------------

  @spec create_steam_checkout(User.t(), map()) ::
          {:ok,
           %{
             purchase: Purchase.t(),
             provider_transaction_id: String.t() | nil,
             steam_url: String.t() | nil
           }}
          | {:error, term()}
  def create_steam_checkout(%User{} = user, attrs) when is_map(attrs) do
    attrs =
      attrs
      |> normalize_params()
      |> Map.put_new("order_id", generate_steam_order_id())

    with {:ok, provider_product} <- resolve_provider_product("steam", attrs),
         :ok <- ensure_checkout_allowed(user, provider_product, attrs),
         {:ok, purchase} <- create_purchase(user, provider_product, attrs) do
      case provider_adapter("steam").init_transaction(purchase, provider_product, attrs) do
        {:ok, result} ->
          with {:ok, updated_purchase} <- mark_steam_purchase_requires_action(purchase, result) do
            params = steam_response_params(result)

            {:ok,
             %{
               purchase: updated_purchase,
               provider_transaction_id: params["transid"],
               steam_url: params["steamurl"]
             }}
          end

        {:error, reason} ->
          mark_purchase_failed(purchase, "steam_checkout_session_failed", reason)
          {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec finalize_steam_purchase(User.t(), map()) ::
          {:ok, %{purchase: Purchase.t()}} | {:error, term()}
  def finalize_steam_purchase(%User{} = user, attrs) when is_map(attrs) do
    attrs = normalize_params(attrs)

    with {:ok, order_id} <- required_value(attrs, "order_id"),
         %Purchase{provider: "steam", user_id: user_id} = purchase when user_id == user.id <-
           get_purchase_by_order_id(order_id),
         {:ok, validation} <- provider_adapter("steam").finalize_transaction(purchase, attrs),
         validation <- normalize_params(validation),
         {:ok, updated} <- update_purchase_from_validation(purchase, validation),
         {:ok, final_purchase} <- apply_validated_status(updated, validation) do
      {:ok, %{purchase: final_purchase}}
    else
      nil -> {:error, :purchase_not_found}
      %Purchase{} -> {:error, :purchase_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Provider webhooks
  # ---------------------------------------------------------------------------

  @spec handle_google_webhook(binary(), binary() | nil) :: {:ok, atom()} | {:error, term()}
  def handle_google_webhook(raw_body, authorization_header) when is_binary(raw_body) do
    with {:ok, event} <- provider_adapter("google").verify_webhook(raw_body, authorization_header),
         event <- normalize_params(event),
         event_id <- event["message_id"] || provider_event_hash("google", raw_body),
         event_type <- google_event_type(event),
         {:ok, _record, true} <- record_provider_event("google", event_id, event_type, event) do
      process_google_event(event)
    else
      {:ok, _record, false} -> {:ok, :duplicate}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec handle_apple_webhook(binary()) :: {:ok, atom()} | {:error, term()}
  def handle_apple_webhook(raw_body) when is_binary(raw_body) do
    with {:ok, event} <- provider_adapter("apple").verify_notification(raw_body),
         event <- normalize_params(event),
         event_id <- event["notificationUUID"] || provider_event_hash("apple", raw_body),
         event_type when is_binary(event_type) <- event["notificationType"],
         {:ok, _record, true} <- record_provider_event("apple", event_id, event_type, event) do
      process_apple_event(event)
    else
      {:ok, _record, false} -> {:ok, :duplicate}
      nil -> {:error, :missing_event_type}
      {:error, reason} -> {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Entitlements
  # ---------------------------------------------------------------------------

  @spec list_user_entitlements(Ecto.UUID.t(), keyword()) :: [Entitlement.t()]
  def list_user_entitlements(user_id, opts \\ []) when is_binary(user_id) do
    include_inactive = Keyword.get(opts, :include_inactive, false)
    now = DateTime.utc_now(:second)

    query =
      from e in Entitlement,
        where: e.user_id == ^user_id,
        order_by: [asc: e.key],
        preload: [:product, :source_purchase]

    query =
      if include_inactive do
        query
      else
        from e in query,
          where:
            e.status == "active" and
              (is_nil(e.expires_at) or e.expires_at > ^now)
      end

    Repo.all(query)
  end

  @spec has_entitlement?(Ecto.UUID.t(), String.t()) :: boolean()
  def has_entitlement?(user_id, key) when is_binary(user_id) and is_binary(key) do
    now = DateTime.utc_now(:second)

    from(e in Entitlement,
      where:
        e.user_id == ^user_id and e.key == ^key and e.status == "active" and
          (is_nil(e.expires_at) or e.expires_at > ^now),
      select: count(e.id)
    )
    |> Repo.one()
    |> Kernel.>(0)
  end

  @spec product_entitlement_key(Product.t()) :: String.t()
  def product_entitlement_key(%Product{grant_config: config, sku: sku}) do
    config = config || %{}
    config["entitlement_key"] || config[:entitlement_key] || sku
  end

  @spec admin_stats() :: map()
  def admin_stats do
    %{
      products: count_products(),
      provider_products: count_provider_products(),
      purchases: count_purchases(),
      completed_purchases: count_purchases(status: "completed"),
      entitlements: count_entitlements(),
      active_entitlements: count_entitlements(status: "active"),
      provider_events: count_provider_events()
    }
  end

  @spec stripe_config_status() :: map()
  def stripe_config_status do
    secret_key = ProviderConfig.stripe_secret_key()
    webhook_secret = ProviderConfig.stripe_webhook_secret()
    secret_key_source = ProviderConfig.stripe_secret_key_source()
    webhook_secret_source = ProviderConfig.stripe_webhook_secret_source()
    api_version_source = ProviderConfig.stripe_api_version_source()

    %{
      configured: present?(secret_key) and present?(webhook_secret),
      secret_key_configured: present?(secret_key),
      webhook_secret_configured: present?(webhook_secret),
      mode: stripe_key_mode(secret_key),
      selected_secret_key: source_label(secret_key_source),
      selected_webhook_secret: source_label(webhook_secret_source),
      expected_secret_keys: ProviderConfig.stripe_candidate_labels(:secret_key),
      expected_webhook_secrets: ProviderConfig.stripe_candidate_labels(:webhook_secret),
      api_version: ProviderConfig.stripe_api_version(),
      api_version_source: source_label(api_version_source) || "stripity_stripe default",
      masked_secret_key: mask_secret(secret_key),
      masked_webhook_secret: mask_secret(webhook_secret),
      environment: default_environment()
    }
  end

  @spec provider_adapter_statuses() :: [map()]
  def provider_adapter_statuses do
    adapters = Application.get_env(:game_server_core, :payment_provider_adapters, [])
    stripe_status = stripe_config_status()

    stripe = %{
      provider: "stripe",
      module: GameServer.Payments.Providers.Stripe,
      configured: stripe_status.configured,
      status: Map.put(stripe_status, :provider, "stripe")
    }

    store_adapters =
      for {provider, default_module} <- [
            {"apple", GameServer.Payments.Providers.Apple},
            {"google", GameServer.Payments.Providers.Google},
            {"steam", GameServer.Payments.Providers.Steam}
          ] do
        key = String.to_existing_atom(provider)
        module = Keyword.get(adapters, key, default_module)
        status = provider_module_status(module)

        %{
          provider: provider,
          module: module,
          configured: Map.get(status, :configured, module != default_module),
          status: status
        }
      end

    [stripe | store_adapters]
  end

  @spec list_admin_products(keyword()) :: [Product.t()]
  def list_admin_products(opts \\ []) do
    page = positive_page(opts)
    page_size = page_size(opts)
    offset = page_offset(page, page_size)

    from(p in Product,
      order_by: [desc: p.inserted_at, desc: p.id],
      limit: ^page_size,
      offset: ^offset
    )
    |> Repo.all()
  end

  @spec count_products(keyword()) :: non_neg_integer()
  def count_products(_opts \\ []) do
    Repo.aggregate(Product, :count, :id)
  end

  @spec list_admin_provider_products(keyword()) :: [ProviderProduct.t()]
  def list_admin_provider_products(opts \\ []) do
    page = positive_page(opts)
    page_size = page_size(opts)
    offset = page_offset(page, page_size)

    from(pp in ProviderProduct,
      order_by: [desc: pp.inserted_at, desc: pp.id],
      preload: [:product],
      limit: ^page_size,
      offset: ^offset
    )
    |> Repo.all()
  end

  @spec count_provider_products(keyword()) :: non_neg_integer()
  def count_provider_products(_opts \\ []) do
    Repo.aggregate(ProviderProduct, :count, :id)
  end

  @spec list_admin_purchases(keyword()) :: [Purchase.t()]
  def list_admin_purchases(opts \\ []) do
    page = positive_page(opts)
    page_size = page_size(opts)
    offset = page_offset(page, page_size)

    Purchase
    |> admin_purchase_filters(opts)
    |> order_by([p], desc: p.inserted_at, desc: p.id)
    |> preload([:product, :provider_product, :user])
    |> limit(^page_size)
    |> offset(^offset)
    |> Repo.all()
  end

  @spec count_purchases(keyword()) :: non_neg_integer()
  def count_purchases(opts \\ []) do
    Purchase
    |> admin_purchase_filters(opts)
    |> Repo.aggregate(:count, :id)
  end

  @spec list_admin_entitlements(keyword()) :: [Entitlement.t()]
  def list_admin_entitlements(opts \\ []) do
    page = positive_page(opts)
    page_size = page_size(opts)
    offset = page_offset(page, page_size)

    Entitlement
    |> admin_entitlement_filters(opts)
    |> order_by([e], desc: e.inserted_at, desc: e.id)
    |> preload([:product, :source_purchase, :user])
    |> limit(^page_size)
    |> offset(^offset)
    |> Repo.all()
  end

  @spec count_entitlements(keyword()) :: non_neg_integer()
  def count_entitlements(opts \\ []) do
    Entitlement
    |> admin_entitlement_filters(opts)
    |> Repo.aggregate(:count, :id)
  end

  @spec list_provider_events(keyword()) :: [ProviderEvent.t()]
  def list_provider_events(opts \\ []) do
    page = positive_page(opts)
    page_size = page_size(opts)
    offset = page_offset(page, page_size)

    ProviderEvent
    |> provider_event_filters(opts)
    |> order_by([e], desc: e.inserted_at, desc: e.id)
    |> limit(^page_size)
    |> offset(^offset)
    |> Repo.all()
  end

  @spec count_provider_events(keyword()) :: non_neg_integer()
  def count_provider_events(opts \\ []) do
    ProviderEvent
    |> provider_event_filters(opts)
    |> Repo.aggregate(:count, :id)
  end

  @spec list_reconciliation_cursors(keyword()) :: [ReconciliationCursor.t()]
  def list_reconciliation_cursors(opts \\ []) do
    page = positive_page(opts)
    page_size = page_size(opts)
    offset = page_offset(page, page_size)

    from(c in ReconciliationCursor,
      order_by: [asc: c.provider, asc: c.name],
      limit: ^page_size,
      offset: ^offset
    )
    |> Repo.all()
  end

  @spec count_reconciliation_cursors(keyword()) :: non_neg_integer()
  def count_reconciliation_cursors(_opts \\ []) do
    Repo.aggregate(ReconciliationCursor, :count, :id)
  end

  @spec record_provider_event(String.t(), String.t(), String.t(), map(), map()) ::
          {:ok, ProviderEvent.t(), boolean()} | {:error, Ecto.Changeset.t()}
  def record_provider_event(provider, event_id, event_type, payload, metadata \\ %{})
      when is_binary(provider) and is_binary(event_id) and is_binary(event_type) and
             is_map(payload) and is_map(metadata) do
    case Repo.get_by(ProviderEvent, provider: provider, event_id: event_id) do
      %ProviderEvent{} = event ->
        {:ok, event, false}

      nil ->
        %ProviderEvent{}
        |> ProviderEvent.changeset(%{
          provider: provider,
          event_id: event_id,
          event_type: event_type,
          payload: payload,
          metadata: metadata,
          processed_at: DateTime.utc_now(:second)
        })
        |> Repo.insert()
        |> case do
          {:ok, event} -> {:ok, event, true}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Internals
  # ---------------------------------------------------------------------------

  defp maybe_active_only(query, true), do: query
  defp maybe_active_only(query, false), do: from(p in query, where: p.active == true)

  defp preload_product(nil), do: nil
  defp preload_product(provider_product), do: Repo.preload(provider_product, :product)

  defp preload_purchase(nil), do: nil
  defp preload_purchase(purchase), do: Repo.preload(purchase, [:product, :provider_product])

  defp resolve_provider_product(provider, %{"provider_product_id" => id}) do
    case GameServer.UUIDv7.cast_or_nil(id) do
      nil ->
        {:error, :invalid_provider_product_id}

      provider_product_id ->
        case get_provider_product(provider_product_id) do
          %ProviderProduct{provider: ^provider, active: true, product: %Product{active: true}} =
              provider_product ->
            {:ok, provider_product}

          _ ->
            {:error, :provider_product_not_found}
        end
    end
  end

  defp resolve_provider_product(provider, %{"product_sku" => sku}) when is_binary(sku) do
    query =
      from pp in ProviderProduct,
        join: p in assoc(pp, :product),
        where:
          pp.provider == ^provider and pp.active == true and p.active == true and p.sku == ^sku,
        preload: [product: p],
        limit: 1

    case Repo.one(query) do
      %ProviderProduct{} = provider_product -> {:ok, provider_product}
      nil -> {:error, :provider_product_not_found}
    end
  end

  defp resolve_provider_product(_provider, _attrs), do: {:error, :missing_product_reference}

  defp ensure_checkout_allowed(
         %User{} = user,
         %ProviderProduct{product: %Product{} = product},
         attrs
       ) do
    case ensure_single_ownership_quantity(product, attrs) do
      :ok -> ensure_single_ownership_available(user, product)
      other -> other
    end
  end

  defp ensure_checkout_allowed(_user, _provider_product, _attrs), do: :ok

  defp ensure_single_ownership_quantity(%Product{kind: kind}, attrs)
       when kind in ["entitlement", "subscription"] do
    if parse_positive_int(attrs["quantity"], 1) == 1 do
      :ok
    else
      {:error, :quantity_not_allowed}
    end
  end

  defp ensure_single_ownership_quantity(_product, _attrs), do: :ok

  defp ensure_single_ownership_available(%User{} = user, %Product{kind: kind} = product)
       when kind in ["entitlement", "subscription"] do
    key = product_entitlement_key(product)

    cond do
      has_entitlement?(user.id, key) ->
        {:error, :already_owned}

      purchase_in_progress?(user.id, key) ->
        {:error, :purchase_already_in_progress}

      true ->
        :ok
    end
  end

  defp ensure_single_ownership_available(_user, _product), do: :ok

  defp purchase_in_progress?(user_id, entitlement_key) do
    from(p in Purchase,
      where: p.user_id == ^user_id and p.status == "requires_action",
      preload: [:product]
    )
    |> Repo.all()
    |> Enum.any?(fn %Purchase{product: product} ->
      product_entitlement_key(product) == entitlement_key
    end)
  end

  defp mark_purchase_failed(%Purchase{} = purchase, reason, provider_reason) do
    payload = %{
      "failure_reason" => reason,
      "provider_reason" => inspect(provider_reason) |> String.slice(0, 1_000)
    }

    result =
      purchase
      |> Purchase.changeset(%{
        status: "failed",
        raw_provider_payload: merge_payload(purchase.raw_provider_payload, payload)
      })
      |> Repo.update()

    Logger.warning(
      "Payment checkout failed",
      purchase_id: purchase.id,
      order_id: purchase.order_id,
      provider: purchase.provider,
      reason: reason,
      provider_reason: inspect(provider_reason)
    )

    result
  end

  defp mark_purchase_requires_action(%Purchase{} = purchase, session) when is_map(session) do
    metadata =
      purchase.metadata
      |> Map.put("stripe_checkout_url", session["url"])
      |> Map.put("stripe_session_id", session["id"])

    purchase
    |> Purchase.changeset(%{
      status: "requires_action",
      provider_transaction_id: session["id"],
      metadata: metadata,
      raw_provider_payload:
        merge_payload(purchase.raw_provider_payload, %{"stripe_session" => session})
    })
    |> Repo.update()
  end

  defp mark_steam_purchase_requires_action(%Purchase{} = purchase, result) when is_map(result) do
    params = steam_response_params(result)

    metadata =
      purchase.metadata
      |> Map.put("steam_url", params["steamurl"])
      |> Map.put("steam_transaction_id", params["transid"])
      |> put_if_present(
        "steam_agreements",
        params["agreements"],
        not is_nil(params["agreements"])
      )

    purchase
    |> Purchase.changeset(%{
      status: "requires_action",
      provider_transaction_id: params["transid"] || purchase.provider_transaction_id,
      metadata: metadata,
      raw_provider_payload:
        merge_payload(purchase.raw_provider_payload, %{"steam_init" => result})
    })
    |> Repo.update()
  end

  defp update_purchase_from_validation(%Purchase{} = purchase, validation) do
    validated_status = validation["status"] || "completed"

    attrs = %{
      status: status_before_fulfillment(validated_status),
      provider_transaction_id: validation["transaction_id"] || purchase.provider_transaction_id,
      provider_original_transaction_id:
        validation["original_transaction_id"] || purchase.provider_original_transaction_id,
      quantity: validation["quantity"] || purchase.quantity,
      currency: validation["currency"] || purchase.currency,
      amount: validation["amount"] || purchase.amount,
      environment: validation["environment"] || purchase.environment,
      expires_at: parse_datetime(validation["expires_at"]) || purchase.expires_at,
      raw_provider_payload:
        merge_payload(purchase.raw_provider_payload, validation["raw_payload"] || validation)
    }

    purchase
    |> Purchase.changeset(attrs)
    |> Repo.update()
  end

  defp apply_validated_status(%Purchase{} = purchase, %{"status" => status})
       when status in ["refunded", "revoked"] do
    revoke_purchase(purchase, %{
      "status" => status,
      "reason" => "provider_validation",
      "payload" => purchase.raw_provider_payload || %{}
    })
  end

  defp apply_validated_status(%Purchase{} = purchase, %{"status" => "completed"}) do
    fulfill_purchase(purchase, purchase.raw_provider_payload || %{})
  end

  defp apply_validated_status(%Purchase{} = purchase, _validation), do: {:ok, purchase}

  defp complete_purchase(%Purchase{} = purchase, provider_payload) do
    purchase
    |> Purchase.changeset(%{
      status: "completed",
      purchased_at: purchase.purchased_at || DateTime.utc_now(:second),
      raw_provider_payload: merge_payload(purchase.raw_provider_payload, provider_payload)
    })
    |> Repo.update()
  end

  defp grant_purchase(%Purchase{product: %Product{kind: "consumable"}}), do: :ok

  defp grant_purchase(%Purchase{product: %Product{} = product} = purchase) do
    key = product_entitlement_key(product)
    expires_at = purchase.expires_at || entitlement_expiry(product)
    now = DateTime.utc_now(:second)

    attrs = %{
      user_id: purchase.user_id,
      product_id: product.id,
      source_purchase_id: purchase.id,
      key: key,
      status: "active",
      starts_at: now,
      expires_at: expires_at,
      revoked_at: nil,
      metadata: %{"product_sku" => product.sku, "provider" => purchase.provider}
    }

    entitlement =
      case Repo.get_by(Entitlement, user_id: purchase.user_id, key: key) do
        nil ->
          %Entitlement{}

        %Entitlement{} = existing ->
          existing
      end

    case entitlement |> Entitlement.changeset(attrs) |> Repo.insert_or_update() do
      {:ok, entitlement} ->
        after_entitlement_changed(entitlement)
        :ok

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp create_validated_store_purchase(%User{} = user, provider_product, validation) do
    validated_status = validation["status"] || "completed"

    attrs = %{
      "status" => status_before_fulfillment(validated_status),
      "provider_transaction_id" => validation["transaction_id"],
      "provider_original_transaction_id" => validation["original_transaction_id"],
      "quantity" => validation["quantity"] || 1,
      "currency" => validation["currency"],
      "amount" => validation["amount"],
      "environment" => validation["environment"] || default_environment(),
      "expires_at" => parse_datetime(validation["expires_at"]),
      "raw_provider_payload" => validation["raw_payload"] || validation
    }

    with {:ok, purchase} <- create_purchase(user, provider_product, attrs),
         {:ok, fulfilled_purchase} <- maybe_fulfill_validated_purchase(purchase, validated_status) do
      {:ok, %{purchase: fulfilled_purchase, seen_before: false}}
    end
  end

  defp status_before_fulfillment("completed"), do: "pending"
  defp status_before_fulfillment(status), do: status

  defp maybe_fulfill_validated_purchase(%Purchase{} = purchase, "completed") do
    fulfill_purchase(purchase, purchase.raw_provider_payload)
  end

  defp maybe_fulfill_validated_purchase(%Purchase{} = purchase, _status), do: {:ok, purchase}

  defp process_stripe_event(%{
         "type" => "checkout.session.completed",
         "data" => %{"object" => object}
       })
       when is_map(object) do
    with {:ok, purchase} <- purchase_from_provider_object(object),
         {:ok, updated} <- update_purchase_from_stripe_session(purchase, object) do
      if stripe_session_paid?(object) do
        with {:ok, _purchase} <- fulfill_purchase(updated, %{"stripe_session" => object}) do
          {:ok, :processed}
        end
      else
        {:ok, :processed}
      end
    end
  end

  defp process_stripe_event(%{
         "type" => "checkout.session.async_payment_succeeded",
         "data" => %{"object" => object}
       })
       when is_map(object) do
    with {:ok, purchase} <- purchase_from_provider_object(object),
         {:ok, updated} <- update_purchase_from_stripe_session(purchase, object),
         {:ok, _purchase} <- fulfill_purchase(updated, %{"stripe_session" => object}) do
      {:ok, :processed}
    end
  end

  defp process_stripe_event(%{
         "type" => "checkout.session.async_payment_failed",
         "data" => %{"object" => object}
       })
       when is_map(object) do
    with {:ok, purchase} <- purchase_from_provider_object(object),
         {:ok, _purchase, :failed} <-
           update_purchase_from_stripe_reconciliation(purchase, object, "failed", :failed) do
      {:ok, :processed}
    end
  end

  defp process_stripe_event(%{"type" => "charge.succeeded", "data" => %{"object" => object}})
       when is_map(object) do
    with {:ok, purchase} <- purchase_from_provider_object(object),
         {:ok, _purchase} <- update_purchase_from_stripe_charge(purchase, object) do
      {:ok, :processed}
    else
      {:error, :purchase_not_found} -> {:ok, :ignored}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_stripe_event(%{
         "type" => "checkout.session.expired",
         "data" => %{"object" => object}
       })
       when is_map(object) do
    with {:ok, purchase} <- purchase_from_provider_object(object) do
      _ =
        purchase
        |> Purchase.changeset(%{
          status: "cancelled",
          raw_provider_payload:
            merge_payload(purchase.raw_provider_payload, %{
              "stripe_session" => object
            })
        })
        |> Repo.update()

      {:ok, :processed}
    end
  end

  defp process_stripe_event(%{"type" => type, "data" => %{"object" => object}})
       when type in [
              "charge.refunded",
              "refund.created",
              "refund.updated",
              "charge.refund.updated",
              "charge.dispute.created",
              "charge.dispute.funds_withdrawn"
            ] and is_map(object) do
    with {:ok, purchase} <- purchase_from_provider_object(object),
         {:ok, _purchase} <-
           revoke_purchase(purchase, %{
             "status" => stripe_reversal_status(type),
             "reason" => type,
             "payload" => %{"stripe_event_object" => object}
           }) do
      {:ok, :processed}
    else
      {:error, :purchase_not_found} -> {:ok, :ignored}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_stripe_event(%{
         "type" => "customer.subscription.updated",
         "data" => %{"object" => object}
       })
       when is_map(object) do
    with {:ok, purchase} <- purchase_from_provider_object(object),
         {:ok, updated} <-
           update_purchase_from_stripe_subscription(purchase, object, "subscription_updated"),
         {:ok, _entitlements} <- update_entitlements_from_stripe_subscription(updated, object) do
      {:ok, :processed}
    else
      {:error, :purchase_not_found} -> {:ok, :ignored}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_stripe_event(%{
         "type" => "customer.subscription.deleted",
         "data" => %{"object" => object}
       })
       when is_map(object) do
    with {:ok, purchase} <- purchase_from_provider_object(object),
         {:ok, updated} <-
           update_purchase_from_stripe_subscription(purchase, object, "subscription_deleted"),
         {:ok, _purchase} <-
           revoke_purchase(updated, %{
             "status" => "cancelled",
             "reason" => "customer.subscription.deleted",
             "payload" => %{"stripe_subscription" => object}
           }) do
      {:ok, :processed}
    else
      {:error, :purchase_not_found} -> {:ok, :ignored}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_stripe_event(_event), do: {:ok, :ignored}

  defp process_google_event(%{"testNotification" => _notification}), do: {:ok, :processed}

  defp process_google_event(%{"voidedPurchaseNotification" => notification})
       when is_map(notification) do
    purchase =
      find_provider_purchase(
        "google",
        notification["orderId"],
        notification["purchaseToken"]
      )

    case purchase do
      %Purchase{} ->
        revoke_purchase(purchase, %{
          "status" => "refunded",
          "reason" => "google_voided_purchase",
          "payload" => %{"google_notification" => notification}
        })
        |> processed_result()

      nil ->
        {:ok, :ignored}
    end
  end

  defp process_google_event(%{"oneTimeProductNotification" => notification})
       when is_map(notification) do
    purchase = find_provider_purchase("google", nil, notification["purchaseToken"])

    case {notification["notificationType"], purchase} do
      {2, %Purchase{} = purchase} ->
        revoke_purchase(purchase, %{
          "status" => "cancelled",
          "reason" => "google_one_time_product_cancelled",
          "payload" => %{"google_notification" => notification}
        })
        |> processed_result()

      {_type, %Purchase{} = purchase} ->
        fulfill_purchase(purchase, %{"google_notification" => notification})
        |> processed_result()

      _ ->
        {:ok, :ignored}
    end
  end

  defp process_google_event(%{"subscriptionNotification" => notification})
       when is_map(notification) do
    purchase = find_provider_purchase("google", nil, notification["purchaseToken"])

    case {notification["notificationType"], purchase} do
      {type, %Purchase{} = purchase} when type in [12, 13, 20] ->
        revoke_purchase(purchase, %{
          "status" => google_subscription_reversal_status(type),
          "reason" => "google_subscription_notification_#{type}",
          "payload" => %{"google_notification" => notification}
        })
        |> processed_result()

      {_type, %Purchase{} = purchase} ->
        fulfill_purchase(purchase, %{"google_notification" => notification})
        |> processed_result()

      _ ->
        {:ok, :ignored}
    end
  end

  defp process_google_event(_event), do: {:ok, :ignored}

  defp process_apple_event(event) do
    transaction = event["decoded_transaction_info"] || %{}
    type = event["notificationType"]

    purchase =
      find_provider_purchase(
        "apple",
        transaction["transactionId"],
        transaction["originalTransactionId"]
      )

    cond do
      is_nil(purchase) ->
        {:ok, :ignored}

      type in @apple_reversal_notifications or not is_nil(transaction["revocationDate"]) ->
        revoke_purchase(purchase, %{
          "status" => "revoked",
          "reason" => "apple_#{type}",
          "payload" => %{"apple_notification" => event}
        })
        |> processed_result()

      type in @apple_activation_notifications ->
        with {:ok, updated} <-
               update_purchase_from_validation(
                 purchase,
                 apple_validation_from_transaction(transaction)
               ),
             {:ok, _purchase} <- fulfill_purchase(updated, %{"apple_notification" => event}) do
          {:ok, :processed}
        end

      true ->
        {:ok, :ignored}
    end
  end

  defp processed_result({:ok, _purchase}), do: {:ok, :processed}
  defp processed_result({:error, reason}), do: {:error, reason}

  defp google_subscription_reversal_status(20), do: "cancelled"
  defp google_subscription_reversal_status(_type), do: "revoked"

  defp apple_validation_from_transaction(transaction) do
    %{
      "transaction_id" => transaction["transactionId"],
      "original_transaction_id" => transaction["originalTransactionId"],
      "status" => "completed",
      "quantity" => transaction["quantity"] || 1,
      "environment" => apple_event_environment(transaction["environment"]),
      "expires_at" => millis_to_iso8601(transaction["expiresDate"]),
      "raw_payload" => %{"apple_transaction" => transaction}
    }
  end

  defp apple_event_environment("Sandbox"), do: "sandbox"
  defp apple_event_environment("Production"), do: "production"
  defp apple_event_environment("Xcode"), do: "test"
  defp apple_event_environment(_environment), do: default_environment()

  defp purchase_from_provider_object(object) do
    metadata = object["metadata"] || %{}

    cond do
      is_binary(metadata["purchase_id"]) ->
        purchase_by_id_result(metadata["purchase_id"])

      is_binary(metadata["order_id"]) ->
        case get_purchase_by_order_id(metadata["order_id"]) do
          %Purchase{} = purchase -> {:ok, purchase}
          nil -> {:error, :purchase_not_found}
        end

      is_binary(object["charge"]) ->
        purchase_from_original_transaction(object["charge"])

      is_binary(object["charge_id"]) ->
        purchase_from_original_transaction(object["charge_id"])

      is_binary(object["id"]) ->
        case get_purchase_by_provider_transaction("stripe", object["id"]) do
          %Purchase{} = purchase ->
            {:ok, purchase}

          nil ->
            object["id"]
            |> purchase_from_original_transaction()
        end

      true ->
        {:error, :purchase_not_found}
    end
  end

  defp purchase_by_id_result(id) do
    case get_purchase(id) do
      %Purchase{} = purchase -> {:ok, purchase}
      nil -> {:error, :purchase_not_found}
    end
  end

  defp get_user_subscription_entitlement(%User{} = user, entitlement_id) do
    Entitlement
    |> Repo.get(entitlement_id)
    |> Repo.preload([:product, source_purchase: [:product, :provider_product]])
    |> case do
      %Entitlement{
        user_id: user_id,
        product: %Product{kind: "subscription"},
        source_purchase: %Purchase{provider: "stripe"}
      } = entitlement
      when user_id == user.id ->
        {:ok, entitlement}

      %Entitlement{user_id: user_id, product: %Product{kind: "subscription"}}
      when user_id == user.id ->
        {:error, :not_stripe_subscription}

      %Entitlement{user_id: user_id} when user_id == user.id ->
        {:error, :not_subscription_entitlement}

      _ ->
        {:error, :entitlement_not_found}
    end
  end

  defp ensure_stripe_session_matches_purchase(%Purchase{} = purchase, session) do
    metadata = session["metadata"] || %{}

    cond do
      stripe_metadata_purchase_mismatch?(metadata["purchase_id"], purchase.id) ->
        {:error, :stripe_session_purchase_mismatch}

      is_binary(metadata["order_id"]) and metadata["order_id"] != purchase.order_id ->
        {:error, :stripe_session_order_mismatch}

      true ->
        :ok
    end
  end

  defp stripe_metadata_purchase_mismatch?(nil, _purchase_id), do: false
  defp stripe_metadata_purchase_mismatch?("", _purchase_id), do: false
  defp stripe_metadata_purchase_mismatch?(purchase_id, purchase_id), do: false

  defp stripe_metadata_purchase_mismatch?(purchase_id, _expected_id)
       when is_binary(purchase_id),
       do: true

  defp stripe_metadata_purchase_mismatch?(_purchase_id, _expected_id), do: true

  defp reconcile_stripe_purchase_from_session(%Purchase{status: "completed"} = purchase, session) do
    if stripe_session_paid?(session) do
      with {:ok, updated} <- update_purchase_from_stripe_session(purchase, session),
           {:ok, _entitlements} <- maybe_update_entitlements_from_stripe_purchase(updated) do
        {:ok, preload_purchase(updated), :already_completed}
      end
    else
      {:ok, preload_purchase(purchase), :already_completed}
    end
  end

  defp reconcile_stripe_purchase_from_session(%Purchase{status: status} = purchase, _session)
       when status in ["refunded", "revoked"] do
    {:ok, preload_purchase(purchase), :unchanged}
  end

  defp reconcile_stripe_purchase_from_session(%Purchase{} = purchase, session) do
    cond do
      stripe_session_paid?(session) ->
        with {:ok, updated} <- update_purchase_from_stripe_session(purchase, session),
             {:ok, fulfilled} <-
               fulfill_purchase(updated, stripe_reconciliation_payload(session, "fulfilled")) do
          {:ok, fulfilled, :fulfilled}
        end

      session["status"] == "expired" ->
        update_purchase_from_stripe_reconciliation(purchase, session, "cancelled", :cancelled)

      stripe_payment_failed?(session) ->
        update_purchase_from_stripe_reconciliation(purchase, session, "failed", :failed)

      session["status"] == "open" ->
        update_purchase_from_stripe_reconciliation(
          purchase,
          session,
          "requires_action",
          :still_open
        )

      true ->
        update_purchase_from_stripe_reconciliation(
          purchase,
          session,
          "requires_action",
          :payment_processing
        )
    end
  end

  defp stripe_session_paid?(%{"payment_status" => status})
       when status in ["paid", "no_payment_required"],
       do: true

  defp stripe_session_paid?(_session), do: false

  defp stripe_payment_failed?(session) do
    session["status"] == "complete" and
      stripe_payment_intent_status(session) in ["canceled", "requires_payment_method"]
  end

  defp stripe_payment_intent_status(%{"payment_intent" => %{"status" => status}}), do: status
  defp stripe_payment_intent_status(_session), do: nil

  defp update_purchase_from_stripe_reconciliation(%Purchase{} = purchase, session, status, result) do
    purchase
    |> Purchase.changeset(%{
      status: status,
      raw_provider_payload:
        merge_payload(
          purchase.raw_provider_payload,
          stripe_reconciliation_payload(session, result)
        )
    })
    |> Repo.update()
    |> case do
      {:ok, updated} -> {:ok, preload_purchase(updated), result}
      {:error, reason} -> {:error, reason}
    end
  end

  defp stripe_reconciliation_payload(session, result) do
    %{
      "stripe_session" => session,
      "stripe_reconciliation" => %{
        "result" => to_string(result),
        "reconciled_at" => DateTime.utc_now(:second) |> DateTime.to_iso8601()
      }
    }
  end

  defp update_purchase_from_stripe_session(%Purchase{} = purchase, object) do
    subscription = stripe_session_subscription(purchase, object)
    amount = object["amount_total"] || purchase.amount
    currency = object["currency"] |> normalize_currency() || purchase.currency

    metadata =
      purchase
      |> stripe_purchase_metadata(object)
      |> stripe_subscription_metadata(subscription)

    purchase
    |> Purchase.changeset(%{
      provider_transaction_id: object["id"] || purchase.provider_transaction_id,
      amount: amount,
      currency: currency,
      expires_at: stripe_subscription_period_end(subscription) || purchase.expires_at,
      metadata: metadata,
      raw_provider_payload:
        stripe_payload_with_subscription(
          purchase.raw_provider_payload,
          %{"stripe_session" => object},
          subscription
        )
    })
    |> Repo.update()
  end

  defp update_purchase_from_stripe_subscription(
         %Purchase{} = purchase,
         subscription,
         reconciliation_result
       )
       when is_map(subscription) do
    metadata =
      purchase
      |> stripe_purchase_metadata(%{})
      |> stripe_subscription_metadata(subscription)

    purchase
    |> Purchase.changeset(%{
      expires_at: stripe_subscription_period_end(subscription) || purchase.expires_at,
      metadata: metadata,
      raw_provider_payload:
        merge_payload(purchase.raw_provider_payload, %{
          "stripe_subscription" => subscription,
          "stripe_subscription_reconciliation" => %{
            "result" => reconciliation_result,
            "reconciled_at" => DateTime.utc_now(:second) |> DateTime.to_iso8601()
          }
        })
    })
    |> Repo.update()
    |> case do
      {:ok, updated} -> {:ok, preload_purchase(updated)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp update_entitlements_from_stripe_subscription(%Purchase{} = purchase, subscription)
       when is_map(subscription) do
    metadata = stripe_entitlement_subscription_metadata(subscription)
    expires_at = stripe_subscription_period_end(subscription)

    from(e in Entitlement, where: e.source_purchase_id == ^purchase.id)
    |> Repo.all()
    |> Enum.reduce_while({:ok, []}, fn entitlement, {:ok, updated_entitlements} ->
      attrs = %{
        metadata: merge_payload(entitlement.metadata || %{}, metadata)
      }

      attrs =
        if expires_at do
          Map.put(attrs, :expires_at, expires_at)
        else
          attrs
        end

      case entitlement |> Entitlement.changeset(attrs) |> Repo.update() do
        {:ok, updated} ->
          after_entitlement_changed(updated)

          {:cont,
           {:ok, [Repo.preload(updated, [:product, :source_purchase]) | updated_entitlements]}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, entitlements} -> {:ok, Enum.reverse(entitlements)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_update_entitlements_from_stripe_purchase(%Purchase{} = purchase) do
    case subscription_object_id((purchase.raw_provider_payload || %{})["stripe_subscription"]) do
      nil ->
        {:ok, []}

      _subscription_id ->
        update_entitlements_from_stripe_subscription(
          purchase,
          purchase.raw_provider_payload["stripe_subscription"]
        )
    end
  end

  defp update_purchase_from_stripe_charge(%Purchase{} = purchase, object) do
    metadata = stripe_purchase_metadata(purchase, object)

    purchase
    |> Purchase.changeset(%{
      provider_original_transaction_id: object["id"] || purchase.provider_original_transaction_id,
      metadata: metadata,
      raw_provider_payload:
        merge_payload(purchase.raw_provider_payload, %{
          "stripe_charge" => object
        })
    })
    |> Repo.update()
  end

  defp stripe_reversal_status(type)
       when type in [
              "charge.refunded",
              "refund.created",
              "refund.updated",
              "charge.refund.updated"
            ],
       do: "refunded"

  defp stripe_reversal_status(_type), do: "revoked"

  defp purchase_from_original_transaction(nil), do: {:error, :purchase_not_found}

  defp purchase_from_original_transaction(transaction_id) when is_binary(transaction_id) do
    case get_purchase_by_provider_original_transaction("stripe", transaction_id) do
      %Purchase{} = purchase -> {:ok, purchase}
      nil -> {:error, :purchase_not_found}
    end
  end

  defp stripe_purchase_metadata(%Purchase{} = purchase, object) do
    metadata = purchase.metadata || %{}

    metadata
    |> put_if_present("stripe_session_id", object["id"], object["object"] == "checkout.session")
    |> put_if_present("stripe_payment_intent_id", object["payment_intent"], true)
    |> put_if_present("stripe_charge_id", object["id"], object["object"] == "charge")
    |> put_if_present("stripe_subscription_id", stripe_session_subscription_id(object), true)
  end

  defp stripe_subscription_metadata(metadata, nil), do: metadata

  defp stripe_subscription_metadata(metadata, subscription) when is_map(subscription) do
    metadata
    |> put_if_present("stripe_subscription_id", subscription["id"], true)
    |> put_if_present("stripe_subscription_status", subscription["status"], true)
    |> put_if_present(
      "stripe_subscription_current_period_end",
      datetime_iso(stripe_subscription_period_end(subscription)),
      true
    )
    |> Map.put(
      "stripe_subscription_cancel_at_period_end",
      subscription["cancel_at_period_end"] == true
    )
  end

  defp stripe_entitlement_subscription_metadata(subscription) when is_map(subscription) do
    %{
      "stripe_subscription_id" => subscription["id"],
      "stripe_subscription_status" => subscription["status"],
      "stripe_subscription_cancel_at_period_end" => subscription["cancel_at_period_end"] == true,
      "stripe_subscription_current_period_end" =>
        datetime_iso(stripe_subscription_period_end(subscription))
    }
  end

  defp stripe_session_subscription(%Purchase{product: %Product{kind: "subscription"}}, object) do
    case object["subscription"] do
      %{} = subscription ->
        subscription

      subscription_id when is_binary(subscription_id) and subscription_id != "" ->
        case stripe_adapter().retrieve_subscription(subscription_id) do
          {:ok, subscription} ->
            normalize_params(subscription)

          {:error, reason} ->
            Logger.warning(
              "Stripe subscription retrieve failed subscription_id=#{subscription_id} reason=#{inspect(reason)}"
            )

            %{"id" => subscription_id}
        end

      _ ->
        nil
    end
  end

  defp stripe_session_subscription(_purchase, _object), do: nil

  defp stripe_session_subscription_id(%{"subscription" => %{"id" => id}}) when is_binary(id),
    do: id

  defp stripe_session_subscription_id(%{"subscription" => id}) when is_binary(id), do: id
  defp stripe_session_subscription_id(_object), do: nil

  defp stripe_subscription_id(%Purchase{} = purchase) do
    metadata = purchase.metadata || %{}
    payload = purchase.raw_provider_payload || %{}

    candidates = [
      metadata["stripe_subscription_id"],
      stripe_session_subscription_id(payload["stripe_session"] || %{}),
      subscription_object_id(payload["stripe_subscription"]),
      purchase.provider_original_transaction_id
    ]

    case Enum.find(candidates, &stripe_subscription_id?/1) do
      nil -> {:error, :missing_stripe_subscription_id}
      subscription_id -> {:ok, subscription_id}
    end
  end

  defp subscription_object_id(%{"id" => id}) when is_binary(id), do: id
  defp subscription_object_id(_subscription), do: nil

  defp stripe_subscription_id?("sub_" <> _rest), do: true
  defp stripe_subscription_id?(_value), do: false

  defp stripe_payload_with_subscription(existing, incoming, nil),
    do: merge_payload(existing, incoming)

  defp stripe_payload_with_subscription(existing, incoming, subscription)
       when is_map(subscription) do
    merge_payload(existing, Map.put(incoming, "stripe_subscription", subscription))
  end

  defp stripe_subscription_period_end(nil), do: nil

  defp stripe_subscription_period_end(subscription) when is_map(subscription) do
    top_level_period_end =
      unix_seconds_to_datetime(subscription["current_period_end"]) ||
        unix_seconds_to_datetime(subscription["cancel_at"])

    top_level_period_end || stripe_subscription_item_period_end(subscription)
  end

  defp stripe_subscription_item_period_end(%{"items" => %{"data" => items}})
       when is_list(items) do
    items
    |> Enum.map(&unix_seconds_to_datetime(&1["current_period_end"]))
    |> Enum.reject(&is_nil/1)
    |> Enum.max_by(&DateTime.to_unix/1, fn -> nil end)
  end

  defp stripe_subscription_item_period_end(_subscription), do: nil

  defp unix_seconds_to_datetime(value) when is_integer(value) do
    case DateTime.from_unix(value, :second) do
      {:ok, datetime} -> DateTime.truncate(datetime, :second)
      {:error, _reason} -> nil
    end
  end

  defp unix_seconds_to_datetime(value) when is_binary(value) do
    value
    |> parse_int()
    |> unix_seconds_to_datetime()
  end

  defp unix_seconds_to_datetime(_value), do: nil

  defp datetime_iso(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp datetime_iso(_value), do: nil

  defp put_if_present(metadata, key, value, true) when is_binary(value) and value != "" do
    Map.put(metadata, key, value)
  end

  defp put_if_present(metadata, _key, _value, _condition), do: metadata

  defp find_provider_purchase(provider, transaction_id, original_transaction_id) do
    [
      fn ->
        if is_binary(transaction_id) and transaction_id != "" do
          get_purchase_by_provider_transaction(provider, transaction_id)
        end
      end,
      fn ->
        if is_binary(original_transaction_id) and original_transaction_id != "" do
          get_purchase_by_provider_original_transaction(provider, original_transaction_id)
        end
      end
    ]
    |> Enum.reduce_while(nil, fn finder, _acc ->
      case finder.() do
        %Purchase{} = purchase -> {:halt, purchase}
        _ -> {:cont, nil}
      end
    end)
  end

  defp google_event_type(%{"voidedPurchaseNotification" => notification})
       when is_map(notification) do
    "voided_purchase:#{notification["refundType"] || "unknown"}"
  end

  defp google_event_type(%{"oneTimeProductNotification" => notification})
       when is_map(notification) do
    "one_time_product:#{notification["notificationType"] || "unknown"}"
  end

  defp google_event_type(%{"subscriptionNotification" => notification})
       when is_map(notification) do
    "subscription:#{notification["notificationType"] || "unknown"}"
  end

  defp google_event_type(%{"testNotification" => _notification}), do: "test"
  defp google_event_type(_event), do: "unknown"

  defp provider_event_hash(provider, raw_body) do
    digest = :crypto.hash(:sha256, raw_body) |> Base.encode16(case: :lower)
    "#{provider}_#{digest}"
  end

  defp steam_response_params(%{"response" => %{"params" => params}}) when is_map(params),
    do: params

  defp steam_response_params(%{"response" => params}) when is_map(params), do: params
  defp steam_response_params(params) when is_map(params), do: params

  defp revoke_entitlements_for_purchase(%Purchase{} = purchase, now, reason) do
    query = from(e in Entitlement, where: e.source_purchase_id == ^purchase.id)

    query
    |> Repo.update_all(
      set: [
        status: "revoked",
        revoked_at: now,
        updated_at: now,
        metadata: %{"revocation_reason" => reason || "purchase_revoked"}
      ]
    )

    Repo.all(query)
  end

  defp after_purchase_fulfilled(%Purchase{} = purchase) do
    Phoenix.PubSub.broadcast(@pubsub, "user:#{purchase.user_id}", {:purchase_updated, purchase})

    GameServer.Async.run(fn ->
      GameServer.Hooks.internal_call(:after_purchase_fulfilled, [purchase])
    end)
  end

  defp after_purchase_revoked(%Purchase{} = purchase) do
    Phoenix.PubSub.broadcast(@pubsub, "user:#{purchase.user_id}", {:purchase_updated, purchase})

    GameServer.Async.run(fn ->
      GameServer.Hooks.internal_call(:after_purchase_revoked, [purchase])
    end)
  end

  defp after_entitlement_changed(%Entitlement{} = entitlement) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      "user:#{entitlement.user_id}",
      {:entitlement_changed, entitlement}
    )

    GameServer.Async.run(fn ->
      GameServer.Hooks.internal_call(:after_entitlement_changed, [entitlement])
    end)
  end

  defp provider_adapter(provider) do
    adapters =
      Application.get_env(:game_server_core, :payment_provider_adapters, [])

    key =
      case provider do
        "apple" -> :apple
        "google" -> :google
        "steam" -> :steam
      end

    Keyword.get(adapters, key, default_provider_adapter(provider))
  end

  defp stripe_adapter do
    Application.get_env(
      :game_server_core,
      :stripe_adapter,
      GameServer.Payments.Providers.Stripe
    )
  end

  defp default_provider_adapter("apple"), do: GameServer.Payments.Providers.Apple
  defp default_provider_adapter("google"), do: GameServer.Payments.Providers.Google
  defp default_provider_adapter("steam"), do: GameServer.Payments.Providers.Steam

  defp provider_module_status(module) do
    if function_exported?(module, :config_status, 0) do
      module.config_status()
    else
      %{configured: true}
    end
  end

  defp positive_page(opts) do
    opts
    |> Keyword.get(:page, 1)
    |> parse_positive_int(1)
  end

  defp page_size(opts) do
    opts
    |> Keyword.get(:page_size, 50)
    |> parse_positive_int(50)
    |> min(250)
  end

  defp page_offset(page, page_size), do: (page - 1) * page_size

  defp admin_purchase_filters(query, opts) do
    query
    |> maybe_where_string(:provider, Keyword.get(opts, :provider))
    |> maybe_where_string(:status, Keyword.get(opts, :status))
    |> maybe_where_id(:user_id, Keyword.get(opts, :user_id))
    |> maybe_where_like(:order_id, Keyword.get(opts, :order_id))
  end

  defp admin_entitlement_filters(query, opts) do
    query
    |> maybe_where_string(:status, Keyword.get(opts, :status))
    |> maybe_where_id(:user_id, Keyword.get(opts, :user_id))
    |> maybe_where_like(:key, Keyword.get(opts, :key))
  end

  defp provider_event_filters(query, opts) do
    query
    |> maybe_where_string(:provider, Keyword.get(opts, :provider))
    |> maybe_where_like(:event_type, Keyword.get(opts, :event_type))
  end

  defp maybe_where_string(query, _field, value) when value in [nil, ""], do: query

  defp maybe_where_string(query, field, value) when is_binary(value) do
    where(query, [row], field(row, ^field) == ^value)
  end

  defp maybe_where_id(query, _field, value) when value in [nil, ""], do: query

  defp maybe_where_id(query, field, value) do
    case GameServer.UUIDv7.cast_or_nil(value) do
      nil -> query
      uuid -> where(query, [row], field(row, ^field) == ^uuid)
    end
  end

  defp maybe_where_like(query, _field, value) when value in [nil, ""], do: query

  defp maybe_where_like(query, field, value) when is_binary(value) do
    pattern = "%#{Repo.escape_like(value)}%"
    where(query, [row], fragment("? LIKE ? ESCAPE '\\'", field(row, ^field), ^pattern))
  end

  defp present?(value), do: is_binary(value) and value != ""

  defp stripe_key_mode("sk_test_" <> _rest), do: "test"
  defp stripe_key_mode("rk_test_" <> _rest), do: "test"
  defp stripe_key_mode("sk_live_" <> _rest), do: "live"
  defp stripe_key_mode("rk_live_" <> _rest), do: "live"
  defp stripe_key_mode(value) when is_binary(value) and value != "", do: "unknown"
  defp stripe_key_mode(_value), do: "not_configured"

  defp mask_secret(value) when is_binary(value) and value != "" do
    len = byte_size(value)

    if len <= 8 do
      String.duplicate("*", len)
    else
      "#{String.slice(value, 0, 7)}...#{String.slice(value, -4, 4)}"
    end
  end

  defp mask_secret(_value), do: "<unset>"

  defp entitlement_expiry(%Product{kind: "subscription", grant_config: config}) do
    duration = parse_positive_int((config || %{})["duration_seconds"], 0)

    if duration > 0 do
      DateTime.utc_now(:second) |> DateTime.add(duration, :second)
    end
  end

  defp entitlement_expiry(_product), do: nil

  defp total_amount(nil, _quantity), do: nil

  defp total_amount(unit_amount, quantity) when is_integer(unit_amount),
    do: unit_amount * quantity

  defp generate_order_id do
    "ord_" <> Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false)
  end

  defp generate_steam_order_id do
    int = :crypto.strong_rand_bytes(8) |> :binary.decode_unsigned()

    int |> rem(9_000_000_000_000_000_000) |> Kernel.+(1_000_000_000_000_000_000) |> to_string()
  end

  defp default_environment do
    ProviderConfig.environment()
  end

  defp source_label({label, _value}), do: label
  defp source_label(nil), do: nil

  defp merge_payload(existing, incoming) when is_map(existing) and is_map(incoming) do
    Map.merge(existing, incoming)
  end

  defp required_value(map, key) do
    case Map.get(map, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      value when is_integer(value) -> {:ok, to_string(value)}
      _ -> {:error, String.to_atom("missing_#{key}")}
    end
  end

  defp parse_positive_int(value, default) do
    case parse_int(value) do
      int when is_integer(int) and int > 0 -> int
      _ -> default
    end
  end

  defp parse_int(value) when is_integer(value), do: value

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_int(_value), do: nil

  defp parse_datetime(nil), do: nil
  defp parse_datetime(%DateTime{} = dt), do: DateTime.truncate(dt, :second)

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> DateTime.truncate(dt, :second)
      _ -> nil
    end
  end

  defp parse_datetime(_value), do: nil

  defp millis_to_iso8601(nil), do: nil

  defp millis_to_iso8601(value) do
    with int when is_integer(int) <- parse_int(value),
         {:ok, dt} <- DateTime.from_unix(int, :millisecond) do
      DateTime.to_iso8601(dt)
    else
      _ -> nil
    end
  end

  defp normalize_currency(nil), do: nil
  defp normalize_currency(currency) when is_binary(currency), do: String.upcase(currency)

  defp normalize_params(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end
end
