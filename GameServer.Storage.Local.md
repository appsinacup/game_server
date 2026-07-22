# `GameServer.Storage.Local`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/storage/local.ex#L1)

Disk-backed storage — the default backend.

Files live under `STORAGE_LOCAL_DIR` (default `priv/storage`). Readable URLs
and upload tickets point at the app itself. The upload endpoint is protected
by the caller's own auth plus a namespace check (a client may only write keys
under its own id), so the client flow matches S3 without a separate signed
token — an S3 presigned `PUT` simply ignores the extra auth header.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
