# Pinned certificates

## apple_root_ca_g3.pem

Apple Root CA - G3, the trust anchor for App Store Server JWS payloads
(StoreKit signed transactions and App Store Server Notifications V2).
`GameServer.Payments.Providers.Apple.JWS` validates each payload's `x5c`
certificate chain up to this root before trusting the leaf signing key.

- Source: https://www.apple.com/certificateauthority/AppleRootCA-G3.cer
- SHA-256 fingerprint:
  `63:34:3A:BF:B8:9A:6A:03:EB:B5:7E:9B:3F:5F:A7:BE:7C:4F:5C:75:6F:30:17:B3:A8:C4:88:C3:65:3E:91:79`

To refresh (DER → PEM):

    curl -sS https://www.apple.com/certificateauthority/AppleRootCA-G3.cer -o root.cer
    openssl x509 -inform DER -in root.cer -outform PEM -out apple_root_ca_g3.pem
    openssl x509 -in apple_root_ca_g3.pem -noout -fingerprint -sha256   # verify it matches above

If this file is missing, Apple purchase/notification verification fails closed.
