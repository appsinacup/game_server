#!/usr/bin/env bash
# Regenerates the Godot protobuf bindings from proto/gamend_realtime.proto.
#
# Requires:
#   GODOT_BIN    - path to a Godot 4 binary (headless-capable)
#   GODOBUF_DIR  - checkout of https://github.com/oniksan/godobuf
#
# Output goes to the canonical addon source (clients/gamend_template) and the
# local godot_addons copy used for development.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:?set GODOT_BIN to a Godot 4 binary}"
GODOBUF_DIR="${GODOBUF_DIR:?set GODOBUF_DIR to a godobuf checkout}"

PROTO="$ROOT_DIR/proto/gamend_realtime.proto"
OUT_TEMPLATE="$ROOT_DIR/clients/gamend_template/proto/gamend_realtime_pb.gd"
OUT_ADDONS="$ROOT_DIR/godot_addons/addons/gamend/proto/gamend_realtime_pb.gd"

mkdir -p "$(dirname "$OUT_TEMPLATE")" "$(dirname "$OUT_ADDONS")"

(cd "$GODOBUF_DIR" && "$GODOT_BIN" --headless -s addons/godobuf/godobuf_cmdln.gd \
  --input="$PROTO" --output="$OUT_TEMPLATE")

# godobuf generates broken proto3-optional presence checks; see the script.
python3 "$ROOT_DIR/clients/fix_godobuf_presence.py" "$OUT_TEMPLATE"

cp "$OUT_TEMPLATE" "$OUT_ADDONS"
echo "Godot protobuf bindings regenerated."
