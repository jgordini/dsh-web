#!/usr/bin/env bash
# Start the DeepSeek Harness web UI and bridge it to a publishable port.
#
# Why a bridge: `dsh web --host 0.0.0.0` is refused on purpose ("it would
# expose remote code execution to the network"), so the harness always binds
# loopback. A published Docker port reaches the container's eth0 address, not
# its loopback, so something has to forward. socat does, and the exposure is
# then an explicit operator decision rather than a bypassed guard.
#
# DSH_TRUSTED_HOSTS lists the authorities this deployment is reached by
# (comma or space separated, e.g. "138.26.48.197:8483"). The harness's
# browser-trust fence answers 403 for any /api request whose Host header is
# neither loopback nor a declared authority.
set -euo pipefail

DSH_LISTEN_PORT="${DSH_LISTEN_PORT:-3080}"   # loopback port the harness binds
GATEWAY_PORT="${GATEWAY_PORT:-8080}"         # published port, bridged to it

trusted_args=()
if [ -n "${DSH_TRUSTED_HOSTS:-}" ]; then
  normalized="${DSH_TRUSTED_HOSTS//,/ }"
  for host in $normalized; do
    [ -n "$host" ] && trusted_args+=(--trusted-host "$host")
  done
fi

echo "[dsh-web] harness on 127.0.0.1:${DSH_LISTEN_PORT}; bridge 0.0.0.0:${GATEWAY_PORT} -> 127.0.0.1:${DSH_LISTEN_PORT}"
echo "[dsh-web] trusted non-loopback authorities: ${DSH_TRUSTED_HOSTS:-<none>}"

dsh web --host 127.0.0.1 --port "${DSH_LISTEN_PORT}" --no-open "${trusted_args[@]}" &
dsh_pid=$!

socat TCP-LISTEN:"${GATEWAY_PORT}",fork,reuseaddr TCP:127.0.0.1:"${DSH_LISTEN_PORT}" &
socat_pid=$!

shutdown() { kill -TERM "$socat_pid" "$dsh_pid" 2>/dev/null || true; }
trap shutdown TERM INT

# Exit when either half dies, so the container restart policy can act.
wait -n "$dsh_pid" "$socat_pid" || code=$?
kill -TERM "$socat_pid" "$dsh_pid" 2>/dev/null || true
wait 2>/dev/null || true
exit "${code:-0}"
