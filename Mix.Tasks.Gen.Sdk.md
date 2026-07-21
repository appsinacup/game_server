# `mix gen.sdk`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/mix/tasks/gen.sdk.ex#L1)

Generates SDK stub modules from the real GameServer modules.

This task reads the real implementations and generates stub modules
for the SDK package with matching type specs and documentation.

## Usage

    mix gen.sdk

The generated files are placed in `sdk/lib/game_server/`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
