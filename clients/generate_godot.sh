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

# Try to make the generator run as the current host user so files written into
# the mounted volume are owned by the same uid/gid — this prevents
# permission problems later when doing in-place edits on the host (CI runners
# often create root-owned files otherwise).
DOCKER_USER_OPT=""
if command -v id >/dev/null 2>&1; then
  HOST_UID=$(id -u)
  HOST_GID=$(id -g)
  if [ -n "${HOST_UID}" ] && [ -n "${HOST_GID}" ]; then
    DOCKER_USER_OPT="-u ${HOST_UID}:${HOST_GID}"
  fi
fi

docker run --rm $DOCKER_USER_OPT -v "$ROOT_DIR:/local" $GEN_IMAGE generate \
  -i /local/clients/godot/openapi.json \
  -g "$GENERATOR" \
  -o /local/clients/godot \
  --additional-properties="$ADDITIONAL_PROPERTIES"

echo "Generation finished. See $OUT_DIR for generated files."

echo "Post-processing generated files: replacing 'Underscore' -> '_'"

# Ensure we have permission to perform in-place edits on generated files.
# When the generator ran as a different user (e.g. root inside Docker) files
# might be owned by a different uid and perl -i will fail to create temp files.
if [ -n "${HOST_UID:-}" ]; then
  chown -R "${HOST_UID}:${HOST_GID}" "$OUT_DIR" 2>/dev/null || true
fi
chmod -R u+rw "$OUT_DIR" 2>/dev/null || true

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
# Replace list_blocked_friends_200_response_data_inner with ListBlockedFriends200ResponseDataInner
find "$OUT_DIR" -type f -iname "*.gd" -print0 | xargs -0 -r perl -0777 -pe "s/list_blocked_friends_200_response_data_inner/ListBlockedFriends200ResponseDataInner/g" -i
# Replace list_lobbies_200_response_meta with ListLobbies200ResponseMeta
find "$OUT_DIR" -type f -iname "*.gd" -print0 | xargs -0 -r perl -0777 -pe "s/list_lobbies_200_response_meta/ListLobbies200ResponseMeta/g" -i
# Replace list_blocked_friends_200_response_data_inner_requester with ListBlockedFriends200ResponseDataInnerRequester
find "$OUT_DIR" -type f -iname "*.gd" -print0 | xargs -0 -r perl -0777 -pe "s/list_blocked_friends_200_response_data_inner_requester/ListBlockedFriends200ResponseDataInnerRequester/g" -i
# Replace list_friend_requests_200_response_incoming_inner with ListFriendRequests200ResponseIncomingInner
find "$OUT_DIR" -type f -iname "*.gd" -print0 | xargs -0 -r perl -0777 -pe "s/list_friend_requests_200_response_incoming_inner/ListFriendRequests200ResponseIncomingInner/g" -i
# Replace list_friend_requests_200_response_meta with ListFriendRequests200ResponseMeta
find "$OUT_DIR" -type f -iname "*.gd" -print0 | xargs -0 -r perl -0777 -pe "s/list_friend_requests_200_response_meta/ListFriendRequests200ResponseMeta/g" -i
# Replace list_friend_requests_200_response_incoming_inner_requester with ListFriendRequests200ResponseIncomingInnerRequester
find "$OUT_DIR" -type f -iname "*.gd" -print0 | xargs -0 -r perl -0777 -pe "s/list_friend_requests_200_response_incoming_inner_requester/ListFriendRequests200ResponseIncomingInnerRequester/g" -i
# Replace list_friends_200_response_data_inner with ListFriends200ResponseDataInner
find "$OUT_DIR" -type f -iname "*.gd" -print0 | xargs -0 -r perl -0777 -pe "s/list_friends_200_response_data_inner/ListFriends200ResponseDataInner/g" -i
# Replace list_lobbies_200_response_data_inner with ListLobbies200ResponseDataInner
find "$OUT_DIR" -type f -iname "*.gd" -print0 | xargs -0 -r perl -0777 -pe "s/list_lobbies_200_response_data_inner/ListLobbies200ResponseDataInner/g" -i
# Replace Login200ResponseData_user with Login200ResponseDataUser
find "$OUT_DIR" -type f -iname "*.gd" -print0 | xargs -0 -r perl -0777 -pe "s/Login200ResponseData_user/Login200ResponseDataUser/g" -i
# Replace ListBlockedFriends200ResponseDataInner_requester with ListBlockedFriends200ResponseDataInnerRequester
find "$OUT_DIR" -type f -iname "*.gd" -print0 | xargs -0 -r perl -0777 -pe "s/ListBlockedFriends200ResponseDataInner_requester/ListBlockedFriends200ResponseDataInnerRequester/g" -i
# Replace ListFriendRequests200ResponseIncomingInner_requester with ListFriendRequests200ResponseIncomingInnerRequester
find "$OUT_DIR" -type f -iname "*.gd" -print0 | xargs -0 -r perl -0777 -pe "s/ListFriendRequests200ResponseIncomingInner_requester/ListFriendRequests200ResponseIncomingInnerRequester/g" -i
# Replace refresh_token_200_response_data with RefreshToken200ResponseData
find "$OUT_DIR" -type f -iname "*.gd" -print0 | xargs -0 -r perl -0777 -pe "s/refresh_token_200_response_data/RefreshToken200ResponseData/g" -i
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
