# Payments

GameServer keeps a server-side payment ledger. Clients can start purchases with a store SDK or Stripe Checkout, but rewards are granted only after the server validates the provider payload or receives a signed webhook.

See [Payment Provider Decision Plan](PAYMENT_PROVIDER_PLAN.md) for the web provider decision, alternatives, and revisit criteria.

## Global Payment Environment

`PAYMENTS_ENVIRONMENT` is the single runtime switch for provider mode:

- `sandbox`: non-real provider flows where supported
- `production`: real provider flows

Clients cannot choose the payment environment. The server chooses credentials and provider endpoints from `PAYMENTS_ENVIRONMENT`, then stores the resolved value on each purchase.

Use separate staging and production deployments first. Keep staging on `PAYMENTS_ENVIRONMENT=sandbox`, and production on `PAYMENTS_ENVIRONMENT=production`. Until provider SKUs get their own environment field, do not mix sandbox and production provider SKU mappings in the same database when product IDs differ.

Legacy `PAYMENTS_ENVIRONMENT=test` is accepted as an alias for `sandbox`; new installs should use `sandbox`.

## Stripe Modes

Stripe supports test mode and live mode. The app maps Stripe test mode to `PAYMENTS_ENVIRONMENT=sandbox`; the selected secret key must match that mode:

- `sk_test_...` or `rk_test_...`: sandbox mode
- `sk_live_...` or `rk_live_...`: live mode

Sandbox:

```bash
PAYMENTS_ENVIRONMENT=sandbox
STRIPE_API_VERSION=2022-11-15
STRIPE_SANDBOX_SECRET_KEY=sk_test_...
STRIPE_SANDBOX_WEBHOOK_SECRET=whsec_...
```

Production:

```bash
PAYMENTS_ENVIRONMENT=production
STRIPE_API_VERSION=2022-11-15
STRIPE_PRODUCTION_SECRET_KEY=sk_live_...
STRIPE_PRODUCTION_WEBHOOK_SECRET=whsec_...
```

`STRIPE_API_VERSION` is optional. If omitted, the Stripe SDK uses `2022-11-15`. Create the webhook endpoint with the same API version as `STRIPE_API_VERSION`.

References:

- Stripe API keys: https://docs.stripe.com/keys
- Stripe authentication and key prefixes: https://docs.stripe.com/api/authentication
- Stripe webhooks: https://docs.stripe.com/webhooks

## Stripe Checkout Setup

1. Create products/prices in Stripe Dashboard.
2. In `/admin/payments`, create an internal product.
3. Create a provider SKU with:
   - provider: `stripe`
   - external ID: Stripe Price ID, for example `price_...` (not `prod_...`)
   - currency and unit amount in minor units
4. Create a Stripe webhook endpoint in Dashboard > Developers / Workbench > Webhooks:
   - URL: `https://your-domain.com/api/v1/payments/webhooks/stripe`
   - API version: `2022-11-15`, or the exact value in `STRIPE_API_VERSION`
   - Events: select only the recommended events below
5. Copy the endpoint signing secret (`whsec_...`) into `STRIPE_SANDBOX_WEBHOOK_SECRET` or `STRIPE_PRODUCTION_WEBHOOK_SECRET`.
6. Client calls `POST /api/v1/payments/checkout/stripe` with `product_sku` or `provider_product_id`.
7. Server creates Stripe Checkout Session and stores a pending purchase.
8. Stripe calls `POST /api/v1/payments/webhooks/stripe`.
9. Signed webhook completes or revokes the purchase.

Recommended Stripe webhook events:

- `checkout.session.completed`
- `checkout.session.async_payment_succeeded`
- `checkout.session.async_payment_failed`
- `checkout.session.expired`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `charge.succeeded`
- `charge.refunded`
- `refund.created`
- `refund.updated`
- `charge.refund.updated`
- `charge.dispute.created`
- `charge.dispute.funds_withdrawn`

For products with kind `entitlement` or `subscription`, checkout quantity must be `1`. A user with an active entitlement, or an in-progress checkout for that product, cannot start another Stripe/Steam checkout for it. Products with kind `consumable` can be purchased repeatedly.

The same ownership guard is applied after Apple, Google, and Steam receipt replay checks and before creating a new purchase. If one item is sold through multiple providers, all provider SKUs must map to the same internal product, or those internal products must share the same `grant_config.entitlement_key`. Otherwise the server cannot know those provider SKUs unlock the same thing.

Currency display and charge currency are controlled by Stripe Checkout. For local currency, enable Stripe Adaptive Pricing in the Stripe Dashboard, or create multi-currency Prices with `currency_options` in Stripe. The provider SKU still stores the Stripe Price ID (`price_...`); Stripe decides which supported currency to present during Checkout.

## Stripe Subscriptions

Stripe subscription products create the same server-side entitlement as one-time entitlement products. While the Stripe subscription is active and auto-renewing, the entitlement remains active. The account payments tab shows:

- `Renews <date>` when Stripe has provided `current_period_end`
- `Auto-renews` when the subscription is active but no provider period end has been stored yet
- `Cancels <date>` after the user schedules cancellation at period end

Users can schedule cancellation from `/users/settings?tab=payments` for Stripe subscriptions. The server calls Stripe to set `cancel_at_period_end=true`; it does not revoke the entitlement immediately. The entitlement remains active until Stripe sends the final subscription deletion event, or until the stored `expires_at` passes.

If a subscription row shows `EXPIRES -` or `Auto-renews`, no period end has been stored yet. Configure the Stripe webhook events above, then use Admin > Payments > Reconcile Stripe on the purchase to fetch the Checkout Session/subscription and backfill the period end. As a fallback for non-Stripe or custom adapters, subscription products may set `grant_config.duration_seconds`; provider period data still wins when present.

`refund.failed` is not enabled by default. A failed refund means Stripe did not complete the refund; this app does not automatically regrant access because that requires a business decision about the original revocation. Reconcile or adjust manually if you add that policy.

## Refunds And Disputes

Refund or dispute events revoke the purchase server-side. Entitlements created by that purchase are marked `revoked`. Consumable game rewards should be granted in hooks, so your game economy remains the source of truth.

Hooks:

- `after_purchase_fulfilled/1`
- `after_purchase_revoked/1`
- `after_entitlement_changed/1`

Default payment hooks mirror payment state into user metadata under `payments`. Purchase IDs are tracked in `payments.purchase_ids`, entitlement keys in `payments.entitlements`, and entitlement IDs in `payments.entitlement_ids`. Subscription products use the same entitlement metadata and include `expires_at` in `payments.entitlement_details`.

## User Store, Purchases, And Downloads

Authenticated users can open `/store` to test browser purchases. Stripe products show a Buy button that starts Stripe Checkout. Apple, Google, and Steam products are listed as catalog rows, but their purchase flow still runs through the platform SDK/client API.

Account settings includes one payment tab:

- `/users/settings?tab=payments`: order history, active entitlements, and downloads

Consumables, such as coin packs, stay visible in purchase history. They do not create server-side balances; use `after_purchase_fulfilled/1` to grant coins/items in your own game systems.

Downloadable entitlements use product config:

```json
{
  "entitlement_key": "starter_pack",
  "download": {
    "asset_key": "starter_pack.zip",
    "filename": "starter_pack.zip"
  }
}
```

Files are served from `:game_server_web, :payment_downloads_dir` or `priv/downloads` by default. `asset_key` must be a file name, not a nested path. Only current active entitlement owners can download.

## Play Store

Google Play support is built in through Android Publisher API. Configure:

```bash
PAYMENTS_ENVIRONMENT=sandbox
GOOGLE_PLAY_PACKAGE_NAME=com.example.game
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_PATH=/run/secrets/google-play-service-account.json
```

Alternative secret forms:

```bash
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON={"type":"service_account",...}
GOOGLE_PLAY_ACCESS_TOKEN=ya29...
```

Optional:

```bash
GOOGLE_PLAY_RTDN_TOKEN=shared_push_token
GOOGLE_PLAY_AUTO_ACKNOWLEDGE=true
```

Setup:

1. Enable Google Play Developer API access for the Play Console account.
2. Create a service account with Android Publisher API access.
3. Set `GOOGLE_PLAY_PACKAGE_NAME` and service account JSON/path.
4. In `/admin/payments`, create an internal product and a provider SKU with provider `google` and external ID equal to the Play product ID.
5. Client completes purchase through Play Billing and calls `POST /api/v1/payments/validate/google` with `product_id` and `purchase_token`.
6. For subscriptions, include `purchase_type: "subscription"` or omit `product_id` and send `purchase_token`.
7. Configure Real-time Developer Notifications through Cloud Pub/Sub push to `POST /api/v1/payments/webhooks/google`.

Google RTDN notifications are stored in provider events. Voided purchase notifications mark the purchase `refunded`. Cancelled or expired subscription notifications mark the purchase `cancelled` or `revoked`.

References:

- Google product purchase validation: https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.products/get
- Google subscription purchase validation: https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2/get
- Google RTDN: https://developer.android.com/google/play/billing/rtdn-reference

## App Store

Apple App Store support is built in for StoreKit 2 signed transactions and App Store Server Notifications v2. Configure:

```bash
APPLE_BUNDLE_ID=com.example.game
APPLE_ISSUER_ID=app_store_server_api_issuer_id
APPLE_KEY_ID=app_store_server_api_key_id
APPLE_PRIVATE_KEY_PATH=/run/secrets/AuthKey_ABC123DEFG.p8
PAYMENTS_ENVIRONMENT=sandbox
```

Alternative key form:

```bash
APPLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
```

Setup:

1. Create an App Store Server API key in App Store Connect.
2. Set issuer ID, key ID, bundle ID, private key, and `PAYMENTS_ENVIRONMENT`.
3. In `/admin/payments`, create an internal product and provider SKU with provider `apple` and external ID equal to the App Store product ID.
4. Client completes purchase with StoreKit and calls `POST /api/v1/payments/validate/apple` with `signed_transaction_info`.
5. If client only has a transaction ID, call same endpoint with `transaction_id`; server fetches it from App Store Server API.
6. Configure App Store Server Notifications v2 to `POST /api/v1/payments/webhooks/apple`.

Apple notifications are stored in provider events. Refund, revocation, grace-period expiration, and consumption-request notifications revoke the purchase and its entitlements.

References:

- App Store Server API: https://developer.apple.com/documentation/appstoreserverapi
- Get Transaction Info: https://developer.apple.com/documentation/appstoreserverapi/get-transaction-info
- App Store Server Notifications: https://developer.apple.com/documentation/appstoreservernotifications

## Steam

Steam support is built in through Steamworks MicroTxn. Configure:

```bash
STEAM_WEB_API_KEY=steam_web_api_key
STEAM_APP_ID=480
PAYMENTS_ENVIRONMENT=sandbox
```

Use `PAYMENTS_ENVIRONMENT=production` when ready for real transactions. If `STEAM_WEB_API_KEY` is unset, payments reuse `STEAM_API_KEY` from Steam OpenID config.

Setup:

1. Create Steam inventory or store item IDs that map to internal products.
2. In `/admin/payments`, create an internal product and provider SKU with provider `steam` and external ID equal to the numeric Steam item ID.
3. Client calls `POST /api/v1/payments/checkout/steam` with `provider_product_id` or `product_sku`, plus `steam_id`.
4. Server calls Steam `InitTxn`, stores a `requires_action` purchase, and returns Steam redirect/overlay URL.
5. Client completes payment through Steam.
6. Client calls `POST /api/v1/payments/steam/finalize` with `order_id`; server calls Steam `FinalizeTxn` and grants product.
7. For reconciliation, call adapter `get_report/1` or add a scheduled job around Steam `GetReport`.

References:

- Steam MicroTxn API: https://partner.steamgames.com/doc/webapi/isteammicrotxn

## Custom Store Adapters

Built-in adapters cover Stripe, Google, Apple, and Steam. You can override any store adapter:

```elixir
config :game_server_core, :payment_provider_adapters,
  apple: MyGame.Payments.AppleAdapter,
  google: MyGame.Payments.GoogleAdapter,
  steam: MyGame.Payments.SteamAdapter
```

Custom adapters should expose `validate_purchase(user, attrs)` and return normalized data:

```elixir
{:ok,
 %{
   "product_id" => "provider_sku_or_price",
   "transaction_id" => "unique_provider_transaction_id",
   "status" => "completed",
   "environment" => "production",
   "raw_payload" => attrs
 }}
```

The server rejects cross-user receipt reuse and returns `seen_before: true` for same-user replay.

## Admin Portal

Use `/admin/payments` to view:

- Payment provider status and detected Stripe mode
- Internal products
- Provider SKU mappings
- Purchases
- Entitlements
- Provider webhook/event history
- Reconciliation cursors

Stripe purchases with a Checkout Session ID (`cs_...`) show a Reconcile Stripe action while pending, stuck, or completed. It retrieves the session from Stripe and fulfills paid sessions, cancels expired sessions, leaves open/processing sessions pending, or backfills subscription period metadata on completed subscriptions.

Use `/admin/config` to view masked environment/config values for Stripe, Google Play, App Store, and Steam payments.
