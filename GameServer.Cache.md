# `GameServer.Cache`

Application cache backed by Nebulex.

This cache uses a 2-level (near-cache) topology via
`Nebulex.Adapters.Multilevel`:

- L1: local in-memory cache (`GameServer.Cache.L1`)
- L2: either Redis (`GameServer.Cache.L2.Redis`) or a partitioned topology
  (`GameServer.Cache.L2.Partitioned`), selected via runtime config.

# `count_all`

# `count_all`

# `count_all!`

# `count_all!`

# `decr`

# `decr`

# `decr!`

# `decr!`

# `delete`

# `delete`

# `delete!`

# `delete!`

# `delete_all`

# `delete_all`

# `delete_all!`

# `delete_all!`

# `expire`

# `expire`

# `expire!`

# `expire!`

# `fetch`

# `fetch`

# `fetch!`

# `fetch!`

# `fetch_or_store`

# `fetch_or_store`

# `fetch_or_store!`

# `fetch_or_store!`

# `get`

# `get`

# `get!`

# `get!`

# `get_all`

# `get_all`

# `get_all!`

# `get_all!`

# `get_and_update`

# `get_and_update`

# `get_and_update!`

# `get_and_update!`

# `get_or_store`

# `get_or_store`

# `get_or_store!`

# `get_or_store!`

# `has_key?`

# `has_key?`

# `in_transaction?`

# `in_transaction?`

# `inclusion_policy`

A convenience function to get the cache inclusion policy.

# `incr`

# `incr`

# `incr!`

# `incr!`

# `info`

# `info`

# `info!`

# `info!`

# `put`

# `put`

# `put!`

# `put!`

# `put_all`

# `put_all`

# `put_all!`

# `put_all!`

# `put_new`

# `put_new`

# `put_new!`

# `put_new!`

# `put_new_all`

# `put_new_all`

# `put_new_all!`

# `put_new_all!`

# `register_event_listener`

# `register_event_listener`

# `register_event_listener!`

# `register_event_listener!`

# `replace`

# `replace`

# `replace!`

# `replace!`

# `stream`

# `stream`

# `stream!`

# `stream!`

# `take`

# `take`

# `take!`

# `take!`

# `touch`

# `touch`

# `touch!`

# `touch!`

# `transaction`

# `transaction`

# `ttl`

# `ttl`

# `ttl!`

# `ttl!`

# `unregister_event_listener`

# `unregister_event_listener`

# `unregister_event_listener!`

# `unregister_event_listener!`

# `update`

# `update`

# `update!`

# `update!`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
