# `GameServer.Storage.S3`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/storage/s3.ex#L1)

S3-compatible storage via ExAws.

Works with AWS S3, Cloudflare R2, Backblaze B2, MinIO, and DigitalOcean Spaces
— set `bucket`, `region`, and (for non-AWS) `endpoint` in config. Uploads use
presigned `PUT` URLs so clients upload straight to the bucket.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
