#!/usr/bin/env bash

set -euo pipefail

plugin_dir="${1:-.}"
manifest="$plugin_dir/manifest.json"

jq -e '
  .schemaVersion == 1 and
  (.id | type == "string" and test("^[a-z0-9][a-z0-9._-]*$") and (startswith("omarchy.") | not)) and
  (.name | type == "string" and length > 0) and
  (.version | type == "string" and length > 0 and length <= 64) and
  (.author | type == "string" and length > 0) and
  (.description | type == "string" and length > 0) and
  (.kinds | index("bar-widget") != null) and
  (.entryPoints.barWidget | type == "string" and length > 0)
' "$manifest" >/dev/null

entry_point="$(jq -r '.entryPoints.barWidget' "$manifest")"
case "$entry_point" in
  /*|*..*) echo "Unsafe entry point: $entry_point" >&2; exit 1 ;;
esac

test -f "$plugin_dir/$entry_point"

if find "$plugin_dir" -path "$plugin_dir/.git" -prune -o -type l -print -quit | grep -q .; then
  echo "Plugin repositories may not contain symlinks." >&2
  exit 1
fi

echo "Plugin structure is valid."
