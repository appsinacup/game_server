#!/usr/bin/env bash
set -euo pipefail

# generate_godot.sh

ROOT_DIR="$(cd "$(dirname "$0")" && pwd -P)/.."
OUT_DIR="$ROOT_DIR/clients/godot"
SPEC_FILE="$ROOT_DIR/clients/godot/openapi.json"

echo "Ensuring output directory exists: $OUT_DIR"
mkdir -p "$OUT_DIR"

echo "Running mix task to write OpenAPI JSON into clients/godot/openapi.json"
pushd "$ROOT_DIR" >/dev/null
mix openapi.spec.json --spec GameServerWeb.ApiSpec --filename clients/godot/openapi.json --pretty=true
popd >/dev/null

if [ ! -f "$SPEC_FILE" ]; then
  echo "error: mix task completed but $SPEC_FILE was not created"
  exit 3
fi

mkdir -p "$OUT_DIR"

# default generator output options
GEN_IMAGE=${GEN_IMAGE:-openapitools/openapi-generator-cli}
GENERATOR=${GENERATOR:-gdscript}
ADDITIONAL_PROPERTIES=${ADDITIONAL_PROPERTIES:-coreNamePrefix=Api,coreNameSuffix=Client,allowUnicodeIdentifiers=false}

echo "Generating GDScript client into $OUT_DIR using Docker image $GEN_IMAGE"

docker run --rm -v "$ROOT_DIR:/local" $GEN_IMAGE generate \
  -i /local/clients/godot/openapi.json \
  -g "$GENERATOR" \
  -o /local/clients/godot \
  --additional-properties="$ADDITIONAL_PROPERTIES"

echo "Generation finished. See $OUT_DIR for generated files."
