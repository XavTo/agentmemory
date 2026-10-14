#!/bin/sh
set -eu

export PORT="${PORT:-8080}"
export AGENTMEMORY_DATA_DIR="${AGENTMEMORY_DATA_DIR:-/data}"
export III_DATA_DIR="$AGENTMEMORY_DATA_DIR"
export HOME="$AGENTMEMORY_DATA_DIR"
export III_ENGINE_PORT="${III_ENGINE_PORT:-49134}"
export III_STREAM_PORT="${III_STREAM_PORT:-3112}"
export III_VIEWER_PORT="${VIEWER_INTERNAL_PORT:-8082}"
export MALLOC_ARENA_MAX="${MALLOC_ARENA_MAX:-2}"

: "${AGENTMEMORY_SECRET:?Set AGENTMEMORY_SECRET in Railway Variables before starting.}"
if [ -n "${RAILWAY_ENVIRONMENT_ID:-}" ] && [ "${RAILWAY_VOLUME_MOUNT_PATH:-}" != "$AGENTMEMORY_DATA_DIR" ]; then
    echo "[railway] Attach a persistent volume at $AGENTMEMORY_DATA_DIR before deploying." >&2
    exit 1
fi

mkdir -p "$HOME/.agentmemory"
chown -R node:node "$AGENTMEMORY_DATA_DIR"

if [ ! -f "$HOME/.agentmemory/preferences.json" ]; then
    umask 077
    node -e 'const fs=require("node:fs"); fs.writeFileSync(process.env.HOME+"/.agentmemory/preferences.json", JSON.stringify({schemaVersion:1,skipSplash:true,skipNpxHint:true,skipGlobalInstall:true,skipConsoleInstall:true,firstRunAt:new Date().toISOString()}));'
    chown node:node "$HOME/.agentmemory/preferences.json"
fi

# Caddy authenticates the private relay; HTTP and live streams share one port.
export AGENTMEMORY_VIEWER_HOST=127.0.0.1
gosu node:node env HOME="$AGENTMEMORY_DATA_DIR" node /opt/agentmemory/viewer-proxy.mjs &

echo "[railway] Starting Agentmemory on port $PORT with persistent storage at $AGENTMEMORY_DATA_DIR"
exec gosu node:node env HOME="$AGENTMEMORY_DATA_DIR" agentmemory --port "$PORT" --data-dir "$AGENTMEMORY_DATA_DIR"
