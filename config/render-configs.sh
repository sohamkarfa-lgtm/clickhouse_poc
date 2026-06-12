#!/usr/bin/env bash
set -euo pipefail

render_file() {
  local source="$1"
  local target="$2"

  perl -pe 's/\$\{([^}]+)\}/exists $ENV{$1} ? $ENV{$1} : die "Missing env var $1"/ge' "$source" > "$target"
}

render_file "/etc/clickhouse-server/config.d/cluster.xml.tpl" "/etc/clickhouse-server/config.d/cluster.xml"
render_file "/etc/clickhouse-server/users.d/users.xml.tpl" "/etc/clickhouse-server/users.d/users.xml"

exec /entrypoint.sh "$@"
