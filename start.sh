#!/usr/bin/env bash
set -euo pipefail

export HOME=/app
export PATH="/app/.local/bin:${PATH}"

# Railway public API port.
# Your Railway service currently uses PORT=8080.
export PORT="${PORT:-8080}"

# Viewer port used by the optional Caddy proxy service.
export VIEWER_PORT="${VIEWER_PORT:-8082}"

# Persistent Railway volume paths.
export III_DATA_DIR="${III_DATA_DIR:-/data}"
export AGENTMEMORY_DATA_DIR="${AGENTMEMORY_DATA_DIR:-/data}"

# Viewer variables, if agentmemory reads them.
export AGENTMEMORY_VIEWER_HOST="${AGENTMEMORY_VIEWER_HOST:-0.0.0.0}"
export AGENTMEMORY_VIEWER_PORT="${AGENTMEMORY_VIEWER_PORT:-${VIEWER_PORT}}"
export AGENTMEMORY_VIEWER_URL="${AGENTMEMORY_VIEWER_URL:-http://0.0.0.0:${VIEWER_PORT}}"

mkdir -p /data
mkdir -p /app

DIST_DIR="/usr/local/lib/node_modules/@agentmemory/agentmemory/dist"
SOURCE_CONFIG="${DIST_DIR}/iii-config.docker.yaml"
DEFAULT_CONFIG="${DIST_DIR}/iii-config.yaml"
RAILWAY_CONFIG="/app/iii-config.railway.yaml"

echo "[railway] Starting agentmemory"
echo "[railway] PORT=${PORT}"
echo "[railway] VIEWER_PORT=${VIEWER_PORT}"
echo "[railway] III_DATA_DIR=${III_DATA_DIR}"
echo "[railway] AGENTMEMORY_DATA_DIR=${AGENTMEMORY_DATA_DIR}"
echo "[railway] AGENTMEMORY_VIEWER_HOST=${AGENTMEMORY_VIEWER_HOST}"
echo "[railway] AGENTMEMORY_VIEWER_PORT=${AGENTMEMORY_VIEWER_PORT}"
echo "[railway] AGENTMEMORY_VIEWER_URL=${AGENTMEMORY_VIEWER_URL}"

if [ ! -f "$SOURCE_CONFIG" ]; then
  echo "[railway] ERROR: missing ${SOURCE_CONFIG}"
  echo "[railway] dist content:"
  ls -la "$DIST_DIR" || true
  exit 1
fi

# Start from agentmemory's Docker config.
cp "$SOURCE_CONFIG" "$RAILWAY_CONFIG"

# Railway requires public-facing services to listen on 0.0.0.0.
# This is only for listener hosts inside the config file.
sed -i "s/host: 127.0.0.1/host: 0.0.0.0/g" "$RAILWAY_CONFIG"
sed -i "s/host: localhost/host: 0.0.0.0/g" "$RAILWAY_CONFIG"

# Adapt the REST API port to Railway's PORT.
sed -i "0,/port: 3111/s//port: ${PORT}/" "$RAILWAY_CONFIG"

# Adapt the viewer port if it appears in the config.
sed -i "s/port: 3113/port: ${VIEWER_PORT}/g" "$RAILWAY_CONFIG"
sed -i "s/port: 8082/port: ${VIEWER_PORT}/g" "$RAILWAY_CONFIG"

# agentmemory loads this default config path internally, so overwrite it.
cp "$RAILWAY_CONFIG" "$DEFAULT_CONFIG"

# Optional, narrow viewer-only patch.
# Do NOT globally replace localhost in dist, because the engine client must
# connect to localhost/127.0.0.1 internally. Replacing it with 0.0.0.0 breaks
# ws://localhost:49134 style internal connections.
echo "[railway] Applying narrow viewer port patch if needed..."
grep -RIl "3113" "$DIST_DIR" 2>/dev/null | while read -r file; do
  sed -i "s/3113/${VIEWER_PORT}/g" "$file" || true
done

echo "[railway] Overwrote default config:"
echo "[railway] ${DEFAULT_CONFIG}"

echo "[railway] Effective config preview:"
cat "$DEFAULT_CONFIG"

echo "[railway] Expected binds:"
echo "[railway] API listener should be 0.0.0.0:${PORT}"
echo "[railway] Viewer listener should be 0.0.0.0:${VIEWER_PORT}, if supported by this agentmemory version"
echo "[railway] Internal engine connections should remain localhost/127.0.0.1"

echo "[railway] Launching agentmemory..."

exec agentmemory \
  --port "${PORT}" \
  --verbose