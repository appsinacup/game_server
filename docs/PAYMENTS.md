# Payments

GameServer keeps a server-side payment ledger. Clients can start purchases with a store SDK or Stripe Checkout, but rewards are granted only after the server validates the provider payload or receives a signed webhook.

## Stripe Modes

Stripe supports test/sandbox mode and live mode. Mode is selected by the API key:

- `sk_test_...` or `rk_test_...`: test/sandbox mode
- `sk_live_...` or `rk_live_...`: live mode

Configure:

```bash
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
PAYMENTS_ENVIRONMENT=test
```

Use live keys only when ready to process real payments:

```bash
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
PAYMENTS_ENVIRONMENT=production
```

References:

- Stripe API keys: https://docs.stripe.com/keys
- Stripe authentication and key prefixes: https://docs.stripe.com/api/authentication
- Stripe webhooks: https://docs.stripe.com/webhooks

## Stripe Checkout Setup

1. Create products/prices in Stripe Dashboard.
2. In `/admin/payments`, create an internal product.
3. Create a provider SKU with:
   - provider: `stripe`
   - external ID: Stripe Price ID, for example `price_...`
   - currency and unit amount in minor units
4. Client calls `POST /api/v1/payments/checkout/stripe` with `product_sku` or `provider_product_id`.
5. Server creates Stripe Checkout Session and stores a pending purchase.
6. Stripe calls `POST /api/v1/payments/webhooks/stripe`.
7. Signed webhook completes or revokes the purchase.

Recommended Stripe webhook events:

- `checkout.session.completed`
- `checkout.session.async_payment_succeeded`
- `checkout.session.expired`
- `charge.succeeded`
- `charge.refunded`
- `refund.created`
- `refund.updated`
- `charge.refund.updated`
- `charge.dispute.created`
- `charge.dispute.funds_withdrawn`

## Refunds And Disputes

Refund or dispute events revoke the purchase server-side. Currency grants remain in the append-only wallet ledger for audit history. Entitlements created by that purchase are marked `revoked`.

Hooks:

- `after_purchase_fulfilled/1`
- `after_purchase_revoked/1`
- `after_entitlement_changed/1`

## Play Store

Google Play support is built in through Android Publisher API. Configure:

```bash
GOOGLE_PLAY_PACKAGE_NAME=com.example.game
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_PATH=/run/secrets/google-play-service-account.json
PAYMENTS_ENVIRONMENT=test
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
APPLE_ENVIRONMENT=sandbox
PAYMENTS_ENVIRONMENT=test
```

Alternative key form:

```bash
APPLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
```

Setup:

1. Create an App Store Server API key in App Store Connect.
2. Set issuer ID, key ID, bundle ID, private key, and `APPLE_ENVIRONMENT`.
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
STEAM_PAYMENTS_ENVIRONMENT=sandbox
PAYMENTS_ENVIRONMENT=test
```

Use `STEAM_PAYMENTS_ENVIRONMENT=production` when ready for real transactions. If `STEAM_WEB_API_KEY` is unset, payments reuse `STEAM_API_KEY` from Steam OpenID config.

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
- Wallet ledger entries
- Provider webhook/event history
- Reconciliation cursors

Use `/admin/config` to view masked environment/config values for Stripe, Google Play, App Store, and Steam payments.
