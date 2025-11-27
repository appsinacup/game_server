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

echo "Post-processing generated files: replacing 'Underscore' -> '_'"

# Fix generator errors. Replace Underscore with _
find "$OUT_DIR" -type f -iname "*.gd" -print0 | xargs -0 -r perl -0777 -pe "s/Underscore/_/g" -i

# Replace #self._bzz_client.close() with self._bzz_client.close()
find "$OUT_DIR" -type f -iname "*.gd" -print0 | xargs -0 -r perl -0777 -pe "s/#self\._bzz_client\.close\(\)/self._bzz_client.close()/g" -i

# Replace : Object with : Dictionary
find "$OUT_DIR" -type f -iname "*.gd" -print0 | xargs -0 -r perl -0777 -pe "s/: Object/: Dictionary/g" -i

# Other fixes
# Replace login_200_response_data with Login200ResponseData
find "$OUT_DIR" -type f -iname "*.gd" -print0 | xargs -0 -r perl -0777 -pe "s/login_200_response_data/Login200ResponseData/g" -i
# Replace login_200_response_data_user with Login200ResponseDataUser
find "$OUT_DIR" -type f -iname "*.gd" -print0 | xargs -0 -r perl -0777 -pe "s/login_200_response_data_user/Login200ResponseDataUser/g" -i
# Replace OAuthSessionData_details with OAuthSessionDataDetails
find "$OUT_DIR" -type f -iname "*.gd" -print0 | xargs -0 -r perl -0777 -pe "s/OAuthSessionData_details/OAuthSessionDataDetails/g" -i



echo "Post-processing complete."

# If APP_VERSION is set (CI), stamp it into the gamend_template so the
# generated Godot addon contains explicit version metadata that consumers can
# read at runtime.
if [ -n "${APP_VERSION:-}" ]; then
  echo "Adding version metadata to gamend_template: ${APP_VERSION}"
  TEMPLATE_VERSION_FILE="$ROOT_DIR/clients/gamend_template/GamendVersion.gd"
  cat > "$TEMPLATE_VERSION_FILE" <<EOF
# Auto-generated version information. Do not edit -- CI will overwrite.
const GAMEND_VERSION = "${APP_VERSION}"
EOF
fi

# Copy the main client pieces (apis, core, model) to a separate godot_api folder
# This keeps the API surface separated for distribution or packaging.
DEST_API_DIR="$ROOT_DIR/clients/gamend"
mkdir -p "$DEST_API_DIR"

for sub in apis core models; do
  SRC="$OUT_DIR/$sub"
  DST="$DEST_API_DIR/$sub"

  if [ -d "$SRC" ]; then
    echo "Copying $sub to $DST"
    rm -rf "$DST"
    mkdir -p "$(dirname "$DST")"
    cp -R "$SRC" "$DST"
  else
    echo "Skip copying $sub - not present in $OUT_DIR"
  fi
done

# Copy gamend_template to gamend if present (rename template folder to final folder)
SRC_TMPL="$OUT_DIR/../gamend_template"
DST_GAMEND="$DEST_API_DIR"

cp -R "$SRC_TMPL/." "$DST_GAMEND"

ROOT_ADDONS="$ROOT_DIR/godot_addons"

mkdir -p "$ROOT_ADDONS/addons"

mv "$DST_GAMEND" "$ROOT_ADDONS/addons" 2>/dev/null || true

echo "gamend_template -> gamend copy complete."
